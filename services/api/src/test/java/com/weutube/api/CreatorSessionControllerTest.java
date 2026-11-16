package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.oauth2.jwt.Jwt;

class CreatorSessionControllerTest {
 private final JdbcTemplate jdbc=mock(JdbcTemplate.class);
 private final CreatorSessionController controller=new CreatorSessionController(jdbc);
 private final Jwt owner=Jwt.withTokenValue("test").header("alg","none")
  .subject("current-user").build();

 @BeforeEach void resetMocks() {reset(jdbc);}

 @Test void signedInWithoutAnyChannelGrantIsNotAccessDenied() {
  when(jdbc.queryForObject(anyString(),eq(Boolean.class),eq("current-user")))
    .thenReturn(false,false);
  var status=controller.status(owner);
  assertTrue(status.authenticated());
  assertFalse(status.channelGranted());
  assertFalse(status.channelConnected());
  assertEquals("NO_CHANNEL_GRANT",status.uploadAccess());
  verify(jdbc,times(2)).queryForObject(anyString(),eq(Boolean.class),eq("current-user"));
 }

 @Test void unconnectedGrantedChannelProducesHonestEmptyState() {
  when(jdbc.queryForObject(anyString(),eq(Boolean.class),eq("current-user")))
    .thenReturn(true,false);
  var status=controller.status(owner);
  assertEquals("CHANNEL_NOT_CONNECTED",status.uploadAccess());
  assertTrue(status.channelGranted());
  assertFalse(status.channelConnected());
 }

 @Test void connectedGrantIsReadyWithoutExposingOAuthCredentials() {
  when(jdbc.queryForObject(anyString(),eq(Boolean.class),eq("current-user")))
    .thenReturn(true,true);
  var status=controller.status(owner);
  assertEquals("READY",status.uploadAccess());
  assertTrue(status.authenticated());
  assertFalse(status.toString().contains("token"));
 }
}
