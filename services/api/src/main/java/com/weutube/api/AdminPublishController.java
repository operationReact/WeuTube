package com.weutube.api;

import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Publishing requires an explicit admin action after a recorded APPROVED review. */
@RestController
@RequestMapping("/api/admin/videos")
public class AdminPublishController {
 private final JdbcTemplate jdbc;
 private final GoogleVideoPublishingService google;
 private final String adminGroup;
 public AdminPublishController(JdbcTemplate jdbc,GoogleVideoPublishingService google,
   @Value("${weutube.security.admin-group:weutube-admin}") String adminGroup) {
  this.jdbc=jdbc;this.google=google;this.adminGroup=adminGroup;
 }
 private void requireAdmin(Jwt jwt) {
  Object raw=jwt.getClaims().get("cognito:groups");
  if (!(raw instanceof java.util.Collection<?> groups)||!groups.contains(adminGroup))
   throw new AccessDeniedException("Admin group required");
 }
 public record Target(String videoId,String channelId,String status) {}
 private Target target(UUID id) {
  var records=jdbc.query("""
   SELECT v.youtube_video_id,c.youtube_channel_id,v.status
   FROM video_submissions v
   JOIN youtube_channels c ON c.id=v.youtube_channel_id
   JOIN youtube_oauth_credentials auth ON auth.youtube_channel_id=c.youtube_channel_id
   WHERE v.id=?
   """,(rs,row)->new Target(rs.getString(1),rs.getString(2),rs.getString(3)),id);
  if(records.isEmpty()||records.get(0).videoId()==null)
   throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Verified YouTube video not found");
  return records.get(0);
 }
 @PostMapping("/{id}/publish")
 public Map<String,String> publish(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  requireAdmin(jwt);
  Target target=target(id);
  if(!"APPROVED".equals(target.status()))
   throw new ResponseStatusException(HttpStatus.CONFLICT,"An approved private review is required");
  int claimed=jdbc.update("""
    UPDATE video_submissions SET status='PUBLISHING',updated_at=now()
    WHERE id=? AND status='APPROVED'
    """,id);
  if(claimed!=1)
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Another publication is in progress");
  try {
   google.publish(target.channelId(),target.videoId());
  } catch(RuntimeException ex) {
   // Do not reissue a potentially successful publish on ambiguous failures.
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
     "YouTube publishing requires verification; use reconcile-publish");
  }
  int updated=jdbc.update("""
    UPDATE video_submissions SET status='PUBLISHED',updated_at=now()
    WHERE id=? AND status='PUBLISHING'
    """,id);
  if(updated!=1)
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Publication succeeded but database reconciliation failed");
  return Map.of("videoId",id.toString(),"status","PUBLISHED");
 }
 @PostMapping("/{id}/reconcile-publish")
 public Map<String,String> reconcile(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  requireAdmin(jwt);
  Target target=target(id);
  if(!"PUBLISHING".equals(target.status())&&!"PUBLISHED".equals(target.status()))
   throw new ResponseStatusException(HttpStatus.CONFLICT,"No publication to reconcile");
  try {
   google.isPublic(target.channelId(),target.videoId());
  } catch(RuntimeException ex) {
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
    "YouTube does not confirm public visibility; do not retry publish blindly");
  }
  jdbc.update("""
    UPDATE video_submissions SET status='PUBLISHED',updated_at=now()
    WHERE id=? AND status='PUBLISHING'
    """,id);
  return Map.of("videoId",id.toString(),"status","PUBLISHED");
 }
}
