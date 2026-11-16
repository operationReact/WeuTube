package com.weutube.api;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Range validation for YouTube's official resumable-upload protocol.
 *
 * This is a no-S3 foundation: the future authenticated relay will stream each
 * small client chunk directly to a Google upload session. Google-confirmed
 * bytes, NOT bytes sent by a browser, determine acknowledged progress.
 *
 * See https://developers.google.com/youtube/data/guides/using_resumable_upload_protocol
 */
public final class YouTubeResumableRanges {
 private YouTubeResumableRanges() {}

 public static final long MAX_FILE_BYTES=256L*1024*1024*1024;
 public static final int CHUNK_GRANULARITY=256*1024;
 public static final int RELAY_CHUNK_BYTES=8*1024*1024;
 private static final Pattern CLIENT_RANGE=Pattern.compile(
   "^bytes ([0-9]+)-([0-9]+)/([0-9]+)$");
 private static final Pattern GOOGLE_ACK=Pattern.compile(
   "^bytes=0-([0-9]+)$");

 /** Inclusive first/last indices, total length and size of one request body. */
 public record Chunk(long first,long last,long total) {
  public long length() { return last-first+1; }
  public String header() { return "bytes "+first+"-"+last+"/"+total; }
 }

 private static long number(String value) {
  try {return Long.parseLong(value);}
  catch(NumberFormatException ex) {
   throw new IllegalArgumentException("Invalid or overflowing resumable byte offset");
  }
 }

 public static void validateFileLength(long total) {
  if(total<1 || total>MAX_FILE_BYTES)
   throw new IllegalArgumentException("Video exceeds YouTube size limit");
 }

 /** Validates exactly one bounded, sequential Google-compatible chunk. */
 public static Chunk parseChunk(String contentRange, long claimedContentLength) {
  Matcher m=CLIENT_RANGE.matcher(contentRange==null?"":contentRange);
  if(!m.matches()) throw new IllegalArgumentException("Expected Content-Range bytes FIRST-LAST/TOTAL");
  long first=number(m.group(1));
  long last=number(m.group(2));
  long total=number(m.group(3));
  validateFileLength(total);
  if(first<0 || last<first || last>=total || first%CHUNK_GRANULARITY!=0)
   throw new IllegalArgumentException("Misaligned or out-of-bounds video chunk");
  long length=last-first+1;
  if(length>RELAY_CHUNK_BYTES || length!=claimedContentLength ||
    (last!=total-1 && length%CHUNK_GRANULARITY!=0))
   throw new IllegalArgumentException("Chunk length must be bounded and aligned");
  return new Chunk(first,last,total);
 }

 public static void requireNextChunk(Chunk chunk,long googleAcknowledgedBytes) {
  if(chunk.first()!=googleAcknowledgedBytes)
   throw new IllegalArgumentException("Upload must resume from YouTube-confirmed offset");
 }

 /** For HTTP 308, Google returns Range: bytes=0-N, inclusive. */
 public static long acknowledgedBytesFromGoogle(String range,long total) {
  validateFileLength(total);
  if(range==null || range.isBlank()) return 0;
  Matcher m=GOOGLE_ACK.matcher(range);
  if(!m.matches()) throw new IllegalArgumentException("Invalid Google upload Range response");
  long last=number(m.group(1));
  if(last<0 || last>=total)
   throw new IllegalArgumentException("Google acknowledged beyond expected file size");
  return last+1;
 }

 public static String statusProbeRange(long total) {
  validateFileLength(total);
  return "bytes */"+total;
 }

 public static boolean retryableGoogleStatus(int status) {
  return status==429 || status==500 || status==502 ||
    status==503 || status==504;
 }
}
