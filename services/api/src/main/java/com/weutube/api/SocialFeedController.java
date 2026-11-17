package com.weutube.api;

import java.time.Instant;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;

/**
 * Public social feed: includes vetted WeuTube publications AND previously
 * uploaded public embeddable videos imported from OAuth-connected YouTube
 * channels. Demo fixtures are opt-in for development only.
 */
@RestController
@RequestMapping("/api/public/social")
public class SocialFeedController {
 private final JdbcTemplate jdbc;
 private final YouTubeChannelCatalogSync catalog;
 private final boolean demoEnabled;

 @Autowired
 public SocialFeedController(JdbcTemplate jdbc,YouTubeChannelCatalogSync catalog,
     @Value("${weutube.social.demo-enabled:false}") boolean demoEnabled) {
  this.jdbc=jdbc;this.catalog=catalog;this.demoEnabled=demoEnabled;
 }
 SocialFeedController(JdbcTemplate jdbc,YouTubeChannelCatalogSync catalog) {
  this(jdbc,catalog,false);
 }

 public record FeedItem(String id,String title,String creator,String creatorId,
  String handle,String category,String description,String thumbnailUrl,
  String videoUrl,String youtubeUrl,Long views,long likes,long comments,
  String duration,boolean demo,Instant publishedAt,String avatarUrl) {}
 public record FeedResponse(List<FeedItem> items,int realCount,int demoCount,
   boolean demoContentIncluded,String channelSyncStatus,int connectedChannels,
   int importedVideos,int shortCandidates,Instant lastSyncedAt) {}
 private static final List<FeedItem> DEMO=DemoSocialCatalog.items();
 public static List<FeedItem> demoItems(){return DEMO;}

 @GetMapping("/feed")
 public FeedResponse feed(@RequestParam(defaultValue="") String search,
     @RequestParam(defaultValue="All") String category,
     @RequestParam(defaultValue="40") int limit,
     @RequestParam(defaultValue="false") boolean includeDemo) {
  return build(search,category,limit,includeDemo,false);
 }

 @GetMapping("/shorts")
 public FeedResponse shorts(@RequestParam(defaultValue="") String search,
     @RequestParam(defaultValue="40") int limit) {
  // API currently knows only public videos <=180 seconds; this is a short
  // video *candidate*, not a YouTube-certified vertical/Shorts format label.
  return build(search,"All",limit,false,true);
 }

 private FeedResponse build(String search,String category,int limit,
     boolean includeDemo,boolean shorts) {
  int cap=Math.max(1,Math.min(60,limit));
  String term=search==null?"":search.strip().toLowerCase(Locale.ROOT);
  if(term.length()>100)term=term.substring(0,100);
  String topic=category==null?"all":category.strip().toLowerCase(Locale.ROOT);
  String searchTerm=term;
  List<FeedItem> local=jdbc.query("""
    SELECT v.id,v.title,c.display_name,c.id,v.youtube_video_id,
      v.created_at,v.category,v.description,
      (SELECT COUNT(*) FROM social_video_likes l WHERE l.video_id=v.id),
      (SELECT COUNT(*) FROM social_video_comments cm WHERE cm.video_id=v.id)
    FROM video_submissions v JOIN creators c ON c.id=v.creator_id
    WHERE v.status='PUBLISHED' AND v.youtube_video_id IS NOT NULL
    ORDER BY v.updated_at DESC,v.id DESC LIMIT ?
    """,(rs,i)-> {
     String yt=rs.getString(5),name=rs.getString(3);
     if(name==null||name.isBlank())name="Creator";
     String handle="@"+name.toLowerCase(Locale.ROOT)
       .replaceAll("[^a-z0-9]+",".").replaceAll("^\\.|\\.$","");
     return new FeedItem(rs.getString(1),rs.getString(2),name,
       rs.getString(4),handle,rs.getString(7),rs.getString(8),
       "https://i.ytimg.com/vi/"+yt+"/hqdefault.jpg",
       null,"https://www.youtube.com/watch?v="+yt,null,
       rs.getLong(9),rs.getLong(10),"",false,
       rs.getTimestamp(6)==null?null:rs.getTimestamp(6).toInstant(),null);
    },cap);

  List<FeedItem> imported=jdbc.query("""
    SELECT youtube_video_id,title,channel_title,youtube_channel_id,
      description,thumbnail_url,published_at,duration_seconds,
      view_count,like_count,comment_count
    FROM youtube_public_channel_catalog
    WHERE (NOT ? OR short_candidate)
      AND last_seen_at >= now() - interval '2 hours'
    ORDER BY published_at DESC,youtube_video_id DESC LIMIT ?
    """,(rs,i)->{
     String yt=rs.getString(1),name=rs.getString(3);
     String handle="@"+name.toLowerCase(Locale.ROOT)
       .replaceAll("[^a-z0-9]+",".").replaceAll("^\\.|\\.$","");
     Object views=rs.getObject(9);
     Object likes=rs.getObject(10);
     Object comments=rs.getObject(11);
     int seconds=rs.getInt(8);
     String duration=String.format("%d:%02d",seconds/60,seconds%60);
     return new FeedItem("yt-"+yt,rs.getString(2),name,
       rs.getString(4),handle,"YouTube",rs.getString(5),rs.getString(6),
       null,"https://www.youtube.com/watch?v="+yt,
       views instanceof Number n?n.longValue():null,
       likes instanceof Number n?n.longValue():0L,
       comments instanceof Number n?n.longValue():0L,
       duration,false,rs.getTimestamp(7).toInstant(),null);
    },shorts,cap);

  List<FeedItem> result=new ArrayList<>();
  Set<String> youtubeIds=new HashSet<>();
  for(FeedItem item:local) {
   if(!shorts) {
    result.add(item);
    String id=item.youtubeUrl().replace("https://www.youtube.com/watch?v=","");
    youtubeIds.add(id);
   }
  }
  for(FeedItem item:imported) {
   if(youtubeIds.add(item.id().substring(3)) &&
     (topic.equals("all")||topic.equals(item.category().toLowerCase(Locale.ROOT))) &&
     matches(item,searchTerm))
    result.add(item);
  }
  result.removeIf(item->!matches(item,searchTerm) ||
      (!topic.equals("all")&&!topic.equals(item.category().toLowerCase(Locale.ROOT))));
  result.sort(Comparator.comparing(FeedItem::publishedAt,
    Comparator.nullsLast(Comparator.reverseOrder())));
  if(result.size()>cap)result=new ArrayList<>(result.subList(0,cap));
  int realCount=result.size(),demoCount=0;
  if(includeDemo && demoEnabled)for(FeedItem item:DEMO) {
   if(result.size()>=cap)break;
   if((topic.equals("all")||item.category().toLowerCase(Locale.ROOT).equals(topic))
       &&matches(item,searchTerm)){result.add(item);demoCount++;}
  }
  YouTubeChannelCatalogSync.SyncState state=catalog.status();
  return new FeedResponse(result,realCount,demoCount,demoCount>0,
    state.status(),state.channelCount(),state.videoCount(),
    state.shortCandidates(),state.lastSuccessAt());
 }

 private static boolean matches(FeedItem item,String term) {
  return term.isBlank()||(item.title()+" "+item.creator()+" "+
    item.description()+" "+item.category())
    .toLowerCase(Locale.ROOT).contains(term);
 }
}
