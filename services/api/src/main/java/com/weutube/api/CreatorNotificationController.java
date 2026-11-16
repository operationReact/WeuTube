package com.weutube.api;

import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

/** Read-only activity feed based on real persisted creator events. */
@RestController
@RequestMapping("/api/creator/notifications")
public class CreatorNotificationController {
 private final JdbcTemplate jdbc;
 public CreatorNotificationController(JdbcTemplate jdbc) {this.jdbc=jdbc;}
 public record Notice(UUID id,String category,String title,String message,Instant occurredAt) {}
 @GetMapping
 @Transactional(readOnly=true)
 public List<Notice> mine(@AuthenticationPrincipal Jwt jwt) {
  return jdbc.query("""
   SELECT id,category,title,message,occurred_at
   FROM (
     SELECT r.id,'VIDEO_REVIEW' AS category,
       CASE WHEN r.decision='APPROVED' THEN 'Video approved'
            ELSE 'Video needs changes' END AS title,
       v.title AS message,r.created_at AS occurred_at
     FROM video_review_events r
     JOIN video_submissions v ON v.id=r.video_id
     JOIN creators c ON c.id=v.creator_id
     WHERE c.cognito_sub=?
     UNION ALL
     SELECT p.id,'PAYOUT' AS category,
       CASE WHEN p.status='APPROVED' THEN 'Withdrawal approved'
            WHEN p.status='REJECTED' THEN 'Withdrawal rejected'
            WHEN p.status='COMPLETED' THEN 'Withdrawal completed'
            ELSE 'Withdrawal requested' END AS title,
       p.status AS message,p.created_at AS occurred_at
     FROM payout_requests p
     JOIN creators c ON c.id=p.creator_id
     WHERE c.cognito_sub=?
   ) events
   ORDER BY occurred_at DESC,id DESC LIMIT 50
   """,(rs,i)->new Notice((UUID)rs.getObject(1),rs.getString(2),
      rs.getString(3),rs.getString(4),rs.getTimestamp(5).toInstant()),
    jwt.getSubject(),jwt.getSubject());
 }
}
