package com.weutube.api;

import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.*;

/**
 * Guests may read comments on videos that have actually been published.
 * Ownership/publication validation remains in SocialEngagementController.
 * Posting or editing engagement is never exposed by this public route.
 */
@RestController
@RequestMapping("/api/public/social")
public class PublicSocialCommentsController {
 private final SocialEngagementController engagement;
 public PublicSocialCommentsController(SocialEngagementController engagement) {
  this.engagement=engagement;
 }
 @GetMapping("/videos/{id}/comments")
 public List<SocialEngagementController.Comment> comments(
    @PathVariable UUID id,@RequestParam(defaultValue="30") int limit) {
  return engagement.comments(id,limit);
 }
}
