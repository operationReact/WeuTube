package com.weutube.api;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Account-level read-only diagnostic. A missing channel grant must never be
 * confused with a rejected Cognito session. Returns no user IDs or secrets.
 */
@RestController
@RequestMapping("/api/creator/session")
public class CreatorSessionController {
 private final JdbcTemplate jdbc;
 public CreatorSessionController(JdbcTemplate jdbc) {this.jdbc=jdbc;}

 public record CreatorSession(boolean authenticated,String uploadAccess,
   boolean channelGranted,boolean channelConnected) {}

 @GetMapping
 public CreatorSession status(@AuthenticationPrincipal Jwt jwt) {
  Boolean granted=jdbc.queryForObject("""
    SELECT EXISTS(
      SELECT 1 FROM creator_channel_grants g
      JOIN creators c ON c.id=g.creator_id
      WHERE c.cognito_sub=?
    )
    """,Boolean.class,jwt.getSubject());
  Boolean connected=jdbc.queryForObject("""
    SELECT EXISTS(
      SELECT 1 FROM creator_channel_grants g
      JOIN creators c ON c.id=g.creator_id
      JOIN youtube_channels y
        ON y.youtube_channel_id=g.youtube_channel_id
      JOIN youtube_oauth_credentials auth
        ON auth.youtube_channel_id=y.youtube_channel_id
      WHERE c.cognito_sub=?
    )
    """,Boolean.class,jwt.getSubject());
  boolean hasGrant=Boolean.TRUE.equals(granted);
  boolean hasConnection=Boolean.TRUE.equals(connected);
  String access=!hasGrant?"NO_CHANNEL_GRANT":
    !hasConnection?"CHANNEL_NOT_CONNECTED":"READY";
  return new CreatorSession(true,access,hasGrant,hasConnection);
 }
}
