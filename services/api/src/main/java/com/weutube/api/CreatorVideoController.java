package com.weutube.api;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.UUID;
import org.springframework.http.ResponseEntity;
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
 @PostMapping("/videos/drafts")
 @Transactional
 public ResponseEntity<VideoResponse> createDraft(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt,
    @Valid @RequestBody DraftRequest request) {
  String sub=jwt.getSubject();
  Creator creator=creators.findByCognitoSub(sub)
   .orElseGet(()->creators.save(new Creator(sub,"Creator")));
  VideoSubmission video=videos.save(new VideoSubmission(creator,request.title().trim()));
  return ResponseEntity.status(201).body(new VideoResponse(video.id,video.title,video.status));
 }
 @GetMapping("/videos")
 @Transactional(readOnly=true)
 public List<VideoResponse> mine(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt) {
  return videos.findByCreatorCognitoSubOrderByCreatedAtDesc(jwt.getSubject()).stream()
   .map(v->new VideoResponse(v.id,v.title,v.status)).toList();
 }
}
