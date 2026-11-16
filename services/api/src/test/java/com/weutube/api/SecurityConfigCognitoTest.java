package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import java.time.Instant;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.jwt.Jwt;

class SecurityConfigCognitoTest {
 private static Jwt token(String use,String client) {
  return new Jwt("fake-redacted-test-token", Instant.now(),
    Instant.now().plusSeconds(300),
    Map.of("alg","RS256"),
    Map.of("sub","test-creator","token_use",use,"client_id",client));
 }

 @Test void validAccessTokenAuthenticatesWithoutAdminGroupOrYoutubeGrant() {
  var authenticated=SecurityConfig.validateCognitoAccess(
    token("access","app-client"),"app-client");
  assertTrue(authenticated.isAuthenticated());
  assertEquals("test-creator",authenticated.getName());
  assertTrue(authenticated.getAuthorities().isEmpty());
 }

 @Test void rejectsIdTokenAsInvalidAuthenticationNotCreatorPermissionFailure() {
  var ex=assertThrows(OAuth2AuthenticationException.class,
    ()->SecurityConfig.validateCognitoAccess(
      token("id","app-client"),"app-client"));
  assertEquals("invalid_token",ex.getError().getErrorCode());
 }

 @Test void rejectsTokenForOtherAppClientAsInvalidAuthentication() {
  var ex=assertThrows(OAuth2AuthenticationException.class,
    ()->SecurityConfig.validateCognitoAccess(
      token("access","different-client"),"app-client"));
  assertEquals("invalid_token",ex.getError().getErrorCode());
 }

 @Test void matchesExpectedClientAndUsesCognitoSubject() {
  var result=SecurityConfig.validateCognitoAccess(
    token("access","correct-client"),"correct-client");
  assertEquals("test-creator",result.getToken().getSubject());
 }
}
