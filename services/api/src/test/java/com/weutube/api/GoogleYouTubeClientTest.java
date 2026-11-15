package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

class GoogleYouTubeClientTest {
 private final ObjectMapper mapper=new ObjectMapper();
 @Test void parsesAuthorizedTokens() throws Exception {
  var json=mapper.readTree("""
   {"access_token":"access-only","refresh_token":"refresh-only",
    "scope":"https://www.googleapis.com/auth/youtube.readonly https://www.googleapis.com/auth/youtube.upload"}
   """);
  var tokens=GoogleYouTubeClient.parseTokens(json);
  assertEquals("access-only",tokens.accessToken());
  assertEquals("refresh-only",tokens.refreshToken());
 }
 @Test void refusesMissingRefreshToken() throws Exception {
  var json=mapper.readTree("""
   {"access_token":"access-only",
    "scope":"https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly"}
   """);
  assertThrows(GoogleYouTubeClient.ProviderException.class,
   ()->GoogleYouTubeClient.parseTokens(json));
 }
 @Test void refusesMissingUploadPermission() throws Exception {
  var json=mapper.readTree("""
   {"access_token":"a","refresh_token":"r","scope":"https://www.googleapis.com/auth/youtube.readonly"}
   """);
  assertThrows(GoogleYouTubeClient.ProviderException.class,
   ()->GoogleYouTubeClient.parseTokens(json));
 }
 @Test void acceptsVerifiedChannelIdentity() throws Exception {
  var channel=GoogleYouTubeClient.parseChannel(mapper.readTree("""
   {"items":[{"id":"UC123","snippet":{"title":"Creator's Channel"}}]}
   """));
  assertEquals("UC123",channel.id());
  assertEquals("Creator's Channel",channel.title());
 }
 @Test void validatesRefreshedAccessToken() throws Exception {
  var refreshed=mapper.readTree("{\"access_token\":\"short-lived-access\",\"expires_in\":3599}");
  assertEquals("short-lived-access",GoogleYouTubeClient.parseRefreshedAccessToken(refreshed));
  assertThrows(GoogleYouTubeClient.ProviderException.class,
   ()->GoogleYouTubeClient.parseRefreshedAccessToken(mapper.readTree("{}")));
 }
 @Test void refusesUnownedOrAmbiguousChannelResponse() throws Exception {
  assertThrows(GoogleYouTubeClient.ProviderException.class,
   ()->GoogleYouTubeClient.parseChannel(mapper.readTree("{\"items\":[]}")));
  assertThrows(GoogleYouTubeClient.ProviderException.class,
   ()->GoogleYouTubeClient.parseChannel(mapper.readTree("""
    {"items":[{"id":"UC1","snippet":{"title":"One"}},{"id":"UC2","snippet":{"title":"Two"}}]}
    """)));
 }
}
