package com.weutube.api;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.jdbc.core.JdbcTemplate;
@RestController
@RequestMapping("/api/admin/reviews")
public class AdminReviewController {
 private final VideoRepository videos;
 private final JdbcTemplate jdbc;
 private final String adminGroup;
 public AdminReviewController(VideoRepository videos,JdbcTemplate jdbc,
   @Value("${weutube.security.admin-group:weutube-admin}") String adminGroup) {
  this.videos=videos; this.jdbc=jdbc; this.adminGroup=adminGroup;
 }
 public record DecisionRequest(@NotBlank String decision,@Size(max=2000) String reason) {}
 @PostMapping("/{id}/decision")
 @Transactional
 public Map<String,String> decide(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,
   @Valid @RequestBody DecisionRequest request) {
  Object rawGroups=jwt.getClaims().get("cognito:groups");
  if (!(rawGroups instanceof java.util.Collection<?> groups) || !groups.contains(adminGroup))
    throw new AccessDeniedException("Admin group required");
  String decision=request.decision().trim().toUpperCase(java.util.Locale.ROOT);
  if (!decision.equals("APPROVED") && !decision.equals("REJECTED"))
    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid decision");
  if (decision.equals("REJECTED") && (request.reason()==null || request.reason().isBlank()))
    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Rejection reason required");
  VideoSubmission video=videos.findById(id)
    .orElseThrow(()->new ResponseStatusException(HttpStatus.NOT_FOUND,"Submission not found"));
  if (!"PRIVATE_REVIEW".equals(video.status))
    throw new ResponseStatusException(HttpStatus.CONFLICT,"Only private-review submissions can be reviewed");
  video.status=decision;
  video.updatedAt=Instant.now();
  videos.save(video);
  jdbc.update("UPDATE video_submissions SET rejection_reason = ? WHERE id = ?",
    decision.equals("REJECTED") ? request.reason().trim() : null,id);
  jdbc.update("INSERT INTO video_review_events(id,video_id,reviewer_sub,decision,reason) VALUES (?,?,?,?,?)",
    UUID.randomUUID(),id,jwt.getSubject(),decision,request.reason());
  return Map.of("videoId",id.toString(),"status",decision);
 }
}
