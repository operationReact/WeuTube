package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.server.ResponseStatusException;

/** Guardrails for the public-facing provider-sized upload entry point. */
class CreatorResumableUploadControllerTest {
  JdbcTemplate jdbc;
  YouTubeResumableRelay relay;
  CreatorResumableUploadController controller;
  Jwt creator;

  @BeforeEach void setup() {
    jdbc=mock(JdbcTemplate.class);
    relay=mock(YouTubeResumableRelay.class);
    controller=new CreatorResumableUploadController(jdbc,relay);
    creator=Jwt.withTokenValue("creator").header("alg","none")
      .subject("creator-account").build();
  }

  @Test void rejectsOnlyFilesAboveYoutubeProviderMaximum() {
    var max=YouTubeResumableRanges.MAX_FILE_BYTES;
    var err=assertThrows(ResponseStatusException.class,
      ()->controller.start(creator,new CreatorResumableUploadController.Start(
        UUID.randomUUID(),"UC_TEST","video.mp4",max+1)));
    assertEquals(HttpStatus.BAD_REQUEST,err.getStatusCode());
    verifyNoInteractions(jdbc,relay);
  }

  @Test void preventsUnrecognizedFileTypeBeforeGoogleOrDbCall() {
    var err=assertThrows(ResponseStatusException.class,
      ()->controller.start(creator,new CreatorResumableUploadController.Start(
        UUID.randomUUID(),"UC_TEST","malware.exe",4096)));
    assertEquals(HttpStatus.BAD_REQUEST,err.getStatusCode());
    verifyNoInteractions(jdbc,relay);
  }

  @Test void rejectsOversizedTransportChunksRatherThanVideoTotals()
    throws Exception {
    var request=new MockHttpServletRequest();
    request.setContent(new byte[0]);
    request.setContentType("application/octet-stream");
    // No body is never a valid upload chunk.
    var err=assertThrows(ResponseStatusException.class,
      ()->controller.chunk(creator,UUID.randomUUID(),
         "bytes 0-262143/274877906944",request));
    assertEquals(HttpStatus.BAD_REQUEST,err.getStatusCode());
    verifyNoInteractions(jdbc,relay);
  }

  @Test void rejectsInvalidByteRangeBeforeLookingUpSession() {
    var request=new MockHttpServletRequest();
    request.setContent(new byte[4]);
    request.setContentType("application/octet-stream");
    var err=assertThrows(ResponseStatusException.class,
      ()->controller.chunk(creator,UUID.randomUUID(),
        "bytes 1-99/200",request));
    assertEquals(HttpStatus.BAD_REQUEST,err.getStatusCode());
    verifyNoInteractions(jdbc,relay);
  }
}
