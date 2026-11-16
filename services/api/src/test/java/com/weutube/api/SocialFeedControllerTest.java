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
 private final SocialFeedController controller=new SocialFeedController(jdbc);

 @Test void emptyProductionDatabaseStillGivesClearlyFlaggedDemoPosts() {
  when(jdbc.query(anyString(),any(RowMapper.class),eq(20))).thenReturn(List.of());
  var result=controller.feed("","All",20,true);
  assertEquals(0,result.realCount());
  assertEquals(5,result.demoCount());
  assertTrue(result.demoContentIncluded());
  assertTrue(result.items().stream().allMatch(SocialFeedController.FeedItem::demo));
  assertTrue(result.items().stream().allMatch(i->i.id().startsWith("demo-")));
 }
 @Test void discoveryFiltersDemoWithoutInventingRealPublication() {
  when(jdbc.query(anyString(),any(RowMapper.class),eq(20))).thenReturn(List.of());
  var result=controller.feed("island","Travel",20,true);
  assertEquals(1,result.items().size());
  assertEquals("demo-ocean",result.items().get(0).id());
  assertEquals(0,result.realCount());
 }
 @Test void noFixtureModeNeverLeaksDemoIntoRealFeed() {
  when(jdbc.query(anyString(),any(RowMapper.class),eq(20))).thenReturn(List.of());
  var result=controller.feed("","All",20,false);
  assertEquals(0,result.items().size());
  assertEquals(0,result.demoCount());
 }
}
