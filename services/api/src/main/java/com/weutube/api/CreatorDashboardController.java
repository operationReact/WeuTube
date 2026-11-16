package com.weutube.api;

import java.util.List;
import java.util.Map;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

/** Account-scoped dashboard data; never invent views, subscribers or RPM. */
@RestController
@RequestMapping("/api/creator/dashboard")
public class CreatorDashboardController {
 private final JdbcTemplate jdbc;
 public CreatorDashboardController(JdbcTemplate jdbc) { this.jdbc=jdbc; }
 public record VideoStatusCount(String status,long count) {}
 public record Dashboard(long videos,long drafts,long pendingReview,long published,
   List<VideoStatusCount> statuses,Long views,Long subscribers,String analyticsStatus) {}

 @GetMapping
 @Transactional(readOnly=true)
 public Dashboard overview(@AuthenticationPrincipal Jwt jwt) {
  String sub=jwt.getSubject();
  List<VideoStatusCount> statuses=jdbc.query("""
    SELECT v.status,COUNT(*) FROM video_submissions v
    JOIN creators c ON c.id=v.creator_id
    WHERE c.cognito_sub=? GROUP BY v.status
    ORDER BY v.status
    """,(rs,i)->new VideoStatusCount(rs.getString(1),rs.getLong(2)),sub);
  long total=0,drafts=0,pending=0,published=0;
  for(var status:statuses) {
   total+=status.count();
   switch(status.status()) {
    case "DRAFT" -> drafts+=status.count();
    case "PRIVATE_REVIEW" -> pending+=status.count();
    case "PUBLISHED" -> published+=status.count();
    default -> {}
   }
  }
  // Without YouTube Analytics authorization, null is more honest than a fabricated zero.
  return new Dashboard(total,drafts,pending,published,statuses,null,null,"NOT_CONNECTED");
 }
}
