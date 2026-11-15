package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import software.amazon.awssdk.services.ssm.SsmClient;
import software.amazon.awssdk.services.ssm.model.GetParameterRequest;
import software.amazon.awssdk.services.ssm.model.GetParameterResponse;
import software.amazon.awssdk.services.ssm.model.Parameter;

class YouTubeOAuthSettingsConfigurationTest {
 @Test void localDevelopmentCanUseEnvironmentWithoutCallingSsm() {
  var settings=new YouTubeOAuthSettingsConfiguration().youtubeOAuthSettings(
    false,"ap-south-1","id","secret","https://example.com/oauth","aes-key");
  assertEquals("id",settings.clientId());
  assertEquals("secret",settings.clientSecret());
  assertEquals("aes-key",settings.tokenKeyBase64());
 }
 @Test void requiresDecryptionForSecureSsmParameters() {
  SsmClient ssm=mock(SsmClient.class);
  when(ssm.getParameter(any(GetParameterRequest.class)))
   .thenReturn(GetParameterResponse.builder().parameter(
     Parameter.builder().value("sensitive-value").build()).build());
  assertEquals("sensitive-value",
   YouTubeOAuthSettingsConfiguration.read(ssm,YouTubeOAuthSettingsConfiguration.CLIENT_SECRET));
  var captor=ArgumentCaptor.forClass(GetParameterRequest.class);
  verify(ssm).getParameter(captor.capture());
  assertEquals("/weutube/prod/youtube/client-secret",captor.getValue().name());
  assertTrue(captor.getValue().withDecryption());
 }
 @Test void rejectsMissingSsmValue() {
  SsmClient ssm=mock(SsmClient.class);
  when(ssm.getParameter(any(GetParameterRequest.class)))
   .thenReturn(GetParameterResponse.builder().parameter(Parameter.builder().value("").build()).build());
  assertThrows(IllegalStateException.class,
   ()->YouTubeOAuthSettingsConfiguration.read(ssm,YouTubeOAuthSettingsConfiguration.CLIENT_ID));
 }
}
