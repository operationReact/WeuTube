package com.weutube.api;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
@RestController
@RequestMapping("/api/creator")
public class CreatorVideoController {
 private final CreatorRepository creators;
 private final VideoRepository videos;
 public CreatorVideoController(CreatorRepository creators,VideoRepository videos) {
  this.creators=creators; this.videos=videos;
 }
 public record DraftRequest(@NotBlank @Size(max=200) String title) {}
 public record VideoResponse(UUID id,String title,String status) {}
 public record VideoDetails(UUID id,String title,String status,String youtubeVideoId,
   String rejectionReason,java.time.Instant createdAt,java.time.Instant updatedAt) {}
 @GetMapping("/videos/{id}")
 @Transactional(readOnly=true)
 public VideoDetails details(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt,
    @PathVariable UUID id) {
  VideoSubmission v=videos.findById(id)
   .orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Video not found"));
  if(!v.creator.cognitoSub.equals(jwt.getSubject()))
   throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Video not found");
  return new VideoDetails(v.id,v.title,v.status,v.youtubeVideoId,v.rejectionReason,v.createdAt,v.updatedAt);
 }
 private VideoSubmission ownedDraft(Jwt jwt, UUID id) {
  VideoSubmission video=videos.findById(id)
    .orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Draft not found"));
  if (!video.creator.cognitoSub.equals(jwt.getSubject()))
    throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Draft not found");
  if (!"DRAFT".equals(video.status))
    throw new ResponseStatusException(HttpStatus.CONFLICT,"Only drafts can be modified");
  return video;
 }
 @PatchMapping("/videos/drafts/{id}")
 @Transactional
 public VideoResponse renameDraft(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt,
   @PathVariable UUID id, @Valid @RequestBody DraftRequest request) {
  String title=request.title().trim();
  if (title.isEmpty())
    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Title cannot be blank");
  VideoSubmission video=ownedDraft(jwt,id);
  video.title=title;
  video.updatedAt=java.time.Instant.now();
  videos.save(video);
  return new VideoResponse(video.id,video.title,video.status);
 }
 @DeleteMapping("/videos/drafts/{id}")
 @Transactional
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void deleteDraft(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt,
   @PathVariable UUID id) {
  videos.delete(ownedDraft(jwt,id));
 }
 @PostMapping("/videos/drafts")
 @Transactional
 public ResponseEntity<VideoResponse> createDraft(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt,
    @Valid @RequestBody DraftRequest request) {
  String sub=jwt.getSubject();
  Creator creator=creators.findByCognitoSub(sub)
   .orElseGet(()->creators.save(new Creator(sub,"Creator")));
  String title=request.title().trim();
  if (title.isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Title cannot be blank");
  VideoSubmission video=videos.save(new VideoSubmission(creator,title));
  return ResponseEntity.status(201).body(new VideoResponse(video.id,video.title,video.status));
 }
 @GetMapping("/videos")
 @Transactional(readOnly=true)
 public List<VideoResponse> mine(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt) {
  return videos.findByCreatorCognitoSubOrderByCreatedAtDesc(jwt.getSubject()).stream()
   .map(v->new VideoResponse(v.id,v.title,v.status)).toList();
 }
}
