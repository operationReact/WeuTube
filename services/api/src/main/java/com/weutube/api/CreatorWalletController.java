package com.weutube.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Max;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/**
 * A ledger-backed, owner-scoped wallet. No inferred RPM or unverified earnings.
 * Payout requests reserve verified funds but DO NOT send money.
 */
@RestController
@RequestMapping("/api/creator/wallet")
public class CreatorWalletController {
 private final JdbcTemplate jdbc;
 private final CreatorRepository creators;
 public CreatorWalletController(JdbcTemplate jdbc,CreatorRepository creators) {
  this.jdbc=jdbc;this.creators=creators;
 }
 public record WalletSummary(String currency,long verifiedMinor,long reservedMinor,long availableMinor) {}
 public record WithdrawalRequest(@NotNull UUID requestKey,@Min(100) @Max(100000000) long amountMinor) {}
 public record Withdrawal(UUID id,long amountMinor,String currency,String status) {}

 private Creator current(Jwt jwt) {
  return creators.findByCognitoSub(jwt.getSubject())
    .orElseGet(()->creators.save(new Creator(jwt.getSubject(),"Creator")));
 }
 private long total(String sql,UUID creatorId) {
  Long result=jdbc.queryForObject(sql,Long.class,creatorId);
  return result==null?0L:result;
 }
 private WalletSummary summary(UUID creatorId) {
  // Ledger entries must originate from reconciled, trusted revenue events.
  long verified=total("""
   SELECT COALESCE(SUM(amount_minor),0) FROM revenue_ledger
   WHERE creator_id=? AND currency='INR'
   """,creatorId);
  long reserved=total("""
   SELECT COALESCE(SUM(amount_minor),0) FROM payout_requests
   WHERE creator_id=? AND currency='INR'
   AND status IN ('REQUESTED','APPROVED','PROCESSING','COMPLETED')
   """,creatorId);
  return new WalletSummary("INR",Math.max(0,verified),Math.max(0,reserved),
    Math.max(0,verified-reserved));
 }
 @GetMapping
 @Transactional
 public WalletSummary balance(@AuthenticationPrincipal Jwt jwt) {
  return summary(current(jwt).id);
 }
 @GetMapping("/withdrawals")
 @Transactional(readOnly=true)
 public List<Withdrawal> withdrawals(@AuthenticationPrincipal Jwt jwt) {
  // No user-controlled creator IDs or unrestricted paging.
  return jdbc.query("""
    SELECT p.id,p.amount_minor,p.currency,p.status FROM payout_requests p
    JOIN creators c ON c.id=p.creator_id
    WHERE c.cognito_sub=? ORDER BY p.created_at DESC LIMIT 100
    """,(rs,row)->new Withdrawal(
       (UUID)rs.getObject(1),rs.getLong(2),rs.getString(3),rs.getString(4)),
    jwt.getSubject());
 }
 @PostMapping("/withdrawals")
 @ResponseStatus(HttpStatus.CREATED)
 @Transactional
 public Withdrawal request(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody WithdrawalRequest input) {
  Creator creator=current(jwt);
  // Lock creator row so simultaneous withdrawals cannot reserve the same funds.
  jdbc.queryForObject("SELECT id FROM creators WHERE id=? FOR UPDATE",UUID.class,creator.id);
  List<Withdrawal> existing=jdbc.query("""
    SELECT id,amount_minor,currency,status FROM payout_requests
    WHERE creator_id=? AND request_key=?
    """,(rs,row)->new Withdrawal((UUID)rs.getObject(1),rs.getLong(2),
      rs.getString(3),rs.getString(4)),creator.id,input.requestKey());
  if(!existing.isEmpty()) {
   Withdrawal previous=existing.get(0);
   if(previous.amountMinor()!=input.amountMinor())
    throw new ResponseStatusException(HttpStatus.CONFLICT,"Request key reused with a different amount");
   return previous;
  }
  if(input.amountMinor()<100 || input.amountMinor()>100000000)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid withdrawal amount");
  if(summary(creator.id).availableMinor()<input.amountMinor())
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Insufficient verified available balance");
  UUID id=UUID.randomUUID();
  jdbc.update("""
    INSERT INTO payout_requests(id,creator_id,amount_minor,currency,status,request_key)
    VALUES (?,?,?,'INR','REQUESTED',?)
    """,id,creator.id,input.amountMinor(),input.requestKey());
  return new Withdrawal(id,input.amountMinor(),"INR","REQUESTED");
 }
}
