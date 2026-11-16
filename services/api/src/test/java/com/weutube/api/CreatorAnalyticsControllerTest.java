package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import org.junit.jupiter.api.Test;

class CreatorAnalyticsControllerTest {
 private final ObjectMapper mapper=new ObjectMapper();

 @Test void sumsOnlyVideosFromExpectedCreatorChannel() throws Exception {
  var response=mapper.readTree("""
   {"items":[
     {"id":"first","snippet":{"channelId":"UC_ALLOWED"},"statistics":{"viewCount":"140","likeCount":"7","commentCount":"3"}},
     {"id":"second","snippet":{"channelId":"UC_OTHER"},"statistics":{"viewCount":"999999","likeCount":"600","commentCount":"600"}}
   ]}
   """);
  var result=CreatorAnalyticsController.parse(response,
    Map.of("first","UC_ALLOWED","second","UC_ALLOWED"));
  assertEquals(140,result.views());
  assertEquals(7,result.likes());
  assertEquals(3,result.comments());
  assertEquals(1,result.verifiedVideos());
  assertTrue(result.partial());
 }
 @Test void missingCountersNeverBecomeInventedRevenue() throws Exception {
  var response=mapper.readTree("""
   {"items":[{"id":"first","snippet":{"channelId":"UC_ALLOWED"},"statistics":{}}]}
   """);
  var result=CreatorAnalyticsController.parse(response,Map.of("first","UC_ALLOWED"));
  assertEquals(0,result.views());
  assertEquals("YOUTUBE_DATA_API",result.source());
  assertFalse(result.partial());
 }
}
