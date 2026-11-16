package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

class YouTubeUploadConstraintsTest {
 @Test void acceptsUpTo100UnicodeCodepointsAndRejectsAngleBrackets() {
  assertEquals("Title",YouTubeUploadConstraints.validatedTitle(" Title "));
  assertEquals(100,YouTubeUploadConstraints.validatedTitle("😀".repeat(100))
    .codePointCount(0,"😀".repeat(100).length()));
  assertThrows(ResponseStatusException.class,
    ()->YouTubeUploadConstraints.validatedTitle("X".repeat(101)));
  assertThrows(ResponseStatusException.class,
    ()->YouTubeUploadConstraints.validatedTitle("<not allowed>"));
 }
 @Test void checksDescriptionSizeInUtf8BytesNotJavaCharacters() {
  assertEquals(5000,YouTubeUploadConstraints.validatedDescription("a".repeat(5000)).length());
  assertEquals(1250,YouTubeUploadConstraints.validatedDescription("😀".repeat(1250)).codePointCount(0,"😀".repeat(1250).length()));
  var tooManyBytes=assertThrows(ResponseStatusException.class,
    ()->YouTubeUploadConstraints.validatedDescription("😀".repeat(1251)));
  assertEquals(HttpStatus.BAD_REQUEST,tooManyBytes.getStatusCode());
  assertThrows(ResponseStatusException.class,
    ()->YouTubeUploadConstraints.validatedDescription("a>b"));
 }
 @Test void supportsYoutubeContainerFormatsAndRejectsUnlistedFiles() {
  for(String file:new String[] {"clip.MP4","clip.MOV","clip.AVI","clip.WMV",
    "clip.webm","clip.FLV","clip.3gp","clip.MPEG","clip.VOB","clip.m2ts"}) {
    assertNotNull(YouTubeUploadConstraints.mimeForName(file),file);
  }
  assertNull(YouTubeUploadConstraints.mimeForName("virus.exe"));
  assertNull(YouTubeUploadConstraints.mimeForName("audio.mp3"));
  assertNull(YouTubeUploadConstraints.mimeForName("movie.mkv"));
 }
 @Test void policyRemainsSeparateFromCurrentGatewayTransport() {
  assertEquals(12*3600,YouTubeUploadConstraints.YOUTUBE_MAX_DURATION_SECONDS);
  assertEquals(15*60,YouTubeUploadConstraints.UNVERIFIED_CHANNEL_MAX_DURATION_SECONDS);
  assertTrue(YouTubeUploadConstraints.YOUTUBE_MAX_FILE_BYTES >
    GooglePrivateUploadService.MAX_UPLOAD_BYTES);
 }
}
