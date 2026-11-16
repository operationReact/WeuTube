package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.server.ResponseStatusException;

class AdminPayoutControllerTest {
 private final JdbcTemplate jdbc=mock(JdbcTemplate.class);
 private final AdminPayoutController controller=new AdminPayoutController(jdbc,"weutube-admin");
 private final Jwt admin=Jwt.withTokenValue("a").header("alg","none").subject("admin")
  .claim("cognito:groups",List.of("weutube-admin")).build();
 private final Jwt creator=Jwt.withTokenValue("u").header("alg","none").subject("user").build();

 @Test void creatorCannotApprovePayout() {
  assertThrows(AccessDeniedException.class,()->
    controller.decide(creator,UUID.randomUUID(),
      new AdminPayoutController.Decision("APPROVED",null)));
  verifyNoInteractions(jdbc);
 }
 @Test void alreadyReviewedPayoutCannotBeApprovedAgain() {
  UUID id=UUID.randomUUID();
  when(jdbc.update(contains("UPDATE payout_requests"),eq("APPROVED"),eq(id)))
   .thenReturn(0);
  var error=assertThrows(ResponseStatusException.class,()->
    controller.decide(admin,id,new AdminPayoutController.Decision("APPROVED",null)));
  assertEquals(HttpStatus.CONFLICT,error.getStatusCode());
  verify(jdbc,never()).update(contains("INSERT INTO payout_decision_events"),
    any(),any(),any(),any(),any());
 }
 @Test void rejectionRequiresReason() {
  var error=assertThrows(ResponseStatusException.class,()->
    controller.decide(admin,UUID.randomUUID(),
     new AdminPayoutController.Decision("REJECTED"," ")));
  assertEquals(HttpStatus.BAD_REQUEST,error.getStatusCode());
 }
}
