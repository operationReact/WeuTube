package com.weutube.api;

import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

/**
 * One-time OAuth callback completion. State is consumed atomically BEFORE any
 * outbound call, so concurrent callbacks cannot reuse the same authorization.
 * On a provider failure the admin must initiate a fresh authorization.
 */
@Service
public class YouTubeConnectionService {
 private final JdbcTemplate jdbc;
 private final YouTubeCredentialStore credentials;
 private final GoogleYouTubeClient google;

 public YouTubeConnectionService(JdbcTemplate jdbc,
   YouTubeCredentialStore credentials,GoogleYouTubeClient google) {
  this.jdbc=jdbc; this.credentials=credentials; this.google=google;
 }

 public boolean configured() {
  return credentials.configured() && google.configured();
 }

 public ConnectedChannel complete(String state,String code,String error) {
  if (state==null || !state.matches("[A-Za-z0-9_-]{32,128}"))
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid OAuth state");
  if (!configured())
   throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"YouTube OAuth is not configured");

  String adminSub;
  try {
   adminSub=jdbc.queryForObject("""
     UPDATE youtube_oauth_attempts
     SET consumed_at = now()
     WHERE state = ? AND consumed_at IS NULL AND expires_at > now()
     RETURNING admin_sub
     """,String.class,state);
  } catch (EmptyResultDataAccessException ex) {
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Unknown, expired, or already used OAuth state");
  }
  if (error!=null && !error.isBlank())
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Google authorization was not approved");
  if (code==null || code.isBlank() || code.length()>4096)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Missing or invalid authorization code");

  try {
   GoogleYouTubeClient.Tokens tokens=google.exchange(code);
   GoogleYouTubeClient.Channel channel=google.channelFor(tokens.accessToken());
   credentials.saveVerifiedChannel(channel.id(),channel.title(),tokens.refreshToken(),adminSub);
   jdbc.update("""
      INSERT INTO youtube_channels(id,youtube_channel_id,display_name,connected_at)
      VALUES (?,?,?,now())
      ON CONFLICT (youtube_channel_id) DO UPDATE
      SET display_name=EXCLUDED.display_name, connected_at=now()
      """,java.util.UUID.randomUUID(),channel.id(),channel.title());
   return new ConnectedChannel(channel.id(),channel.title(),"connected");
  } catch (GoogleYouTubeClient.ProviderException ex) {
   // Do not return Google exception details or credential values to the browser.
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,"Google channel connection failed; retry authorization");
  }
 }

 public record ConnectedChannel(String channelId,String displayName,String status) {}
}
