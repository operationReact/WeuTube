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
  String duration,boolean demo,Instant publishedAt,String avatarUrl) {}
 public record FeedResponse(List<FeedItem> items,int realCount,int demoCount,
    boolean demoContentIncluded) {}

 private static final List<FeedItem> DEMO=DemoSocialCatalog.items();

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
     v.created_at,v.category,v.description,
     (SELECT COUNT(*) FROM social_video_likes l WHERE l.video_id=v.id),
     (SELECT COUNT(*) FROM social_video_comments cm WHERE cm.video_id=v.id)
   FROM video_submissions v JOIN creators c ON c.id=v.creator_id
   WHERE v.status='PUBLISHED' AND v.youtube_video_id IS NOT NULL
   ORDER BY v.updated_at DESC, v.id DESC LIMIT ?
   """,(rs,i)-> {
    String yt=rs.getString(5);
    String name=rs.getString(3)==null?"Creator":rs.getString(3);
    String handle="@"+name.toLowerCase(Locale.ROOT)
     .replaceAll("[^a-z0-9]+",".").replaceAll("^\\.|\\.$","");
    return new FeedItem(rs.getString(1),rs.getString(2),name,
      rs.getString(4),handle,rs.getString(7),rs.getString(8),
      "https://i.ytimg.com/vi/"+yt+"/hqdefault.jpg",
      null,"https://www.youtube.com/watch?v="+yt,null,
      rs.getLong(9),rs.getLong(10),"",false,
      rs.getTimestamp(6)==null?null:rs.getTimestamp(6).toInstant(),null);
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
