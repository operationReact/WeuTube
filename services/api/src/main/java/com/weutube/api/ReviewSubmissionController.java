package com.weutube.api;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
@RestController
@RequestMapping("/api/creator/videos")
public class ReviewSubmissionController {
 private final VideoRepository videos;
 public ReviewSubmissionController(VideoRepository videos) { this.videos=videos; }
 @PostMapping("/{id}/submit-review")
 @Transactional
 public Map<String,String> submit(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  VideoSubmission video=videos.findById(id)
   .orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Draft not found"));
  if (!video.creator.cognitoSub.equals(jwt.getSubject()))
   throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Draft not found");
  if (!"DRAFT".equals(video.status))
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Only drafts can be submitted");
  // Do not accept review requests until an actual private upload is verified.
  throw new ResponseStatusException(HttpStatus.PRECONDITION_REQUIRED,
   "Verified private YouTube upload required before moderation");
 }
}
