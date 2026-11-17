package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

class PublicUploadReadinessControllerTest {
 private final JdbcTemplate jdbc=mock(JdbcTemplate.class);

 @Test void neverCallsAStoredChannelAConfirmedYouTubeUpload() {
  when(jdbc.queryForObject(anyString(),eq(Integer.class))).thenReturn(1);
  var result=new PublicUploadReadinessController(jdbc,true,"commit-123").status();
  assertEquals("CHANNEL_RECORD_PRESENT",result.getBody().state());
  assertEquals("commit-123",result.getBody().revision());
  assertTrue(result.getBody().singleConnectedChannelRecorded());
  assertTrue(result.getHeaders().getCacheControl().contains("no-store"));
 }

 @Test void reportsMissingGoogleAuthorizationWithoutExposingSecrets() {
  when(jdbc.queryForObject(anyString(),eq(Integer.class))).thenReturn(0);
  var result=new PublicUploadReadinessController(jdbc,true,"commit-456").status();
  assertEquals("GOOGLE_CHANNEL_CONNECTION_REQUIRED",result.getBody().state());
  assertFalse(result.getBody().singleConnectedChannelRecorded());
  assertFalse(result.toString().contains("refresh_token"));
 }

 @Test void refusesToClaimReadyWhenMultipleChannelsAreConnected() {
  when(jdbc.queryForObject(anyString(),eq(Integer.class))).thenReturn(2);
  var result=new PublicUploadReadinessController(jdbc,true,"rev").status();
  assertEquals("CHANNEL_SELECTION_REQUIRED",result.getBody().state());
 }

 @Test void disabledServerNeverReportsOnboardingReady() {
  when(jdbc.queryForObject(anyString(),eq(Integer.class))).thenReturn(1);
  var result=new PublicUploadReadinessController(jdbc,false,"rev").status();
  assertEquals("CREATOR_ONBOARDING_DISABLED",result.getBody().state());
  assertFalse(result.getBody().creatorOnboardingEnabled());
 }
}
