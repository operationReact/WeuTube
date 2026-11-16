package com.weutube.api;

import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import software.amazon.awssdk.services.cognitoidentityprovider.CognitoIdentityProviderClient;
import software.amazon.awssdk.services.cognitoidentityprovider.model.CognitoIdentityProviderException;
import software.amazon.awssdk.services.cognitoidentityprovider.model.GlobalSignOutRequest;

/** Revokes Cognito sign-in sessions using the already validated access token. */
@RestController
@RequestMapping("/api/auth")
public class CognitoSessionController {
 private final CognitoIdentityProviderClient cognito;
 public CognitoSessionController(CognitoIdentityProviderClient cognito) {
  this.cognito=cognito;
 }
 @PostMapping("/sign-out")
 @ResponseStatus(HttpStatus.NO_CONTENT)
 public void signOut(@AuthenticationPrincipal Jwt jwt,
   @RequestHeader(HttpHeaders.AUTHORIZATION) String authorization) {
  if(jwt==null || authorization==null || !authorization.startsWith("Bearer "))
   throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Access token required");
  try {
   cognito.globalSignOut(GlobalSignOutRequest.builder()
      .accessToken(authorization.substring("Bearer ".length())).build());
  } catch(CognitoIdentityProviderException ex) {
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
      "Could not revoke Cognito session");
  }
 }
}
