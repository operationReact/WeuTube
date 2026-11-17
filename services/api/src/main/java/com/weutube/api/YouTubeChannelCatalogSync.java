package com.weutube.api;

import com.fasterxml.jackson.databind.JsonNode;
import java.time.Duration;
import java.time.Instant;
import java.time.format.DateTimeParseException;
import java.util.*;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

/** Synchronizes public embeddable videos already uploaded to a granted YouTube channel.
 * Never relies on WeuTube upload submissions or fabricates video metrics.
 */
@Service
public class YouTubeChannelCatalogSync {
 private static final Logger LOG=LoggerFactory.getLogger(YouTubeChannelCatalogSync.class);
 private static final Pattern VIDEO_ID=Pattern.compile("[A-Za-z0-9_-]{11}");
 private final JdbcTemplate jdbc;
 private final YouTubeCredentialStore credentials;
 private final YouTubeAccessTokenService tokens;
 private final GoogleYouTubeClient youtube;

 public YouTubeChannelCatalogSync(JdbcTemplate jdbc,YouTubeCredentialStore credentials,
     YouTubeAccessTokenService tokens,GoogleYouTubeClient youtube) {
  this.jdbc=jdbc;this.credentials=credentials;this.tokens=tokens;this.youtube=youtube;
 }

 public record SyncState(String status,int channelCount,int videoCount,
   int shortCandidates,Instant lastSuccessAt) {}

 public SyncState status() {
  int channels=jdbc.queryForObject("SELECT COUNT(*) FROM youtube_oauth_credentials",Integer.class);
  int videos=jdbc.queryForObject("SELECT COUNT(*) FROM youtube_public_channel_catalog",Integer.class);
  int shorts=jdbc.queryForObject("SELECT COUNT(*) FROM youtube_public_channel_catalog WHERE short_candidate",Integer.class);
  if(channels==0)return new SyncState("NOT_CONNECTED",0,videos,shorts,null);
  List<Map<String,Object>> states=jdbc.queryForList(
    "SELECT status,last_success_at FROM youtube_channel_catalog_sync");
  String state=states.isEmpty()||states.size()<channels?"PENDING":"READY";
  if(states.stream().anyMatch(row->"IMPORTING".equals(row.get("status"))))state="IMPORTING";
  if(states.stream().anyMatch(row->"ERROR".equals(row.get("status"))))state="ERROR";
  Instant latest=null;
  for(var row:states) {
   Object value=row.get("last_success_at");
   if(value instanceof java.sql.Timestamp ts &&
      (latest==null||ts.toInstant().isAfter(latest)))latest=ts.toInstant();
  }
  return new SyncState(state,channels,videos,shorts,latest);
 }

 @Scheduled(initialDelay=15000,fixedDelay=1800000)
 public synchronized void sync() {
  List<YouTubeCredentialStore.ChannelSummary> channels;
  try {channels=credentials.connectedChannels();}
  catch(RuntimeException e){LOG.warn("YouTube catalog channel inventory unavailable");return;}
  for(var channel:channels) {
   try {syncChannel(channel);}
   catch(RuntimeException e) {
    jdbc.update("""
      INSERT INTO youtube_channel_catalog_sync
        (youtube_channel_id,channel_title,status,error_code,last_attempt_at)
      VALUES (?,?,'ERROR','IMPORT_FAILED',now())
      ON CONFLICT(youtube_channel_id) DO UPDATE SET status='ERROR',
        error_code='IMPORT_FAILED',last_attempt_at=now()
      """,channel.channelId(),channel.displayName());
    // Never log provider responses, refresh tokens or access tokens.
    LOG.warn("A connected YouTube channel catalog refresh failed");
   }
  }
 }

 void syncChannel(YouTubeCredentialStore.ChannelSummary channel) {
  String channelId=channel.channelId();
  if(!channelId.matches("[A-Za-z0-9_-]{1,128}"))
   throw new IllegalArgumentException("Invalid YouTube channel identity");
  jdbc.update("""
    INSERT INTO youtube_channel_catalog_sync
      (youtube_channel_id,channel_title,status,last_attempt_at)
    VALUES (?,?,'IMPORTING',now())
    ON CONFLICT(youtube_channel_id) DO UPDATE SET status='IMPORTING',
      channel_title=EXCLUDED.channel_title,last_attempt_at=now(),error_code=NULL
    """,channelId,channel.displayName());
  String access=tokens.forChannel(channelId);
  JsonNode channelData=youtube.readVideoCatalog("channels",
     Map.of("part","contentDetails","id",channelId),access);
  JsonNode c=channelData.path("items").path(0);
  if(!channelId.equals(c.path("id").asText("")))
   throw new IllegalStateException("Channel identity mismatch");
  String uploads=c.path("contentDetails").path("relatedPlaylists").path("uploads").asText("");
  if(uploads.isBlank())throw new IllegalStateException("Uploads playlist missing");
  Instant started=Instant.now();
  String next="";
  int imported=0;
  boolean complete=false;
  Set<String> seen=new HashSet<>();
  for(int page=0;page<20;page++) {
   Map<String,String> query=new LinkedHashMap<>();
   query.put("part","contentDetails");
   query.put("playlistId",uploads);
   query.put("maxResults","50");
   if(!next.isBlank())query.put("pageToken",next);
   JsonNode listing=youtube.readVideoCatalog("playlistItems",query,access);
   if(listing==null||!listing.path("items").isArray())
    throw new IllegalStateException("Invalid uploads response");
   List<String> ids=new ArrayList<>();
   for(JsonNode v:listing.path("items")) {
    String id=v.path("contentDetails").path("videoId").asText("");
    if(VIDEO_ID.matcher(id).matches() && seen.add(id))ids.add(id);
   }
   if(!ids.isEmpty()) {
    JsonNode details=youtube.readVideoCatalog("videos",
      Map.of("part","snippet,contentDetails,statistics,status",
        "id",String.join(",",ids),"maxResults","50"),access);
    if(details==null||!details.path("items").isArray())
     throw new IllegalStateException("Invalid video metadata response");
    for(JsonNode row:details.path("items")) {
     VideoInfo v=parsePublicVideo(row,channelId);
     if(v==null)continue;
     imported++;
     jdbc.update("""
       INSERT INTO youtube_public_channel_catalog
       (youtube_video_id,youtube_channel_id,channel_title,title,description,
        thumbnail_url,published_at,duration_seconds,view_count,like_count,
        comment_count,short_candidate,last_seen_at)
       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
       ON CONFLICT(youtube_video_id) DO UPDATE SET
        youtube_channel_id=EXCLUDED.youtube_channel_id,
        channel_title=EXCLUDED.channel_title,title=EXCLUDED.title,
        description=EXCLUDED.description,thumbnail_url=EXCLUDED.thumbnail_url,
        published_at=EXCLUDED.published_at,duration_seconds=EXCLUDED.duration_seconds,
        view_count=EXCLUDED.view_count,like_count=EXCLUDED.like_count,
        comment_count=EXCLUDED.comment_count,short_candidate=EXCLUDED.short_candidate,
        last_seen_at=EXCLUDED.last_seen_at
       """,v.id(),channelId,channel.displayName(),v.title(),v.description(),
       v.thumbnail(),java.sql.Timestamp.from(v.publishedAt()),v.seconds(),
       v.views(),v.likes(),v.comments(),v.shortCandidate(),
       java.sql.Timestamp.from(started));
    }
   }
   next=listing.path("nextPageToken").asText("");
   if(next.isBlank()){complete=true;break;}
  }
  // Only purge removed/private videos when all pages were verified.
  if(complete)jdbc.update("""
    DELETE FROM youtube_public_channel_catalog
    WHERE youtube_channel_id=? AND last_seen_at < ?
    """,channelId,java.sql.Timestamp.from(started));
  jdbc.update("""
    UPDATE youtube_channel_catalog_sync
    SET status='READY',imported_count=?,last_success_at=now(),
      last_attempt_at=now(),error_code=NULL
    WHERE youtube_channel_id=?
    """,imported,channelId);
  LOG.info("YouTube catalog refreshed: count={}, complete={}",imported,complete);
 }

 record VideoInfo(String id,String title,String description,String thumbnail,
   Instant publishedAt,int seconds,Long views,Long likes,Long comments,
   boolean shortCandidate) {}

 static VideoInfo parsePublicVideo(JsonNode row,String channelId) {
  if(row==null)return null;
  String id=row.path("id").asText("");
  JsonNode snippet=row.path("snippet"),status=row.path("status");
  if(!VIDEO_ID.matcher(id).matches()||
    !channelId.equals(snippet.path("channelId").asText(""))||
    !"public".equals(status.path("privacyStatus").asText(""))||
    !status.path("embeddable").asBoolean(false))return null;
  String title=snippet.path("title").asText("").strip();
  try {
   Instant when=Instant.parse(snippet.path("publishedAt").asText(""));
   long seconds=Duration.parse(row.path("contentDetails").path("duration").asText(""))
     .getSeconds();
   if(title.isBlank()||seconds<1||seconds>Integer.MAX_VALUE)return null;
   JsonNode stats=row.path("statistics");
   return new VideoInfo(id,title,snippet.path("description").asText(""),
     "https://i.ytimg.com/vi/"+id+"/hqdefault.jpg",when,(int)seconds,
     count(stats,"viewCount"),count(stats,"likeCount"),count(stats,"commentCount"),
     seconds<=180);
  } catch(DateTimeParseException|ArithmeticException e){return null;}
 }
 private static Long count(JsonNode stats,String field) {
  JsonNode value=stats.path(field);
  return value.canConvertToLong()?value.longValue():null;
 }
}
