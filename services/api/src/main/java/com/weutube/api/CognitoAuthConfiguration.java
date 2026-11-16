package com.weutube.api;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AnonymousCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.cognitoidentityprovider.CognitoIdentityProviderClient;

/** Public Cognito user-pool operations do not require IAM signing credentials. */
@Configuration(proxyBeanMethods=false)
public class CognitoAuthConfiguration {
 @Bean(destroyMethod="close")
 CognitoIdentityProviderClient cognitoIdentityProvider(
    @Value("${weutube.cognito.region:ap-south-1}") String region) {
  return CognitoIdentityProviderClient.builder()
    .region(Region.of(region))
    .credentialsProvider(AnonymousCredentialsProvider.create())
    .build();
 }
}
