package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

/** Protocol guardrails before introducing a no-S3 streaming relay. */
class YouTubeResumableRangesTest {
 @Test void standardChunkAndNextOffset() {
  var range=YouTubeResumableRanges.parseChunk(
    "bytes 0-8388607/16777216",8*1024*1024);
  assertEquals(0,range.first());
  assertEquals(8388608,range.length());
  assertEquals("bytes 0-8388607/16777216",range.header());
  YouTubeResumableRanges.requireNextChunk(range,0);
  assertThrows(IllegalArgumentException.class,
    ()->YouTubeResumableRanges.requireNextChunk(range,8388608));
 }

 @Test void resumedChunksCanStartAtGoogleConfirmedPartialOffset() {
  var chunk=YouTubeResumableRanges.parseChunk("bytes 1-262144/262145",262144);
  assertEquals(1,chunk.first());
  YouTubeResumableRanges.requireNextChunk(chunk,1);
 }
 @Test void acceptsFinalUnalignedChunk() {
  var range=YouTubeResumableRanges.parseChunk(
    "bytes 8388608-8388618/8388619",11);
  assertEquals(11,range.length());
  YouTubeResumableRanges.requireNextChunk(range,8388608);
 }

 @Test void requiresBoundedAlignedAndHonestByteRange() {
  for(String invalid:new String[] {
    "bytes 0-16777215/16777216", // too large: 16 MiB request
    "bytes 0-300000/16777216",   // non-final chunk not 256 KiB aligned
    "bytes 0-100/99",            // beyond total
    "bytes -1-100/200",          // negative
    "bytes 5-2/100",             // reversed
    "bytes 0-8/18446744073709551615", // overflow
    "bytes */100",               // status probe is not upload data
  }) {
   assertThrows(IllegalArgumentException.class,
     ()->YouTubeResumableRanges.parseChunk(invalid,8*1024*1024),invalid);
  }
  assertThrows(IllegalArgumentException.class,
    ()->YouTubeResumableRanges.parseChunk("bytes 0-262143/1048576",1));
 }

 @Test void handlesGoogle308RangeAsAuthoritativeNotLocalProgress() {
  assertEquals(0,YouTubeResumableRanges.acknowledgedBytesFromGoogle(null,8388608));
  assertEquals(262144,YouTubeResumableRanges.acknowledgedBytesFromGoogle(
    "bytes=0-262143",8388608));
  assertEquals(8388608,YouTubeResumableRanges.acknowledgedBytesFromGoogle(
    "bytes=0-8388607",8388608));
  for(String bad:new String[]{"bytes=100-200","bytes=0-8388608",
    "bytes=0-18446744073709551615","bytes=0--1"}) {
    assertThrows(IllegalArgumentException.class,
      ()->YouTubeResumableRanges.acknowledgedBytesFromGoogle(bad,8388608),bad);
  }
 }

 @Test void supports256GibArithmeticWithoutIntOverflow() {
  long total=YouTubeResumableRanges.MAX_FILE_BYTES;
  assertTrue(total>Integer.MAX_VALUE);
  var range=YouTubeResumableRanges.parseChunk(
    "bytes "+(total-8388608)+"-"+(total-1)+"/"+total,8388608);
  assertEquals(total-8388608,range.first());
  assertEquals("bytes */"+total,YouTubeResumableRanges.statusProbeRange(total));
  assertThrows(IllegalArgumentException.class,
    ()->YouTubeResumableRanges.validateFileLength(total+1));
  assertThrows(IllegalArgumentException.class,
    ()->YouTubeResumableRanges.validateFileLength(0));
 }

 @Test void recognizesRetryableGoogleStatuses() {
  assertTrue(YouTubeResumableRanges.retryableGoogleStatus(503));
  assertTrue(YouTubeResumableRanges.retryableGoogleStatus(429));
  assertFalse(YouTubeResumableRanges.retryableGoogleStatus(401));
  assertFalse(YouTubeResumableRanges.retryableGoogleStatus(403));
  assertFalse(YouTubeResumableRanges.retryableGoogleStatus(404));
 }
}
