package com.weutube.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Admin decisions only. There is deliberately no endpoint to invent a completed bank transfer. */
@RestController
@RequestMapping("/api/admin/payouts")
public class AdminPayoutController {
 private final JdbcTemplate jdbc;
 private final String adminGroup;
 public AdminPayoutController(JdbcTemplate jdbc,
   @Value("${weutube.security.admin-group:weutube-admin}") String adminGroup) {
  this.jdbc=jdbc;this.adminGroup=adminGroup;
 }
 private void requireAdmin(Jwt jwt) {
  Object raw=jwt.getClaims().get("cognito:groups");
  if(!(raw instanceof java.util.Collection<?> groups)||!groups.contains(adminGroup))
   throw new AccessDeniedException("Admin group required");
 }
 public record Payout(UUID id,String creatorSubject,long amountMinor,String currency,String status) {}
 public record Decision(@NotBlank String decision,@Size(max=1000) String reason) {}

 @GetMapping("/queue")
 @Transactional(readOnly=true)
 public List<Payout> queue(@AuthenticationPrincipal Jwt jwt,
   @RequestParam(defaultValue="0") int page) {
  requireAdmin(jwt);
  if(page<0 || page>100000)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid page");
  return jdbc.query("""
   SELECT p.id,c.cognito_sub,p.amount_minor,p.currency,p.status
   FROM payout_requests p JOIN creators c ON c.id=p.creator_id
   WHERE p.status='REQUESTED'
   ORDER BY p.created_at ASC,p.id ASC LIMIT 25 OFFSET ?
   """,(rs,row)->new Payout((UUID)rs.getObject(1),rs.getString(2),
     rs.getLong(3),rs.getString(4),rs.getString(5)),page*25);
 }
 @PostMapping("/{id}/decision")
 @Transactional
 public Map<String,String> decide(@AuthenticationPrincipal Jwt jwt,
   @PathVariable UUID id,@Valid @RequestBody Decision input) {
  requireAdmin(jwt);
  String action=input.decision().trim().toUpperCase(java.util.Locale.ROOT);
  if(!action.equals("APPROVED")&&!action.equals("REJECTED"))
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid decision");
  if(action.equals("REJECTED")&&(input.reason()==null || input.reason().isBlank()))
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Rejection reason is required");
  int changed=jdbc.update("""
   UPDATE payout_requests SET status=? WHERE id=? AND status='REQUESTED'
   """,action,id);
  if(changed!=1)
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Payout was not pending or was already reviewed");
  jdbc.update("""
   INSERT INTO payout_decision_events(id,payout_id,reviewer_sub,decision,reason)
   VALUES (?,?,?,?,?)
   """,UUID.randomUUID(),id,jwt.getSubject(),action,
     input.reason()==null?null:input.reason().trim());
  return Map.of("payoutId",id.toString(),"status",action);
 }
}
