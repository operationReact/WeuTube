package com.weutube.api;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/**
 * Creates one-time, short-lived OAuth authorization attempts.
 * The callback must exchange and securely store Google tokens before activating a channel.
 */
@RestController
@RequestMapping("/api/admin/youtube")
public class YouTubeOAuthController {
 private static final SecureRandom RANDOM = new SecureRandom();
 private final JdbcTemplate jdbc;
 private final YouTubeCredentialStore credentials;
 private final String clientId;
 private final String redirectUri;
 private final String adminGroup;

 public YouTubeOAuthController(JdbcTemplate jdbc,YouTubeCredentialStore credentials,
   @Value("${weutube.youtube.client-id:}") String clientId,
   @Value("${weutube.youtube.redirect-uri:}") String redirectUri,
   @Value("${weutube.security.admin-group:weutube-admin}") String adminGroup) {
  this.jdbc=jdbc; this.credentials=credentials; this.clientId=clientId; this.redirectUri=redirectUri; this.adminGroup=adminGroup;
 }
 private void requireAdmin(Jwt jwt) {
  Object raw=jwt.getClaims().get("cognito:groups");
  if (!(raw instanceof java.util.Collection<?> groups) || !groups.contains(adminGroup))
   throw new org.springframework.security.access.AccessDeniedException("Admin group required");
 }
 private static String enc(String value) {
  return URLEncoder.encode(value,StandardCharsets.UTF_8);
 }
 public record AuthorizationUrl(String url,Instant expiresAt) {}
 @GetMapping("/channels")
 public java.util.List<YouTubeCredentialStore.ChannelSummary> channels(@AuthenticationPrincipal Jwt jwt) {
  requireAdmin(jwt);
  return credentials.connectedChannels();
 }
 @PostMapping("/authorization")
 @Transactional
 public AuthorizationUrl start(@AuthenticationPrincipal Jwt jwt) {
  requireAdmin(jwt);
  if (clientId.isBlank() || redirectUri.isBlank() || !redirectUri.startsWith("https://"))
   throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"Google OAuth is not configured");
  byte[] random=new byte[32];
  RANDOM.nextBytes(random);
  String state=Base64.getUrlEncoder().withoutPadding().encodeToString(random);
  Instant expires=Instant.now().plus(Duration.ofMinutes(10));
  jdbc.update("INSERT INTO youtube_oauth_attempts(id,state,admin_sub,expires_at) VALUES (?,?,?,?)",
   UUID.randomUUID(),state,jwt.getSubject(),expires);
  String url="https://accounts.google.com/o/oauth2/v2/auth?client_id="+enc(clientId)
    +"&redirect_uri="+enc(redirectUri)
    +"&response_type=code&scope="+enc("https://www.googleapis.com/auth/youtube.upload https://www.googleapis.com/auth/youtube.readonly")
    +"&access_type=offline&prompt=consent&state="+enc(state);
  return new AuthorizationUrl(url,expires);
 }
 @GetMapping("/callback")
 public Map<String,String> callback(@RequestParam String state,@RequestParam(required=false) String code) {
  // Do not exchange credentials until encrypted storage and channel verification exist.
  // Validate state without consuming it: this callback is intentionally non-operational.
  if (state == null || state.isBlank() || state.length() > 128)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid OAuth state");
  Integer valid=jdbc.queryForObject(
   "SELECT count(*) FROM youtube_oauth_attempts WHERE state = ? AND expires_at > now() AND consumed_at IS NULL",
   Integer.class,state);
  if (valid == null || valid != 1)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Unknown or expired OAuth state");
  if (code == null || code.isBlank())
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Missing authorization code");
  throw new ResponseStatusException(HttpStatus.NOT_IMPLEMENTED,
   "OAuth token exchange is disabled until encrypted storage and channel verification are ready");
 }
}
