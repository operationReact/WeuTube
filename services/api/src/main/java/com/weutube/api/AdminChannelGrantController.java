package com.weutube.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Only a Cognito admin can authorize creators to upload to an owner-controlled channel. */
@RestController
@RequestMapping("/api/admin/channels")
public class AdminChannelGrantController {
 private final JdbcTemplate jdbc;
 private final String adminGroup;
 public AdminChannelGrantController(JdbcTemplate jdbc,
   @Value("${weutube.security.admin-group:weutube-admin}") String adminGroup) {
  this.jdbc=jdbc;this.adminGroup=adminGroup;
 }
 private void requireAdmin(Jwt jwt) {
  Object groups=jwt.getClaims().get("cognito:groups");
  if (!(groups instanceof java.util.Collection<?> values) || !values.contains(adminGroup))
   throw new AccessDeniedException("Admin group required");
 }
 public record GrantRequest(@NotBlank @Size(max=128) String creatorSubject) {}

 /** Admin can grant the connected channel to their own verified creator account,
  * without copying a Cognito subject into the UI or widening permissions. */
 @PostMapping("/{channelId}/grant-me")
 @Transactional
 public Map<String,String> grantMe(@AuthenticationPrincipal Jwt jwt,
     @PathVariable String channelId) {
  requireAdmin(jwt);
  return grant(jwt,channelId,new GrantRequest(jwt.getSubject()));
 }
 @PostMapping("/{channelId}/creators")
 @Transactional
 public Map<String,String> grant(@AuthenticationPrincipal Jwt jwt,
    @PathVariable String channelId,@Valid @RequestBody GrantRequest input) {
  requireAdmin(jwt);
  if(channelId.isBlank() || channelId.length()>128)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid channel");
  int changed=jdbc.update("""
   INSERT INTO creator_channel_grants(creator_id,youtube_channel_id,granted_by_sub)
   SELECT c.id,y.youtube_channel_id,? FROM creators c
   CROSS JOIN youtube_channels y
   JOIN youtube_oauth_credentials auth ON auth.youtube_channel_id=y.youtube_channel_id
   WHERE c.cognito_sub=? AND y.youtube_channel_id=?
   ON CONFLICT (creator_id,youtube_channel_id) DO NOTHING
   """,jwt.getSubject(),input.creatorSubject(),channelId);
  if(changed==0) {
   Integer count=jdbc.queryForObject("""
    SELECT COUNT(*) FROM creator_channel_grants g
    JOIN creators c ON g.creator_id=c.id
    WHERE c.cognito_sub=? AND g.youtube_channel_id=?
    """,Integer.class,input.creatorSubject(),channelId);
   if(count==null || count==0)
    throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Creator or connected channel not found");
  }
  return Map.of("creatorSubject",input.creatorSubject(),"channelId",channelId,"status","granted");
 }
 @DeleteMapping("/{channelId}/creators/{creatorSubject}")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 @Transactional
 public void revoke(@AuthenticationPrincipal Jwt jwt,
    @PathVariable String channelId,@PathVariable String creatorSubject) {
  requireAdmin(jwt);
  jdbc.update("""
   DELETE FROM creator_channel_grants WHERE youtube_channel_id=?
   AND creator_id IN (SELECT id FROM creators WHERE cognito_sub=?)
   """,channelId,creatorSubject);
 }
}
