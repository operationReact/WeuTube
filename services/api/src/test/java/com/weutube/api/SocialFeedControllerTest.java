package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;

class SocialFeedControllerTest {
 private final JdbcTemplate jdbc=mock(JdbcTemplate.class);
 private final YouTubeChannelCatalogSync catalog=mock(YouTubeChannelCatalogSync.class);
 private final SocialFeedController controller=new SocialFeedController(jdbc,catalog,true);
 {
  when(jdbc.query(anyString(),any(RowMapper.class),eq(false),eq(20))).thenReturn(List.of());
  when(catalog.status()).thenReturn(
    new YouTubeChannelCatalogSync.SyncState("NOT_CONNECTED",0,0,0,null));
 }


 @Test void emptyProductionDatabaseStillGivesClearlyFlaggedDemoPosts() {
  when(jdbc.query(anyString(),any(RowMapper.class),eq(20))).thenReturn(List.of());
  var result=controller.feed("","All",20,true);
  assertEquals(0,result.realCount());
  assertEquals(12,result.demoCount());
  assertTrue(result.demoContentIncluded());
  assertTrue(result.items().stream().allMatch(SocialFeedController.FeedItem::demo));
  assertTrue(result.items().stream().allMatch(i->i.id().startsWith("demo-")));
 }
 @Test void discoveryFiltersDemoWithoutInventingRealPublication() {
  when(jdbc.query(anyString(),any(RowMapper.class),eq(20))).thenReturn(List.of());
  var result=controller.feed("grandmother","Food",20,true);
  assertEquals(1,result.items().size());
  assertEquals("demo-food",result.items().get(0).id());
  assertEquals(0,result.realCount());
 }
 @Test void productionRejectsDemoEvenIfOldApkForcesIncludeDemoTrue() {
  var production=new SocialFeedController(jdbc,catalog,false);
  when(jdbc.query(anyString(),any(RowMapper.class),eq(20))).thenReturn(List.of());
  var result=production.feed("","All",20,true);
  assertEquals(0,result.demoCount());
  assertFalse(result.demoContentIncluded());
  assertTrue(result.items().isEmpty());
 }
 @Test void productionDefaultsNeverEnableDemoContent() {
  when(jdbc.query(anyString(),any(RowMapper.class),eq(40))).thenReturn(List.of());
  when(jdbc.query(anyString(),any(RowMapper.class),eq(false),eq(40))).thenReturn(List.of());
  var result=controller.feed("","All",40,false);
  assertEquals(0,result.demoCount());
  assertEquals("NOT_CONNECTED",result.channelSyncStatus());
  assertEquals(0,result.connectedChannels());
  assertTrue(result.items().isEmpty());
 }
 @Test void shortsEndpointDoesNotIncludeDemoFixtures() {
  when(jdbc.query(anyString(),any(RowMapper.class),eq(true),eq(40))).thenReturn(List.of());
  when(jdbc.query(anyString(),any(RowMapper.class),eq(40))).thenReturn(List.of());
  var result=controller.shorts("",40);
  assertEquals(0,result.demoCount());
  assertTrue(result.items().isEmpty());
 }
 @Test void noFixtureModeNeverLeaksDemoIntoRealFeed() {
  when(jdbc.query(anyString(),any(RowMapper.class),eq(20))).thenReturn(List.of());
  var result=controller.feed("","All",20,false);
  assertEquals(0,result.items().size());
  assertEquals(0,result.demoCount());
 }
}
