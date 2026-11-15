package com.weutube.api;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.server.ResponseStatusException;
class YouTubeOAuthControllerTest {
 @Test void rejectsMissingStateBeforeDatabaseLookup() {
  JdbcTemplate jdbc=mock(JdbcTemplate.class);
  var controller=new YouTubeOAuthController(jdbc,mock(YouTubeCredentialStore.class),"client","https://example.com/callback","weutube-admin");
  var error=assertThrows(ResponseStatusException.class,()->controller.callback("", "code"));
  assertEquals(HttpStatus.BAD_REQUEST,error.getStatusCode());
  verifyNoInteractions(jdbc);
 }
 @Test void rejectsExpiredOrUnknownState() {
  JdbcTemplate jdbc=mock(JdbcTemplate.class);
  when(jdbc.queryForObject(anyString(),eq(Integer.class),eq("state"))).thenReturn(0);
  var controller=new YouTubeOAuthController(jdbc,mock(YouTubeCredentialStore.class),"client","https://example.com/callback","weutube-admin");
  var error=assertThrows(ResponseStatusException.class,()->controller.callback("state","code"));
  assertEquals(HttpStatus.BAD_REQUEST,error.getStatusCode());
 }
 @Test void refusesTokenExchangeUntilStorageIsReady() {
  JdbcTemplate jdbc=mock(JdbcTemplate.class);
  when(jdbc.queryForObject(anyString(),eq(Integer.class),eq("state"))).thenReturn(1);
  var controller=new YouTubeOAuthController(jdbc,mock(YouTubeCredentialStore.class),"client","https://example.com/callback","weutube-admin");
  var error=assertThrows(ResponseStatusException.class,()->controller.callback("state","code"));
  assertEquals(HttpStatus.NOT_IMPLEMENTED,error.getStatusCode());
 }
}
