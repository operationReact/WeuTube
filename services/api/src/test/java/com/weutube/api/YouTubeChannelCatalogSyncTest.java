package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;

class YouTubeChannelCatalogSyncTest {
 private final ObjectMapper mapper=new ObjectMapper();
 private final JdbcTemplate db=mock(JdbcTemplate.class);
 private final YouTubeCredentialStore store=mock(YouTubeCredentialStore.class);
 private final YouTubeAccessTokenService access=mock(YouTubeAccessTokenService.class);
 private final GoogleYouTubeClient youtube=mock(GoogleYouTubeClient.class);
 private final YouTubeChannelCatalogSync sync=
  new YouTubeChannelCatalogSync(db,store,access,youtube);

 private com.fasterxml.jackson.databind.JsonNode video(String privacy,
      boolean embeddable,long seconds) throws Exception {
  return mapper.readTree("""
    {"id":"abCDefgH123",
     "snippet":{"channelId":"UC_VALID","title":"A real channel upload",
       "description":"Actual creator content","publishedAt":"2026-11-01T10:00:00Z"},
     "status":{"privacyStatus":"%s","embeddable":%s},
     "contentDetails":{"duration":"PT%dS"},
     "statistics":{"viewCount":"1453","likeCount":"78","commentCount":"11"}}
    """.formatted(privacy,embeddable,seconds));
 }

 @Test void admitsPublicEmbeddableVideosWithRealCounts() throws Exception {
  var info=YouTubeChannelCatalogSync.parsePublicVideo(
    video("public",true,45),"UC_VALID");
  assertNotNull(info);
  assertEquals("abCDefgH123",info.id());
  assertEquals(1453L,info.views());
  assertEquals(78L,info.likes());
  assertTrue(info.shortCandidate());
 }
 @Test void rejectsPrivateUnlistedNonEmbeddableAndOtherChannels() throws Exception {
  assertNull(YouTubeChannelCatalogSync.parsePublicVideo(
    video("private",true,12),"UC_VALID"));
  assertNull(YouTubeChannelCatalogSync.parsePublicVideo(
    video("unlisted",true,12),"UC_VALID"));
  assertNull(YouTubeChannelCatalogSync.parsePublicVideo(
    video("public",false,12),"UC_VALID"));
  assertNull(YouTubeChannelCatalogSync.parsePublicVideo(
    video("public",true,12),"UC_OTHER"));
 }
 @Test void doesNotMislabelLongVideosAsShortCandidates() throws Exception {
  assertFalse(YouTubeChannelCatalogSync.parsePublicVideo(
    video("public",true,181),"UC_VALID").shortCandidate());
 }
 @Test void synchronizesUploadsPlaylistWithoutSearchOrScraping() throws Exception {
  var channel=new YouTubeCredentialStore.ChannelSummary(
    "UC_VALID","Existing channel",Instant.parse("2026-10-01T12:00:00Z"));
  when(access.forChannel("UC_VALID")).thenReturn("access");
  when(youtube.readVideoCatalog(eq("channels"),anyMap(),eq("access")))
    .thenReturn(mapper.readTree("""
      {"items":[{"id":"UC_VALID",
        "contentDetails":{"relatedPlaylists":{"uploads":"UU_VALID"}}}]}
    """));
  when(youtube.readVideoCatalog(eq("playlistItems"),anyMap(),eq("access")))
    .thenReturn(mapper.readTree("""
      {"items":[{"contentDetails":{"videoId":"abCDefgH123"}}]}
    """));
  when(youtube.readVideoCatalog(eq("videos"),anyMap(),eq("access")))
    .thenReturn(mapper.readTree("""
      {"items":[{"id":"abCDefgH123",
        "snippet":{"channelId":"UC_VALID","title":"Real Shorts",
          "description":"","publishedAt":"2026-11-01T10:00:00Z"},
        "status":{"privacyStatus":"public","embeddable":true},
        "contentDetails":{"duration":"PT45S"},
        "statistics":{"viewCount":"100"}}]}
    """));
  sync.syncChannel(channel);
  verify(youtube).readVideoCatalog(eq("channels"),anyMap(),eq("access"));
  verify(youtube).readVideoCatalog(eq("playlistItems"),anyMap(),eq("access"));
  verify(youtube).readVideoCatalog(eq("videos"),anyMap(),eq("access"));
  verify(db,atLeastOnce()).update(
    contains("INSERT INTO youtube_public_channel_catalog"),any(Object[].class));
 }
}
