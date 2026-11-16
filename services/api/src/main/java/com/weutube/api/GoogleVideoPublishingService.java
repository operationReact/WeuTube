package com.weutube.api;

import com.fasterxml.jackson.databind.JsonNode;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

/** Owner-verified public publishing; no caller can provide an arbitrary OAuth token. */
@Service
public class GoogleVideoPublishingService {
 private final YouTubeAccessTokenService accessTokens;
 private final GoogleYouTubeClient google;
 private final RestClient client;
 public GoogleVideoPublishingService(YouTubeAccessTokenService accessTokens,
   GoogleYouTubeClient google) {
  this.accessTokens=accessTokens;this.google=google;
  var factory=new SimpleClientHttpRequestFactory();
  factory.setConnectTimeout(Duration.ofSeconds(5));
  factory.setReadTimeout(Duration.ofSeconds(20));
  this.client=RestClient.builder().requestFactory(factory).build();
 }
 public static class ProviderFailure extends RuntimeException {
  public ProviderFailure(String message) { super(message); }
 }

 static void ensureOwnerAndVisibility(JsonNode response,String videoId,
    String channelId,String visibility) {
  if(response==null || !response.path("items").isArray()
    || response.path("items").size()!=1)
   throw new ProviderFailure("Video could not be verified");
  JsonNode item=response.path("items").get(0);
  if(!videoId.equals(item.path("id").asText(""))
    || !channelId.equals(item.path("snippet").path("channelId").asText(""))
    || !visibility.equals(item.path("status").path("privacyStatus").asText("")))
   throw new ProviderFailure("Video ownership or visibility does not match");
 }
 private String token(String channelId) {
  String access=accessTokens.forChannel(channelId);
  if(!channelId.equals(google.channelFor(access).id()))
   throw new ProviderFailure("Authenticated YouTube channel does not match");
  return access;
 }
 private JsonNode details(String videoId,String access) {
  return client.get().uri("https://www.googleapis.com/youtube/v3/videos?part=snippet,status&id={videoId}",videoId)
    .headers(h->h.setBearerAuth(access)).retrieve().body(JsonNode.class);
 }
 public boolean isPublic(String channelId,String videoId) {
  try {
   String token=token(channelId);
   ensureOwnerAndVisibility(details(videoId,token),videoId,channelId,"public");
   return true;
  } catch(RestClientException|GoogleYouTubeClient.ProviderException ex) {
   throw new ProviderFailure("YouTube publication verification failed");
  }
 }
 public void publish(String channelId,String videoId) {
  try {
   String token=token(channelId);
   JsonNode current=details(videoId,token);
   ensureOwnerAndVisibility(current,videoId,channelId,"private");
   JsonNode original=current.path("items").get(0).path("status");
   Map<String,Object> status=new LinkedHashMap<>();
   status.put("privacyStatus","public");
   for(String key:new String[]{"embeddable","license","publicStatsViewable",
      "selfDeclaredMadeForKids","containsSyntheticMedia"}) {
    if(original.hasNonNull(key)) {
     JsonNode value=original.get(key);
     if(value.isBoolean()) status.put(key,value.booleanValue());
     else if(value.isTextual()) status.put(key,value.asText());
    }
   }
   JsonNode result=client.put()
    .uri("https://www.googleapis.com/youtube/v3/videos?part=status")
    .headers(h->h.setBearerAuth(token))
    .body(Map.of("id",videoId,"status",status))
    .retrieve().body(JsonNode.class);
   if(result==null || !videoId.equals(result.path("id").asText(""))
      || !"public".equals(result.path("status").path("privacyStatus").asText("")))
    throw new ProviderFailure("YouTube did not confirm public visibility");
  } catch(RestClientException|GoogleYouTubeClient.ProviderException ex) {
   throw new ProviderFailure("YouTube publication failed; reconciliation required");
  }
 }
}
