package com.weutube.api;

import java.util.List;
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
 public CreatorGrantedChannelController(JdbcTemplate jdbc) {this.jdbc=jdbc;}
 public record GrantedChannel(String channelId,String displayName) {}

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
