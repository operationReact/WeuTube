package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class YouTubeAccessTokenServiceTest {
 @Test void refreshesOnDemandWithoutExposingRefreshToken() {
  var store=mock(YouTubeCredentialStore.class);
  var google=mock(GoogleYouTubeClient.class);
  when(store.loadRefreshToken("UC123")).thenReturn(Optional.of("refresh-secret"));
  when(google.refreshAccessToken("refresh-secret")).thenReturn("new-access-secret");
  var service=new YouTubeAccessTokenService(store,google);
  assertEquals("new-access-secret",service.forChannel("UC123"));
  verify(google).refreshAccessToken("refresh-secret");
 }
 @Test void reusesShortLivedTokenAcrossThousandsOfVideoChunks() {
  var store=mock(YouTubeCredentialStore.class);
  var google=mock(GoogleYouTubeClient.class);
  when(store.loadRefreshToken("UC123")).thenReturn(Optional.of("refresh-secret"));
  when(google.refreshAccessToken("refresh-secret")).thenReturn("access");
  var service=new YouTubeAccessTokenService(store,google);
  for(int i=0;i<200;i++) assertEquals("access",service.forChannel("UC123"));
  verify(google,times(1)).refreshAccessToken("refresh-secret");
  service.invalidate("UC123");
  assertEquals("access",service.forChannel("UC123"));
  verify(google,times(2)).refreshAccessToken("refresh-secret");
 }
 @Test void unknownChannelFailsBeforeGoogleRequest() {
  var store=mock(YouTubeCredentialStore.class);
  var google=mock(GoogleYouTubeClient.class);
  when(store.loadRefreshToken("missing")).thenReturn(Optional.empty());
  assertThrows(IllegalArgumentException.class,
   ()->new YouTubeAccessTokenService(store,google).forChannel("missing"));
  verifyNoInteractions(google);
 }
}
