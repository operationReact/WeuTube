package com.weutube.api;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Service;

/**
 * Internal-only short-lived Google tokens. The bearer credential NEVER goes
 * to Flutter; large uploads reuse it across chunks instead of needlessly
 * refreshing Google OAuth for every 8 MiB.
 */
@Service
public class YouTubeAccessTokenService {
 private static final Duration CACHE_TTL=Duration.ofMinutes(45);
 private record Cached(String value,Instant expiresAt) {}
 private final ConcurrentHashMap<String,Cached> cache=new ConcurrentHashMap<>();
 private final YouTubeCredentialStore credentials;
 private final GoogleYouTubeClient google;

 public YouTubeAccessTokenService(YouTubeCredentialStore credentials,GoogleYouTubeClient google) {
  this.credentials=credentials;this.google=google;
 }

 public String forChannel(String channelId) {
  if(channelId==null || channelId.isBlank())
   throw new IllegalArgumentException("YouTube channel is required");
  Cached item=cache.compute(channelId,(id,previous)-> {
   if(previous!=null && previous.expiresAt().isAfter(Instant.now().plusSeconds(30)))
    return previous;
   String refreshToken=credentials.loadRefreshToken(id)
     .orElseThrow(()->new IllegalArgumentException("YouTube channel is not connected"));
   String value=google.refreshAccessToken(refreshToken);
   return new Cached(value,Instant.now().plus(CACHE_TTL));
  });
  return item.value();
 }

 /** Called on any provider 401 so the next status probe refreshes OAuth. */
 public void invalidate(String channelId) {cache.remove(channelId);}
}
