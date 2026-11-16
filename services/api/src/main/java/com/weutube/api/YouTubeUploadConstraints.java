package com.weutube.api;

import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

/**
 * YouTube-provided video and metadata limits (not WeuTube transport capacity).
 * YouTube Help: https://support.google.com/youtube/answer/71673
 * YouTube API RMF: https://developers.google.com/youtube/terms/required-minimum-functionality
 *
 * Keep operational upload limits separate: until the app implements durable
 * resumable ingestion, accepting a 256 GB multipart request would be unsafe.
 */
public final class YouTubeUploadConstraints {
 private YouTubeUploadConstraints() {}

 public static final long YOUTUBE_MAX_FILE_BYTES = 256L * 1024 * 1024 * 1024;
 public static final long YOUTUBE_MAX_DURATION_SECONDS = 12L * 3600;
 public static final long UNVERIFIED_CHANNEL_MAX_DURATION_SECONDS = 15L * 60;
 public static final int TITLE_MAX_CHARACTERS = 100;
 public static final int DESCRIPTION_MAX_UTF8_BYTES = 5000;

 // These are *file container* extensions; DNxHR, ProRes and HEVC are codecs,
 // typically inside MOV or AVI, rather than independent file extensions.
 private static final Map<String,String> VIDEO_MIME_BY_EXTENSION = Map.ofEntries(
   Map.entry("mp4","video/mp4"), Map.entry("m4v","video/mp4"),
   Map.entry("mov","video/quicktime"), Map.entry("avi","video/x-msvideo"),
   Map.entry("wmv","video/x-ms-wmv"), Map.entry("webm","video/webm"),
   Map.entry("flv","video/x-flv"), Map.entry("3gp","video/3gpp"),
   Map.entry("3gpp","video/3gpp"), Map.entry("mpg","video/mpeg"),
   Map.entry("mpeg","video/mpeg"), Map.entry("m2v","video/mpeg"),
   Map.entry("m2p","video/mpeg"), Map.entry("mpg2","video/mpeg"),
   Map.entry("mpeg2","video/mpeg"), Map.entry("vob","video/mpeg"),
   Map.entry("mts","video/mp2t"), Map.entry("m2ts","video/mp2t")
 );

 public static Set<String> extensions() {
   return VIDEO_MIME_BY_EXTENSION.keySet();
 }
 public static String mimeForName(String filename) {
   if(filename==null || filename.isBlank()) return null;
   String normalized=filename.toLowerCase(Locale.ROOT);
   int dot=normalized.lastIndexOf('.');
   if(dot < 0 || dot==normalized.length()-1) return null;
   return VIDEO_MIME_BY_EXTENSION.get(normalized.substring(dot+1));
 }
 public static String validatedTitle(String value) {
   String title=value == null ? "" : value.trim();
   if(title.isEmpty() || title.codePointCount(0,title.length()) > TITLE_MAX_CHARACTERS
     || title.indexOf('<')>=0 || title.indexOf('>')>=0)
     throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
       "YouTube title must be 1-100 characters without angle brackets");
   return title;
 }
 public static String validatedDescription(String value) {
   String description=value == null ? "" : value.trim();
   if(description.indexOf('<')>=0 || description.indexOf('>')>=0
     || description.getBytes(StandardCharsets.UTF_8).length > DESCRIPTION_MAX_UTF8_BYTES)
     throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
       "YouTube description must be at most 5000 UTF-8 bytes without angle brackets");
   return description;
 }
}
