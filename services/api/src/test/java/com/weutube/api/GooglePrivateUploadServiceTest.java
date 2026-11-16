package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.net.URI;
import org.junit.jupiter.api.Test;

class GooglePrivateUploadServiceTest {
 private final ObjectMapper mapper=new ObjectMapper();

 @Test void acceptsOnlyOfficialResumableUploadLocation() {
  var uri=URI.create("https://www.googleapis.com/upload/youtube/v3/videos?upload_id=abc");
  assertEquals(uri,GooglePrivateUploadService.validateSessionUri(uri));
  assertThrows(GooglePrivateUploadService.UploadFailed.class,
    ()->GooglePrivateUploadService.validateSessionUri(URI.create("http://www.googleapis.com/upload/youtube/v3/videos")));
  assertThrows(GooglePrivateUploadService.UploadFailed.class,
    ()->GooglePrivateUploadService.validateSessionUri(URI.create("https://evil.example/upload/youtube/v3/videos")));
  assertThrows(GooglePrivateUploadService.UploadFailed.class,
    ()->GooglePrivateUploadService.validateSessionUri(URI.create("https://www.googleapis.com.evil.example/upload/youtube/v3/videos")));
 }
 @Test void requiresProviderConfirmedPrivateStatusAndOwner() throws Exception {
  var valid=mapper.readTree("""
   {"id":"video123","snippet":{"channelId":"UC_A"},"status":{"privacyStatus":"private"}}
   """);
  var uploaded=GooglePrivateUploadService.parseUpload(valid,"UC_A");
  assertEquals("private",uploaded.privacyStatus());
  assertEquals("video123",uploaded.id());
  assertThrows(GooglePrivateUploadService.UploadFailed.class,
    ()->GooglePrivateUploadService.parseUpload(valid,"UC_B"));
  var publicVideo=mapper.readTree("""
   {"id":"video123","snippet":{"channelId":"UC_A"},"status":{"privacyStatus":"public"}}
   """);
  assertThrows(GooglePrivateUploadService.UploadFailed.class,
    ()->GooglePrivateUploadService.parseUpload(publicVideo,"UC_A"));
 }
}
