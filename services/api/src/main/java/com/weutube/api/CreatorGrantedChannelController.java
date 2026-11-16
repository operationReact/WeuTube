package com.weutube.api;

import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

/** Creator selects only from owner-authorized, currently connected channels. */
@RestController
@RequestMapping("/api/creator/channels")
public class CreatorGrantedChannelController {
 private final JdbcTemplate jdbc;
 private final boolean autoUploadEnabled;
 public CreatorGrantedChannelController(JdbcTemplate jdbc,
   @Value("${weutube.youtube.creator-auto-upload-enabled:false}") boolean autoUploadEnabled) {
  this.jdbc=jdbc;
  this.autoUploadEnabled=autoUploadEnabled;
 }
 public record GrantedChannel(String channelId,String displayName) {}

 /**
  * Self-service access is restricted to the single OAuth-connected platform
  * channel, enabled explicitly by the operator. It never issues Google tokens,
  * grants publication rights, or bypasses an administrator's revocation.
  */
 @PostMapping("/activate")
 @Transactional
 public GrantedChannel activate(@AuthenticationPrincipal Jwt jwt) {
  if(!autoUploadEnabled)
   throw new ResponseStatusException(HttpStatus.FORBIDDEN,
     "Creator uploads have not been enabled on this server");
  List<GrantedChannel> connected=jdbc.query("""
    SELECT y.youtube_channel_id,y.display_name FROM youtube_channels y
    JOIN youtube_oauth_credentials oauth
      ON oauth.youtube_channel_id=y.youtube_channel_id
    ORDER BY y.youtube_channel_id LIMIT 2
    """,(rs,i)->new GrantedChannel(rs.getString(1),rs.getString(2)));
  if(connected.isEmpty())
   throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
     "No YouTube channel is connected. An administrator must authorize it with Google");
  if(connected.size()!=1)
   throw new ResponseStatusException(HttpStatus.CONFLICT,
     "Multiple YouTube channels are connected; an administrator must select the upload channel");
  GrantedChannel chosen=connected.get(0);
  String sub=jwt.getSubject();
  Boolean blocked=jdbc.queryForObject("""
    SELECT EXISTS(SELECT 1 FROM creator_channel_auto_upload_blocks
      WHERE creator_sub=? AND youtube_channel_id=?)
    """,Boolean.class,sub,chosen.channelId());
  if(Boolean.TRUE.equals(blocked))
   throw new ResponseStatusException(HttpStatus.FORBIDDEN,
     "Your upload access was revoked by an administrator");
  jdbc.update("""
    INSERT INTO creators(id,cognito_sub,display_name)
      VALUES (?,?,?) ON CONFLICT(cognito_sub) DO NOTHING
    """,UUID.randomUUID(),sub,"Creator");
  jdbc.update("""
    INSERT INTO creator_channel_grants(creator_id,youtube_channel_id,granted_by_sub)
      SELECT id,?,? FROM creators WHERE cognito_sub=?
    ON CONFLICT (creator_id,youtube_channel_id) DO NOTHING
    """,chosen.channelId(),"weutube:creator-onboarding",sub);
  return chosen;
 }

 @GetMapping
 @Transactional(readOnly=true)
 public List<GrantedChannel> mine(@AuthenticationPrincipal Jwt jwt) {
  return jdbc.query("""
    SELECT y.youtube_channel_id,y.display_name
    FROM creator_channel_grants g
    JOIN creators c ON c.id=g.creator_id
    JOIN youtube_channels y ON y.youtube_channel_id=g.youtube_channel_id
    JOIN youtube_oauth_credentials oauth ON oauth.youtube_channel_id=y.youtube_channel_id
    WHERE c.cognito_sub=?
    ORDER BY y.display_name,y.youtube_channel_id LIMIT 30
    """,(rs,i)->new GrantedChannel(rs.getString(1),rs.getString(2)),jwt.getSubject());
 }
}
