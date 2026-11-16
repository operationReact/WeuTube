package com.weutube.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.URI;
import java.time.Duration;
import java.util.Map;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

/**
 * Google owns the video bytes. WeuTube never exposes shared-channel OAuth
 * credentials or Google's upload-session URL to the uploading creator.
 */
@Service
public class YouTubeResumableRelay {
 private static final URI START=URI.create(
   "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status");
 private final YouTubeAccessTokenService tokens;
 private final GoogleYouTubeClient youtube;
 private final ObjectMapper json;
 private final RestClient rest;

 public YouTubeResumableRelay(YouTubeAccessTokenService tokens,
   GoogleYouTubeClient youtube,ObjectMapper json) {
  this.tokens=tokens;this.youtube=youtube;this.json=json;
  var http=new SimpleClientHttpRequestFactory();
  http.setConnectTimeout(Duration.ofSeconds(8));
  http.setReadTimeout(Duration.ofSeconds(30));
  this.rest=RestClient.builder().requestFactory(http).build();
 }

 public record Progress(long acknowledgedBytes,boolean completed,String youtubeVideoId) {}

 public String initiate(String channelId,String title,String description,
   String mime,long totalBytes) {
  YouTubeResumableRanges.validateFileLength(totalBytes);
  try {
   String token=tokens.forChannel(channelId);
   if(!channelId.equals(youtube.channelFor(token).id()))
    throw new IllegalStateException("YouTube connected-channel identity mismatch");
   ResponseEntity<String> response=rest.post().uri(START)
     .headers(h -> {
      h.setBearerAuth(token);
      h.set("X-Upload-Content-Length",Long.toString(totalBytes));
      h.set("X-Upload-Content-Type",mime);
     })
     .contentType(MediaType.APPLICATION_JSON)
     .body(Map.of(
       "snippet",Map.of("title",title,"description",description,"categoryId","22"),
       "status",Map.of("privacyStatus","private")))
     .retrieve().toEntity(String.class);
   URI session=GooglePrivateUploadService.validateSessionUri(
     response.getHeaders().getLocation());
   return session.toString();
  } catch(RuntimeException ex) {
   // Never put provider credentials or the upload capability URL in errors.
   throw new IllegalStateException("Unable to initiate YouTube private upload");
  }
 }

 private HttpURLConnection connection(String channelId,String sessionUrl,
   String mediaType,String contentRange,int bytes) throws IOException {
  URI uri=GooglePrivateUploadService.validateSessionUri(URI.create(sessionUrl));
  var c=(HttpURLConnection)uri.toURL().openConnection();
  c.setInstanceFollowRedirects(false);
  c.setRequestMethod("PUT");
  c.setConnectTimeout(8000);
  c.setReadTimeout(120000);
  c.setRequestProperty("Authorization","Bearer "+tokens.forChannel(channelId));
  c.setRequestProperty("Content-Range",contentRange);
  c.setRequestProperty("Content-Type",mediaType);
  c.setDoOutput(true);
  c.setFixedLengthStreamingMode(bytes);
  return c;
 }

 private Progress result(HttpURLConnection c,String channelId,long total)
   throws IOException {
  int status=c.getResponseCode();
  if(status==308) {
   long acknowledged=YouTubeResumableRanges.acknowledgedBytesFromGoogle(
     c.getHeaderField("Range"),total);
   return new Progress(acknowledged,false,null);
  }
  if(status==200 || status==201) {
   try(var body=c.getInputStream()) {
    var uploaded=GooglePrivateUploadService.parseUpload(
      json.readTree(body),channelId);
    return new Progress(total,true,uploaded.id());
   }
  }
  if(status==401) {
   tokens.invalidate(channelId);
   throw new IllegalStateException("YouTube access token expired; retry after verification");
  }
  if(status==404 || status==410)
   throw new IllegalStateException("Google resumable session expired; reconciliation required");
  throw new IllegalStateException("YouTube did not accept the upload request");
 }

 public Progress send(String channelId,String sessionUrl,
   String mediaType,YouTubeResumableRanges.Chunk range,byte[] payload) {
  if(payload.length!=range.length())
   throw new IllegalArgumentException("Chunk length mismatch");
  HttpURLConnection c=null;
  try {
   c=connection(channelId,sessionUrl,mediaType,range.header(),payload.length);
   try(var out=c.getOutputStream()) { out.write(payload); }
   return result(c,channelId,range.total());
  } catch(IOException ex) {
   throw new IllegalStateException(
     "YouTube transfer interrupted; query the session status before retry");
  } finally {if(c!=null)c.disconnect();}
 }

 public Progress probe(String channelId,String sessionUrl,
   String mediaType,long totalBytes) {
  HttpURLConnection c=null;
  try {
   c=connection(channelId,sessionUrl,mediaType,
     YouTubeResumableRanges.statusProbeRange(totalBytes),0);
   return result(c,channelId,totalBytes);
  } catch(IOException ex) {
   throw new IllegalStateException(
     "Unable to verify Google's accepted byte offset");
  } finally {if(c!=null)c.disconnect();}
 }
}
