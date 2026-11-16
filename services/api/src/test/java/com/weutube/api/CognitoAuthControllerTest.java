package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;
import software.amazon.awssdk.services.cognitoidentityprovider.CognitoIdentityProviderClient;
import software.amazon.awssdk.services.cognitoidentityprovider.model.*;

class CognitoAuthControllerTest {
 private final CognitoIdentityProviderClient cognito=mock(CognitoIdentityProviderClient.class);
 private final CognitoAuthController controller=new CognitoAuthController(cognito,"public-client");

 @Test void signsUpWithoutReturningPassword() {
  when(cognito.signUp(any(SignUpRequest.class)))
   .thenReturn(SignUpResponse.builder().userConfirmed(false).build());
  var response=controller.signup(
    new CognitoAuthController.Registration("CREATOR@EXAMPLE.COM","SecretPassword1!","Creator"));
  assertEquals("CONFIRMATION_REQUIRED",response.getBody().get("status"));
  assertFalse(response.toString().contains("SecretPassword1!"));
  assertTrue(response.getHeaders().getCacheControl().contains("no-store"));
 }
 @Test void returnsRealCognitoTokensAndNoStore() {
  when(cognito.initiateAuth(any(InitiateAuthRequest.class)))
   .thenReturn(InitiateAuthResponse.builder().authenticationResult(
     AuthenticationResultType.builder().accessToken("issued-access").idToken("issued-id")
       .refreshToken("issued-refresh").expiresIn(3600).build()).build());
  var response=controller.login(
    new CognitoAuthController.PasswordLogin("creator@example.com","SecretPassword1!"));
  assertEquals("SIGNED_IN",response.getBody().status());
  assertEquals("issued-access",response.getBody().accessToken());
  assertEquals("issued-refresh",response.getBody().refreshToken());
  assertTrue(response.getHeaders().getCacheControl().contains("no-store"));
 }
 @Test void unconfiguredLoginFailsClosed() {
  var disabled=new CognitoAuthController(cognito,"");
  var error=assertThrows(ResponseStatusException.class,
    ()->disabled.login(new CognitoAuthController.PasswordLogin(
      "creator@example.com","SecretPassword1!")));
  assertEquals(HttpStatus.SERVICE_UNAVAILABLE,error.getStatusCode());
  verifyNoInteractions(cognito);
 }
 @Test void invalidCredentialsHaveNoUserDetailsInError() {
  when(cognito.initiateAuth(any(InitiateAuthRequest.class)))
   .thenThrow(CognitoIdentityProviderException.builder().message("internal sensitive detail").build());
  var error=assertThrows(ResponseStatusException.class,
    ()->controller.login(new CognitoAuthController.PasswordLogin("a@example.com","wrong")));
  assertEquals(HttpStatus.UNAUTHORIZED,error.getStatusCode());
  assertFalse(error.getReason().contains("sensitive"));
 }
}
