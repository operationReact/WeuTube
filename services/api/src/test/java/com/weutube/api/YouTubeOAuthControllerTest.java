package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.oauth2.jwt.Jwt;

class YouTubeOAuthControllerTest {
 private final JdbcTemplate jdbc=mock(JdbcTemplate.class);
 private final YouTubeCredentialStore credentials=mock(YouTubeCredentialStore.class);
 private final YouTubeConnectionService connection=mock(YouTubeConnectionService.class);
 private YouTubeOAuthController controller() {
  return new YouTubeOAuthController(jdbc,credentials,connection,
   "google-client","https://api.weutube.com/api/admin/youtube/callback","weutube-admin");
 }
 private Jwt adminJwt() {
  return Jwt.withTokenValue("token").header("alg","none").subject("admin-123")
   .claim("cognito:groups",List.of("weutube-admin")).build();
 }
 @Test void delegatesBrowserCallbackAndReturnsOnlyChannelDetails() {
  var connected=new YouTubeConnectionService.ConnectedChannel("UC123","My Channel","connected");
  when(connection.complete("state","code",null)).thenReturn(connected);
  var response=controller().callback("state","code",null);
  assertEquals(HttpStatus.OK,response.getStatusCode());
  assertEquals(connected,response.getBody());
  assertEquals("no-referrer",response.getHeaders().getFirst("Referrer-Policy"));
  assertTrue(response.getHeaders().getCacheControl().contains("no-store"));
 }
 @Test void adminAuthorizationRequiresConfiguredEncryptionAndGoogle() {
  when(connection.configured()).thenReturn(false);
  var error=assertThrows(org.springframework.web.server.ResponseStatusException.class,
   ()->controller().start(adminJwt()));
  assertEquals(HttpStatus.SERVICE_UNAVAILABLE,error.getStatusCode());
  verifyNoInteractions(jdbc);
 }
 @Test void nonAdminCannotInitiateConnection() {
  Jwt user=Jwt.withTokenValue("token").header("alg","none").subject("user")
   .claim("cognito:groups",List.of("weutube-creator")).build();
  assertThrows(AccessDeniedException.class,()->controller().start(user));
 }
 @Test void adminCanStartConnectionWithRandomSingleUseState() {
  when(connection.configured()).thenReturn(true);
  var response=controller().start(adminJwt());
  assertTrue(response.url().startsWith("https://accounts.google.com/o/oauth2/v2/auth?"));
  assertTrue(response.url().contains("access_type=offline"));
  assertTrue(response.url().contains("prompt=consent"));
  verify(jdbc).update(contains("INSERT INTO youtube_oauth_attempts"),any(),anyString(),
   eq("admin-123"),eq(response.expiresAt().atOffset(java.time.ZoneOffset.UTC)));
 }
}
