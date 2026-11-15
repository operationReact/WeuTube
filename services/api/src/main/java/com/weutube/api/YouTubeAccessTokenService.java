package com.weutube.api;

import org.springframework.stereotype.Service;

/**
 * Internal-only token provider for future YouTube API operations.
 * No method here is exposed as an HTTP endpoint.
 */
@Service
public class YouTubeAccessTokenService {
 private final YouTubeCredentialStore credentials;
 private final GoogleYouTubeClient google;

 public YouTubeAccessTokenService(YouTubeCredentialStore credentials,GoogleYouTubeClient google) {
  this.credentials=credentials;
  this.google=google;
 }

 public String forChannel(String channelId) {
  String refreshToken=credentials.loadRefreshToken(channelId)
   .orElseThrow(()->new IllegalArgumentException("YouTube channel is not connected"));
  return google.refreshAccessToken(refreshToken);
 }
}
