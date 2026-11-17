package com.weutube.api;

import com.fasterxml.jackson.databind.JsonNode;
import java.time.Duration;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.Set;
import java.util.Arrays;
import java.util.List;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

/** Server-to-server Google API client. Never logs or returns OAuth tokens through HTTP endpoints. */
@Service
public class GoogleYouTubeClient {
 private static final String TOKEN_ENDPOINT="https://oauth2.googleapis.com/token";
 private static final String CHANNEL_ENDPOINT="https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true";
 private static final String SCOPE_UPLOAD="https://www.googleapis.com/auth/youtube.upload";
 private static final String SCOPE_READ="https://www.googleapis.com/auth/youtube.readonly";
 private static final String SCOPE_PUBLISH="https://www.googleapis.com/auth/youtube.force-ssl";
 private final RestClient http;
 private final String clientId;
 private final String clientSecret;
 private final String redirectUri;

 public GoogleYouTubeClient(YouTubeOAuthSettings settings) {
  this.clientId=settings.clientId();
  this.clientSecret=settings.clientSecret();
  this.redirectUri=settings.redirectUri();
  SimpleClientHttpRequestFactory factory=new SimpleClientHttpRequestFactory();
  factory.setConnectTimeout(Duration.ofSeconds(5));
  factory.setReadTimeout(Duration.ofSeconds(10));
  this.http=RestClient.builder().requestFactory(factory).build();
 }

 public boolean configured() {
  return !clientId.isBlank() && !clientSecret.isBlank()
    && redirectUri.startsWith("https://") && !redirectUri.isBlank();
 }

 public Tokens exchange(String code) {
  if (!configured()) throw new IllegalStateException("Google OAuth is not configured");
  var form=new LinkedMultiValueMap<String,String>();
  form.add("client_id",clientId);
  form.add("client_secret",clientSecret);
  form.add("code",code);
  form.add("redirect_uri",redirectUri);
  form.add("grant_type","authorization_code");
  try {
   JsonNode response=http.post().uri(TOKEN_ENDPOINT)
     .contentType(MediaType.APPLICATION_FORM_URLENCODED)
     .body(form).retrieve().body(JsonNode.class);
   return parseTokens(response);
  } catch (RestClientException ex) {
   throw new ProviderException("Google token exchange failed",ex);
  }
 }

 /**
  * Exchanges a stored Google refresh token for a fresh short-lived access token.
  * Intended only for internal YouTube publishing/metadata services.
  */
 public String refreshAccessToken(String refreshToken) {
  if (!configured()) throw new IllegalStateException("Google OAuth is not configured");
  if (refreshToken==null || refreshToken.isBlank())
   throw new IllegalArgumentException("Refresh token required");
  var form=new LinkedMultiValueMap<String,String>();
  form.add("client_id",clientId);
  form.add("client_secret",clientSecret);
  form.add("refresh_token",refreshToken);
  form.add("grant_type","refresh_token");
  try {
   JsonNode response=http.post().uri(TOKEN_ENDPOINT)
     .contentType(MediaType.APPLICATION_FORM_URLENCODED)
     .body(form).retrieve().body(JsonNode.class);
   return parseRefreshedAccessToken(response);
  } catch (RestClientException ex) {
   throw new ProviderException("Google access token refresh failed",ex);
  }
 }

 static String parseRefreshedAccessToken(JsonNode response) {
  if (response==null || response.path("access_token").asText("").isBlank())
   throw new ProviderException("Google did not return a refreshed access token");
  return response.path("access_token").asText();
 }

 /** Server-only Data API metadata reads using the stored channel grant.
  * Restrict resources so caller-controlled parameters cannot become an SSRF.
  * Tokens are used only as request headers, never returned to Flutter.
  */
 public JsonNode readVideoCatalog(String resource,Map<String,String> query,String accessToken) {
  if (!Set.of("channels","playlistItems","videos").contains(resource))
   throw new IllegalArgumentException("Unsupported YouTube catalog endpoint");
  if (accessToken==null || accessToken.isBlank())
   throw new IllegalArgumentException("Missing authorized YouTube access");
  var params=new java.util.ArrayList<String>();
  query.forEach((key,value) -> {
   if (key==null || !Set.of("part","id","playlistId","pageToken","maxResults","fields")
       .contains(key) || value==null || value.length()>2000)
    throw new IllegalArgumentException("Invalid YouTube catalog query");
   params.add(URLEncoder.encode(key,StandardCharsets.UTF_8)
     +"="+URLEncoder.encode(value,StandardCharsets.UTF_8));
  });
  String url="https://www.googleapis.com/youtube/v3/"+resource
    +"?"+String.join("&",params);
  try {
   return http.get().uri(java.net.URI.create(url)).headers(h->h.setBearerAuth(accessToken))
     .retrieve().body(JsonNode.class);
  } catch (RestClientException ex) {
   throw new ProviderException("YouTube catalog metadata read failed",ex);
  }
 }

 public Channel channelFor(String accessToken) {
  try {
   JsonNode response=http.get().uri(CHANNEL_ENDPOINT)
     .headers(h->h.setBearerAuth(accessToken))
     .retrieve().body(JsonNode.class);
   return parseChannel(response);
  } catch (RestClientException ex) {
   throw new ProviderException("YouTube channel lookup failed",ex);
  }
 }

 static Tokens parseTokens(JsonNode response) {
  if (response==null) throw new ProviderException("Empty Google token response");
  String access=response.path("access_token").asText("");
  String refresh=response.path("refresh_token").asText("");
  List<String> granted=Arrays.asList(response.path("scope").asText("").split(" "));
  if (access.isBlank() || refresh.isBlank()
      || !granted.contains(SCOPE_UPLOAD) || !granted.contains(SCOPE_READ) || !granted.contains(SCOPE_PUBLISH))
   throw new ProviderException("Required YouTube OAuth credentials or scopes not granted");
  return new Tokens(access,refresh);
 }

 static Channel parseChannel(JsonNode response) {
  if (response==null || !response.path("items").isArray()
      || response.path("items").size()!=1)
   throw new ProviderException("No unique YouTube channel was returned");
  JsonNode item=response.path("items").get(0);
  String id=item.path("id").asText("");
  String title=item.path("snippet").path("title").asText("");
  if (id.isBlank() || id.length()>128 || title.isBlank() || title.length()>200)
   throw new ProviderException("YouTube channel response is incomplete");
  return new Channel(id,title);
 }

 public record Tokens(String accessToken,String refreshToken) {}
 public record Channel(String id,String title) {}
 public static class ProviderException extends RuntimeException {
  public ProviderException(String message) { super(message); }
  public ProviderException(String message,Throwable cause) { super(message,cause); }
 }
}
