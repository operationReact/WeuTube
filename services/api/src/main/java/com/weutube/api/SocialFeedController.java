package com.weutube.api;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

/**
 * Public discovery feed. Persisted records are returned only for completed,
 * admin-approved, publicly published YouTube uploads.
 * Curated demo fixtures are explicitly flagged and never counted as live
 * creators, views, earnings or monetized content.
 */
@RestController
@RequestMapping("/api/public/social")
public class SocialFeedController {
 private final JdbcTemplate jdbc;
 public SocialFeedController(JdbcTemplate jdbc) {this.jdbc=jdbc;}

 public record FeedItem(String id,String title,String creator,String creatorId,
  String handle,String category,String description,String thumbnailUrl,
  String videoUrl,String youtubeUrl,Long views,long likes,long comments,
  String duration,boolean demo,Instant publishedAt) {}
 public record FeedResponse(List<FeedItem> items,int realCount,int demoCount,
    boolean demoContentIncluded) {}

 private static final List<FeedItem> DEMO=List.of(
  new FeedItem("demo-mountains","A weekend above the clouds","WeuTube Preview",null,
   "@weutube.preview","Travel","A little mountain air and a sunrise worth remembering.",
   "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900&q=82",
   "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4",
   null,24800L,2310,12,"0:15",true,null),
  new FeedItem("demo-ocean","The island nobody told me about","WeuTube Preview",null,
   "@weutube.preview","Travel","Warm light, peaceful coastlines and new discoveries.",
   "https://images.unsplash.com/photo-1500375592092-40eb2168fd21?w=900&q=82",
   "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4",
   null,56200L,4821,21,"0:15",true,null),
  new FeedItem("demo-city","Finding beauty after dark","WeuTube Preview",null,
   "@weutube.preview","Art","An evening stroll through color, culture and city lights.",
   "https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=900&q=82",
   "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4",
   null,32400L,1937,18,"0:15",true,null),
  new FeedItem("demo-camp","The road to nowhere (and everywhere)","WeuTube Preview",null,
   "@weutube.preview","Lifestyle","Small journeys and the joy of slowing down.",
   "https://images.unsplash.com/photo-1473448912268-2022ce9509d8?w=900&q=82",
   "https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
   null,18200L,824,5,"0:15",true,null),
  new FeedItem("demo-stories","Stories around the campfire","WeuTube Preview",null,
   "@weutube.preview","Storytelling","An introduction to our upcoming creator community.",
   "https://images.unsplash.com/photo-1448375240586-882707db888b?w=900&q=82",
   "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
   null,8100L,556,7,"9:56",true,null)
 );

 public static List<FeedItem> demoItems() {return DEMO;}

 @GetMapping("/feed")
 public FeedResponse feed(@RequestParam(defaultValue="") String search,
    @RequestParam(defaultValue="All") String category,
    @RequestParam(defaultValue="20") int limit,
    @RequestParam(defaultValue="true") boolean includeDemo) {
  int cap=Math.max(1,Math.min(40,limit));
  String term=search.strip().toLowerCase(Locale.ROOT);
  if(term.length()>100)term=term.substring(0,100);
  String topic=category.strip().toLowerCase(Locale.ROOT);
  final String searchTerm=term;
  // Public visibility MUST NOT depend on creator-controlled draft status.
  List<FeedItem> live=jdbc.query("""
   SELECT v.id,v.title,c.display_name,c.id,v.youtube_video_id,
     v.created_at,
     (SELECT COUNT(*) FROM social_video_likes l WHERE l.video_id=v.id),
     (SELECT COUNT(*) FROM social_video_comments cm WHERE cm.video_id=v.id)
   FROM video_submissions v JOIN creators c ON c.id=v.creator_id
   WHERE v.status='PUBLISHED' AND v.youtube_video_id IS NOT NULL
   ORDER BY v.updated_at DESC, v.id DESC LIMIT ?
   """,(rs,i)-> {
    String yt=rs.getString(5);
    return new FeedItem(rs.getString(1),rs.getString(2),rs.getString(3),
      rs.getString(4),"@creator","Stories","Published on WeuTube's channel",
      "https://i.ytimg.com/vi/"+yt+"/hqdefault.jpg",
      null,"https://www.youtube.com/watch?v="+yt,null,
      rs.getLong(7),rs.getLong(8),"",false,
      rs.getTimestamp(6)==null?null:rs.getTimestamp(6).toInstant());
   },cap);
  List<FeedItem> output=new ArrayList<>();
  for(FeedItem video:live) {
    if((topic.equals("all")||video.category().toLowerCase(Locale.ROOT).equals(topic))
      && matches(video,searchTerm))output.add(video);
  }
  int realCount=output.size();
  int demoCount=0;
  if(includeDemo) {
   for(FeedItem video:DEMO) {
    if(output.size()>=cap) break;
    if((topic.equals("all")||video.category().toLowerCase(Locale.ROOT).equals(topic))
      && matches(video,searchTerm)) {
      output.add(video);
      demoCount++;
    }
   }
  }
  return new FeedResponse(output,realCount,demoCount,demoCount>0);
 }
 private static boolean matches(FeedItem item,String text) {
  return text.isBlank() || (item.title()+" "+item.creator()+" "+
   item.description()+" "+item.category()).toLowerCase(Locale.ROOT).contains(text);
 }
}
