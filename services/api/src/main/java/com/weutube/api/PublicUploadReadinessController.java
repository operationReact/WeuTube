package com.weutube.api;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Public, non-secret deployment diagnostic. A database record is NOT proof
 * that Google's refresh token is still usable or that an upload succeeded.
 * Do not return OAuth tokens, channel IDs, or creator identity.
 */
@RestController
@RequestMapping("/api/public/upload-readiness")
public class PublicUploadReadinessController {
 private final JdbcTemplate jdbc;
 private final boolean autoUploadEnabled;
 private final String releaseSha;

 public PublicUploadReadinessController(JdbcTemplate jdbc,
   @Value("${weutube.youtube.creator-auto-upload-enabled:false}") boolean autoUploadEnabled,
   @Value("${weutube.release-sha:unversioned}") String releaseSha) {
  this.jdbc=jdbc;
  this.autoUploadEnabled=autoUploadEnabled;
  this.releaseSha=releaseSha;
 }

 public record Readiness(String revision,String state,
   boolean creatorOnboardingEnabled,boolean singleConnectedChannelRecorded) {}

 @GetMapping
 public ResponseEntity<Readiness> status() {
  Integer count=jdbc.queryForObject("""
    SELECT COUNT(*) FROM (
      SELECT 1 FROM youtube_channels y
      JOIN youtube_oauth_credentials auth
        ON auth.youtube_channel_id=y.youtube_channel_id
      LIMIT 2
    ) connected
    """,Integer.class);
  int channelCount=count==null?0:count;
  String state=!autoUploadEnabled?"CREATOR_ONBOARDING_DISABLED"
    :channelCount==0?"GOOGLE_CHANNEL_CONNECTION_REQUIRED"
    :channelCount>1?"CHANNEL_SELECTION_REQUIRED":"CHANNEL_RECORD_PRESENT";
  return ResponseEntity.ok().cacheControl(CacheControl.noStore())
    .body(new Readiness(releaseSha,state,autoUploadEnabled,
      channelCount==1));
 }
}
