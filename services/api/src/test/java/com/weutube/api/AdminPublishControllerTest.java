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

class AdminPublishControllerTest {
 private final JdbcTemplate jdbc=mock(JdbcTemplate.class);
 private final GoogleVideoPublishingService publisher=mock(GoogleVideoPublishingService.class);
 private final AdminPublishController controller=new AdminPublishController(jdbc,publisher,"weutube-admin");
 private final Jwt admin=Jwt.withTokenValue("a").header("alg","none").subject("admin")
   .claim("cognito:groups",List.of("weutube-admin")).build();
 private final Jwt creator=Jwt.withTokenValue("u").header("alg","none").subject("user").build();

 @Test void nonAdminCannotPublish() {
  assertThrows(AccessDeniedException.class,()->
    controller.publish(creator,UUID.randomUUID()));
  verifyNoInteractions(jdbc,publisher);
 }
 @Test void cannotPublishWithoutApproval() {
  UUID id=UUID.randomUUID();
  when(jdbc.query(anyString(),any(org.springframework.jdbc.core.RowMapper.class),eq(id)))
   .thenReturn(List.of(new AdminPublishController.Target("video","UC123","PRIVATE_REVIEW")));
  var error=assertThrows(ResponseStatusException.class,()->controller.publish(admin,id));
  assertEquals(HttpStatus.CONFLICT,error.getStatusCode());
  verifyNoInteractions(publisher);
 }
 @Test void onlyOneAtomicPublicationClaimMayProceed() {
  UUID id=UUID.randomUUID();
  when(jdbc.query(anyString(),any(org.springframework.jdbc.core.RowMapper.class),eq(id)))
    .thenReturn(List.of(new AdminPublishController.Target("video","UC123","APPROVED")));
  when(jdbc.update(contains("PUBLISHING"),eq(id))).thenReturn(0);
  var error=assertThrows(ResponseStatusException.class,()->controller.publish(admin,id));
  assertEquals(HttpStatus.CONFLICT,error.getStatusCode());
  verifyNoInteractions(publisher);
 }
}
