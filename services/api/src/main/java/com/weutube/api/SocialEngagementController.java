package com.weutube.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/**
 * Authenticated engagement for real, published content. The server NEVER stores
 * "demo-*" activity. Every operation is bound to the JWT creator identity.
 */
@RestController
@RequestMapping("/api/social")
public class SocialEngagementController {
 private final JdbcTemplate jdbc;
 private final CreatorRepository creators;
 public SocialEngagementController(JdbcTemplate jdbc,CreatorRepository creators) {
  this.jdbc=jdbc;this.creators=creators;
 }
 public record Comment(UUID id,String creator,String content,Instant createdAt) {}
 public record CommentInput(@NotBlank @Size(max=400) String text) {}

 private UUID current(Jwt jwt) {
  return creators.findByCognitoSub(jwt.getSubject())
   .orElseGet(()->creators.save(new Creator(jwt.getSubject(),"Creator"))).id;
 }
 private void requirePublished(UUID video) {
  Integer count=jdbc.queryForObject("""
   SELECT COUNT(*) FROM video_submissions
   WHERE id=? AND status='PUBLISHED' AND youtube_video_id IS NOT NULL
   """,Integer.class,video);
  if(count==null||count==0)
   throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Published video not found");
 }
 @PutMapping("/videos/{id}/like")
 @Transactional
 public Map<String,Boolean> like(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  requirePublished(id);
  jdbc.update("""
   INSERT INTO social_video_likes(video_id,creator_id) VALUES (?,?)
   ON CONFLICT DO NOTHING
   """,id,current(jwt));
  return Map.of("liked",true);
 }
 @DeleteMapping("/videos/{id}/like")
 @Transactional
 public Map<String,Boolean> unlike(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  jdbc.update("DELETE FROM social_video_likes WHERE video_id=? AND creator_id=?",
   id,current(jwt));
  return Map.of("liked",false);
 }
 @PutMapping("/videos/{id}/save")
 @Transactional
 public Map<String,Boolean> save(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  requirePublished(id);
  jdbc.update("""
   INSERT INTO social_video_saves(video_id,creator_id) VALUES (?,?)
   ON CONFLICT DO NOTHING
   """,id,current(jwt));
  return Map.of("saved",true);
 }
 @DeleteMapping("/videos/{id}/save")
 @Transactional
 public Map<String,Boolean> unsave(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  jdbc.update("DELETE FROM social_video_saves WHERE video_id=? AND creator_id=?",
   id,current(jwt));
  return Map.of("saved",false);
 }
 @PutMapping("/creators/{id}/follow")
 @Transactional
 public Map<String,Boolean> follow(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  UUID follower=current(jwt);
  if(follower.equals(id))
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Cannot follow yourself");
  Integer count=jdbc.queryForObject("SELECT COUNT(*) FROM creators WHERE id=?",Integer.class,id);
  if(count==null||count==0)
   throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Creator not found");
  jdbc.update("""
   INSERT INTO social_creator_follows(follower_id,followed_id) VALUES (?,?)
   ON CONFLICT DO NOTHING
   """,follower,id);
  return Map.of("following",true);
 }
 @DeleteMapping("/creators/{id}/follow")
 @Transactional
 public Map<String,Boolean> unfollow(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  jdbc.update("DELETE FROM social_creator_follows WHERE follower_id=? AND followed_id=?",
   current(jwt),id);
  return Map.of("following",false);
 }
 @GetMapping("/me")
 @Transactional
 public Map<String,List<String>> myState(@AuthenticationPrincipal Jwt jwt) {
  UUID me=current(jwt);
  return Map.of(
   "likedVideoIds",jdbc.query("SELECT video_id FROM social_video_likes WHERE creator_id=?",
      (rs,i)->rs.getString(1),me),
   "savedVideoIds",jdbc.query("SELECT video_id FROM social_video_saves WHERE creator_id=?",
      (rs,i)->rs.getString(1),me),
   "followingCreatorIds",jdbc.query("SELECT followed_id FROM social_creator_follows WHERE follower_id=?",
      (rs,i)->rs.getString(1),me)
  );
 }
 @GetMapping("/videos/{id}/comments")
 @Transactional(readOnly=true)
 public List<Comment> comments(@PathVariable UUID id,
     @RequestParam(defaultValue="30") int limit) {
  requirePublished(id);
  return jdbc.query("""
   SELECT cm.id,c.display_name,cm.content,cm.created_at
   FROM social_video_comments cm JOIN creators c ON c.id=cm.creator_id
   WHERE cm.video_id=?
   ORDER BY cm.created_at DESC,cm.id DESC LIMIT ?
   """,(rs,i)->new Comment((UUID)rs.getObject(1),rs.getString(2),rs.getString(3),
     rs.getTimestamp(4).toInstant()),id,Math.min(50,Math.max(1,limit)));
 }
 @PostMapping("/videos/{id}/comments")
 @ResponseStatus(HttpStatus.CREATED)
 @Transactional
 public Comment postComment(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,
    @Valid @RequestBody CommentInput input) {
  requirePublished(id);
  String content=input.text().strip();
  if(content.isEmpty() || content.length()>400)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Comment must be 1-400 characters");
  UUID user=current(jwt);
  Integer recent=jdbc.queryForObject("""
   SELECT COUNT(*) FROM social_video_comments
   WHERE creator_id=? AND created_at > now() - interval '1 hour'
   """,Integer.class,user);
  if(recent!=null && recent>=20)
   throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS,"Comment limit reached");
  UUID commentId=UUID.randomUUID();
  jdbc.update("""
   INSERT INTO social_video_comments(id,video_id,creator_id,content)
   VALUES (?,?,?,?)
   """,commentId,id,user,content);
  String name=creators.findByCognitoSub(jwt.getSubject())
     .map(c->c.displayName).orElse("Creator");
  return new Comment(commentId,name,content,Instant.now());
 }
}
