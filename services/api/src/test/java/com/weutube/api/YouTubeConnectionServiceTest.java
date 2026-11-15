package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.server.ResponseStatusException;

class YouTubeConnectionServiceTest {
 private static final String STATE="abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG";
 JdbcTemplate jdbc=mock(JdbcTemplate.class);
 YouTubeCredentialStore store=mock(YouTubeCredentialStore.class);
 GoogleYouTubeClient google=mock(GoogleYouTubeClient.class);
 YouTubeConnectionService service=new YouTubeConnectionService(jdbc,store,google);

 @BeforeEach void setup() {
  when(store.configured()).thenReturn(true);
  when(google.configured()).thenReturn(true);
 }
 private void validState() {
  when(jdbc.queryForObject(anyString(),eq(String.class),eq(STATE))).thenReturn("admin-sub");
 }
 @Test void connectsOnlyVerifiedChannelAndDoesNotExposeTokens() {
  validState();
  when(google.exchange("auth-code")).thenReturn(new GoogleYouTubeClient.Tokens("access-secret","refresh-secret"));
  when(google.channelFor("access-secret")).thenReturn(new GoogleYouTubeClient.Channel("UC123","Creator Channel"));
  var result=service.complete(STATE,"auth-code",null);
  assertEquals("UC123",result.channelId());
  assertEquals("Creator Channel",result.displayName());
  assertEquals("connected",result.status());
  assertFalse(result.toString().contains("secret"));
  var sequence=inOrder(jdbc,google,store);
  sequence.verify(jdbc).queryForObject(contains("UPDATE youtube_oauth_attempts"),eq(String.class),eq(STATE));
  sequence.verify(google).exchange("auth-code");
  sequence.verify(google).channelFor("access-secret");
  sequence.verify(store).saveVerifiedChannel("UC123","Creator Channel","refresh-secret","admin-sub");
 }
 @Test void rejectsMalformedStateWithoutDatabaseAccess() {
  var error=assertThrows(ResponseStatusException.class,()->service.complete("bad","code",null));
  assertEquals(HttpStatus.BAD_REQUEST,error.getStatusCode());
  verifyNoInteractions(jdbc);
 }
 @Test void rejectsExpiredOrConsumedState() {
  when(jdbc.queryForObject(anyString(),eq(String.class),eq(STATE)))
    .thenThrow(new EmptyResultDataAccessException(1));
  var error=assertThrows(ResponseStatusException.class,()->service.complete(STATE,"code",null));
  assertEquals(HttpStatus.BAD_REQUEST,error.getStatusCode());
  verify(google,never()).exchange(anyString());
 }
 @Test void consumesStateWhenUserDeniesConsent() {
  validState();
  var error=assertThrows(ResponseStatusException.class,()->service.complete(STATE,null,"access_denied"));
  assertEquals(HttpStatus.BAD_REQUEST,error.getStatusCode());
  verify(google,never()).exchange(anyString());
  verify(jdbc).queryForObject(contains("UPDATE"),eq(String.class),eq(STATE));
 }
 @Test void consumesStateForMissingCode() {
  validState();
  var error=assertThrows(ResponseStatusException.class,()->service.complete(STATE,null,null));
  assertEquals(HttpStatus.BAD_REQUEST,error.getStatusCode());
  verify(google,never()).exchange(anyString());
 }
 @Test void providerFailureDoesNotStoreUnverifiedChannel() {
  validState();
  when(google.exchange("code")).thenThrow(new GoogleYouTubeClient.ProviderException("confidential provider detail"));
  var error=assertThrows(ResponseStatusException.class,()->service.complete(STATE,"code",null));
  assertEquals(HttpStatus.BAD_GATEWAY,error.getStatusCode());
  assertFalse(error.getReason().contains("confidential"));
  verify(store,never()).saveVerifiedChannel(anyString(),anyString(),anyString(),anyString());
 }
 @Test void requiresEncryptionKeyBeforeConsumingState() {
  when(store.configured()).thenReturn(false);
  var error=assertThrows(ResponseStatusException.class,()->service.complete(STATE,"code",null));
  assertEquals(HttpStatus.SERVICE_UNAVAILABLE,error.getStatusCode());
  verifyNoInteractions(jdbc);
 }
}
