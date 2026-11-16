package com.weutube.api;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URI;
import java.time.Duration;
import java.util.Map;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.multipart.MultipartFile;

/**
 * Streams a creator's video to the connected owner's YouTube channel using
 * the official resumable upload protocol. Always PRIVATE before review.
 * Files are request-temporary and not retained in WeuTube storage.
 */
@Service
public class GooglePrivateUploadService {
 public static final long MAX_UPLOAD_BYTES=256L*1024*1024;
 private static final URI START=URI.create(
   "https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status");
 private final YouTubeAccessTokenService accessTokens;
 private final GoogleYouTubeClient google;
 private final RestClient client;
 private final ObjectMapper json;

 public GooglePrivateUploadService(YouTubeAccessTokenService accessTokens,
   GoogleYouTubeClient google,ObjectMapper json) {
  this.accessTokens=accessTokens;this.google=google;this.json=json;
  var factory=new SimpleClientHttpRequestFactory();
  factory.setConnectTimeout(Duration.ofSeconds(8));
  factory.setReadTimeout(Duration.ofSeconds(30));
  this.client=RestClient.builder().requestFactory(factory).build();
 }
 public record Uploaded(String id,String channelId,String privacyStatus) {}
 public static class UploadFailed extends RuntimeException {
  public UploadFailed(String message) { super(message); }
 }
 static URI validateSessionUri(URI uri) {
  // Provider response is not a trustworthy arbitrary URL.
  if(uri==null || !uri.getScheme().equals("https")
    || !"www.googleapis.com".equals(uri.getHost())
    || uri.getRawUserInfo()!=null
    || !uri.getPath().equals("/upload/youtube/v3/videos"))
   throw new UploadFailed("Invalid YouTube upload session");
  return uri;
 }
 static Uploaded parseUpload(JsonNode response,String expectedChannel) {
  if(response==null) throw new UploadFailed("Empty YouTube upload response");
  String id=response.path("id").asText("");
  String channel=response.path("snippet").path("channelId").asText("");
  String privacy=response.path("status").path("privacyStatus").asText("");
  if(id.isBlank() || id.length()>128 || !expectedChannel.equals(channel)
    || !"private".equals(privacy))
   throw new UploadFailed("Private video ownership or visibility could not be verified");
  return new Uploaded(id,channel,privacy);
 }
 public Uploaded upload(String channelId,String title,String description,MultipartFile video) {
  long size=video.getSize();
  if(size<=0 || size>MAX_UPLOAD_BYTES)
   throw new IllegalArgumentException("Current direct upload allows up to 256 MiB");
  String mediaType=YouTubeUploadConstraints.mimeForName(video.getOriginalFilename());
  if(mediaType==null)
   throw new IllegalArgumentException("File format not supported by YouTube");
  // File names and MIME hints are not a substitute for provider verification;
  // Google can still reject an unsupported or malformed codec/container.
  YouTubeUploadConstraints.validatedTitle(title);
  YouTubeUploadConstraints.validatedDescription(description);
  try {
   String token=accessTokens.forChannel(channelId);
   if(!channelId.equals(google.channelFor(token).id()))
    throw new UploadFailed("Connected channel does not match upload destination");
   String metadata=json.writeValueAsString(Map.of(
     "snippet",Map.of("title",title,"description",description,"categoryId","22"),
     "status",Map.of("privacyStatus","private")));
   ResponseEntity<String> session=client.post().uri(START)
     .headers(h-> {
      h.setBearerAuth(token);
      h.set("X-Upload-Content-Length",Long.toString(size));
      h.set("X-Upload-Content-Type",mediaType);
     })
     .contentType(MediaType.APPLICATION_JSON).body(metadata)
     .retrieve().toEntity(String.class);
   URI uri=validateSessionUri(session.getHeaders().getLocation());
   HttpURLConnection connection=(HttpURLConnection)uri.toURL().openConnection();
   connection.setInstanceFollowRedirects(false);
   connection.setRequestMethod("PUT");
   connection.setDoOutput(true);
   connection.setConnectTimeout(8000);
   connection.setReadTimeout(600000);
   connection.setRequestProperty("Authorization","Bearer "+token);
   connection.setRequestProperty("Content-Type",mediaType);
   connection.setFixedLengthStreamingMode(size);
   try {
    try(InputStream in=video.getInputStream();OutputStream out=connection.getOutputStream()) {
     in.transferTo(out);
    }
    int status=connection.getResponseCode();
    if(status!=200 && status!=201)
     throw new UploadFailed("YouTube upload did not complete successfully");
    try(InputStream response=connection.getInputStream()) {
     return parseUpload(json.readTree(response),channelId);
    }
   } finally { connection.disconnect(); }
  } catch (RestClientException|IOException ex) {
   // Never propagate Google bearer credentials or provider internals.
   throw new UploadFailed("Private YouTube upload failed; reconciliation may be required");
  }
 }
}
