package com.weutube.api;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.Map;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
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
 private void requireAdmin(Jwt jwt) {
  Object rawGroups=jwt.getClaims().get("cognito:groups");
  if (!(rawGroups instanceof java.util.Collection<?> groups) || !groups.contains(adminGroup))
    throw new AccessDeniedException("Admin group required");
 }
 public record ReviewQueueItem(UUID id,String title,String status,Instant createdAt) {}
 @GetMapping("/queue")
 @Transactional(readOnly=true)
 public List<ReviewQueueItem> queue(@AuthenticationPrincipal Jwt jwt,
    @RequestParam(defaultValue="0") int page) {
  requireAdmin(jwt);
  if (page < 0 || page > 100000)
    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid page");
  return videos.findByStatus("PRIVATE_REVIEW",
    PageRequest.of(page,25,Sort.by(Sort.Direction.ASC,"createdAt")))
    .stream().map(v->new ReviewQueueItem(v.id,v.title,v.status,v.createdAt)).toList();
 }
 public record DecisionRequest(@NotBlank String decision,@Size(max=2000) String reason) {}
 @PostMapping("/{id}/decision")
 @Transactional
 public Map<String,String> decide(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,
   @Valid @RequestBody DecisionRequest request) {
  requireAdmin(jwt);
  String decision=request.decision().trim().toUpperCase(java.util.Locale.ROOT);
  if (!decision.equals("APPROVED") && !decision.equals("REJECTED"))
    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid decision");
  if (decision.equals("REJECTED") && (request.reason()==null || request.reason().isBlank()))
    throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Rejection reason required");
  // Conditional state transition is atomic across concurrent admin requests.
  // Only the winner may write a decision event.
  int changed=jdbc.update("""
   UPDATE video_submissions
   SET status=?, rejection_reason=?, updated_at=now()
   WHERE id=? AND status='PRIVATE_REVIEW'
   """,decision,decision.equals("REJECTED")?request.reason().trim():null,id);
  if (changed!=1) {
   if (!videos.existsById(id))
    throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Submission not found");
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Submission has already been reviewed");
  }
  jdbc.update("INSERT INTO video_review_events(id,video_id,reviewer_sub,decision,reason) VALUES (?,?,?,?,?)",
    UUID.randomUUID(),id,jwt.getSubject(),decision,request.reason());
  return Map.of("videoId",id.toString(),"status",decision);
 }
}
