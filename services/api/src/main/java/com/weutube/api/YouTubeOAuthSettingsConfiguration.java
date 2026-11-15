package com.weutube.api;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.ssm.SsmClient;
import software.amazon.awssdk.services.ssm.model.GetParameterRequest;
import software.amazon.awssdk.services.ssm.model.GetParameterResponse;

/**
 * Loads OAuth settings either from environment variables or AWS Systems Manager
 * using the workload's IAM role and the SDK default credentials provider chain.
 * No hardcoded AWS access keys, and no credentials are printed.
 */
@Configuration(proxyBeanMethods=false)
public class YouTubeOAuthSettingsConfiguration {
 static final String CLIENT_ID="/weutube/prod/youtube/client-id";
 static final String CLIENT_SECRET="/weutube/prod/youtube/client-secret";
 static final String TOKEN_KEY="/weutube/prod/youtube/token-key-base64";

 @Bean
 YouTubeOAuthSettings youtubeOAuthSettings(
   @Value("${weutube.youtube.ssm-enabled:false}") boolean ssmEnabled,
   @Value("${weutube.youtube.ssm-region:ap-south-1}") String region,
   @Value("${weutube.youtube.client-id:}") String clientId,
   @Value("${weutube.youtube.client-secret:}") String clientSecret,
   @Value("${weutube.youtube.redirect-uri:}") String redirectUri,
   @Value("${weutube.youtube.token-key-base64:}") String encryptionKey) {
  if (!ssmEnabled) return new YouTubeOAuthSettings(clientId,clientSecret,redirectUri,encryptionKey);
  try (SsmClient ssm=SsmClient.builder().region(Region.of(region)).build()) {
   String ssmClientId=read(ssm,CLIENT_ID);
   String ssmClientSecret=read(ssm,CLIENT_SECRET);
   String key=encryptionKey.isBlank() ? read(ssm,TOKEN_KEY) : encryptionKey;
   return new YouTubeOAuthSettings(ssmClientId,ssmClientSecret,redirectUri,key);
  } catch (RuntimeException e) {
   // Avoid exception messages from the SSM SDK that might contain request metadata.
   throw new IllegalStateException("WeuTube YouTube configuration could not be loaded from AWS SSM");
  }
 }
 static String read(SsmClient ssm,String parameterName) {
  GetParameterResponse response=ssm.getParameter(GetParameterRequest.builder()
    .name(parameterName).withDecryption(true).build());
  if (response.parameter()==null || response.parameter().value()==null
      || response.parameter().value().isBlank())
   throw new IllegalStateException("Required WeuTube SSM parameter is empty");
  return response.parameter().value();
 }
}

record YouTubeOAuthSettings(String clientId,String clientSecret,String redirectUri,String tokenKeyBase64) {}
