package com.weutube.api;

import com.fasterxml.jackson.databind.JsonNode;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.RestController;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.server.ResponseStatusException;

/** Read-only creator-owned YouTube video statistics, never inferred income. */
@RestController
@RequestMapping("/api/creator/analytics")
public class CreatorAnalyticsController {
 private final JdbcTemplate jdbc;
 private final YouTubeAccessTokenService tokens;
 private final RestClient http;
 public CreatorAnalyticsController(JdbcTemplate jdbc,YouTubeAccessTokenService tokens) {
  this.jdbc=jdbc;this.tokens=tokens;
  var factory=new SimpleClientHttpRequestFactory();
  factory.setConnectTimeout(Duration.ofSeconds(5));
  factory.setReadTimeout(Duration.ofSeconds(15));
  http=RestClient.builder().requestFactory(factory).build();
 }
 public record LinkedVideo(String videoId,String channelId) {}
 public record Analytics(long views,long likes,long comments,
   int verifiedVideos,int requestedVideos,boolean partial,String source) {}
 static long number(JsonNode item,String name) {
  String n=item.path("statistics").path(name).asText("");
  if(!n.matches("[0-9]{1,19}")) return 0;
  try { return Long.parseLong(n); } catch(NumberFormatException e) { return 0; }
 }
 static Analytics parse(JsonNode body,Map<String,String> owned) {
  if(body==null || !body.path("items").isArray())
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,"YouTube statistics unavailable");
  long views=0,likes=0,comments=0;
  int verified=0;
  for(JsonNode item:body.path("items")) {
   String id=item.path("id").asText("");
   String channel=item.path("snippet").path("channelId").asText("");
   if(!channel.equals(owned.get(id))) continue;
   verified++;
   views+=number(item,"viewCount");
   likes+=number(item,"likeCount");
   comments+=number(item,"commentCount");
  }
  return new Analytics(views,likes,comments,verified,owned.size(),verified<owned.size(),"YOUTUBE_DATA_API");
 }
 @GetMapping
 public Analytics summary(@AuthenticationPrincipal Jwt jwt) {
  List<LinkedVideo> owned=jdbc.query("""
   SELECT v.youtube_video_id,c.youtube_channel_id
   FROM video_submissions v
   JOIN creators cr ON cr.id=v.creator_id
   JOIN youtube_channels c ON c.id=v.youtube_channel_id
   WHERE cr.cognito_sub=? AND v.status='PUBLISHED' AND v.youtube_video_id IS NOT NULL
   ORDER BY v.created_at DESC LIMIT 501
   """,(rs,row)->new LinkedVideo(rs.getString(1),rs.getString(2)),jwt.getSubject());
  if(owned.isEmpty()) return new Analytics(0,0,0,0,0,false,"NO_PUBLISHED_VIDEOS");
  boolean truncated=owned.size()>500;
  if(truncated) owned=owned.subList(0,500);
  Map<String,List<String>> byChannel=new LinkedHashMap<>();
  for(LinkedVideo v:owned) {
   if(!v.videoId().matches("[A-Za-z0-9_-]{1,128}"))
    throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,"Unexpected stored YouTube video ID");
   byChannel.computeIfAbsent(v.channelId(),k->new ArrayList<>()).add(v.videoId());
  }
  long views=0,likes=0,comments=0;
  int verified=0;
  try {
   for(var entry:byChannel.entrySet()) {
    String token=tokens.forChannel(entry.getKey());
    List<String> ids=entry.getValue();
    for(int begin=0;begin<ids.size();begin+=50) {
     List<String> batch=ids.subList(begin,Math.min(begin+50,ids.size()));
     JsonNode body=http.get()
      .uri(u->u.scheme("https").host("www.googleapis.com")
        .path("/youtube/v3/videos").queryParam("part","snippet,statistics")
        .queryParam("id",String.join(",",batch)).build())
      .headers(h->h.setBearerAuth(token)).retrieve().body(JsonNode.class);
     Map<String,String> mapped=new LinkedHashMap<>();
     for(String id:batch) mapped.put(id,entry.getKey());
     Analytics parsed=parse(body,mapped);
     views+=parsed.views();likes+=parsed.likes();comments+=parsed.comments();
     verified+=parsed.verifiedVideos();
    }
   }
  } catch(RestClientException|GoogleYouTubeClient.ProviderException ex) {
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
     "YouTube statistics are temporarily unavailable");
  }
  return new Analytics(views,likes,comments,verified,owned.size(),truncated || verified<owned.size(),
    "YOUTUBE_DATA_API");
 }
}
