package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.server.ResponseStatusException;

class CreatorWalletControllerTest {
 private final JdbcTemplate jdbc=mock(JdbcTemplate.class);
 private final CreatorRepository creators=mock(CreatorRepository.class);
 private final CreatorWalletController controller=new CreatorWalletController(jdbc,creators);
 private final Jwt jwt=Jwt.withTokenValue("test").header("alg","none")
    .subject("creator-one").build();
 private final Creator creator=new Creator("creator-one","Creator");
 @BeforeEach void setup() {
  when(creators.findByCognitoSub("creator-one")).thenReturn(Optional.of(creator));
 }
 @Test void zeroBalanceNoFakeRevenue() {
  when(jdbc.queryForObject(contains("revenue_ledger"),eq(Long.class),eq(creator.id))).thenReturn(0L);
  when(jdbc.queryForObject(contains("payout_requests"),eq(Long.class),eq(creator.id))).thenReturn(0L);
  var wallet=controller.balance(jwt);
  assertEquals("INR",wallet.currency());
  assertEquals(0,wallet.verifiedMinor());
  assertEquals(0,wallet.availableMinor());
 }
 @Test void rejectsWithdrawalWithoutVerifiedFunds() {
  when(jdbc.queryForObject(contains("creators WHERE id"),eq(UUID.class),eq(creator.id))).thenReturn(creator.id);
  when(jdbc.query(anyString(),any(org.springframework.jdbc.core.RowMapper.class),
    eq(creator.id),any(UUID.class))).thenReturn(List.of());
  when(jdbc.queryForObject(contains("revenue_ledger"),eq(Long.class),eq(creator.id))).thenReturn(0L);
  when(jdbc.queryForObject(contains("payout_requests"),eq(Long.class),eq(creator.id))).thenReturn(0L);
  var err=assertThrows(ResponseStatusException.class,
    ()->controller.request(jwt,new CreatorWalletController.WithdrawalRequest(UUID.randomUUID(),500)));
  assertEquals(HttpStatus.CONFLICT,err.getStatusCode());
  verify(jdbc,never()).update(contains("INSERT INTO payout_requests"),any(),any(),any(),any());
 }
}
