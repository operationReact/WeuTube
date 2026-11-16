package com.weutube.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.Map;
import java.util.Locale;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import software.amazon.awssdk.services.cognitoidentityprovider.CognitoIdentityProviderClient;
import software.amazon.awssdk.services.cognitoidentityprovider.model.*;

/** Real Cognito user-pool authentication contract. Tokens must be secured by the client. */
@RestController
@RequestMapping("/api/public/auth")
public class CognitoAuthController {
 private final CognitoIdentityProviderClient cognito;
 private final String clientId;
 public CognitoAuthController(CognitoIdentityProviderClient cognito,
    @Value("${weutube.cognito.client-id:}") String clientId) {
  this.cognito=cognito;this.clientId=clientId;
 }
 private String clientId() {
  if(clientId.isBlank())
   throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
      "WeuTube authentication is not configured");
  return clientId;
 }
 private static String email(String value) { return value.trim().toLowerCase(Locale.ROOT); }
 private static <T> ResponseEntity<T> privateResponse(T body) {
  return ResponseEntity.ok()
    .cacheControl(CacheControl.noStore())
    .header("Pragma","no-cache").header("Referrer-Policy","no-referrer")
    .body(body);
 }
 public record Registration(@Email @NotBlank String email,
    @NotBlank @Size(min=12,max=128) String password,
    @NotBlank @Size(max=150) String displayName) {}
 public record EmailCode(@Email @NotBlank String email,
    @NotBlank @Size(min=4,max=30) String code) {}
 public record EmailRequest(@Email @NotBlank String email) {}
 public record ResetPassword(@Email @NotBlank String email,
    @NotBlank String code,@NotBlank @Size(min=12,max=128) String newPassword) {}
 public record PasswordLogin(@Email @NotBlank String email,@NotBlank String password) {}
 public record Refresh(@NotBlank String refreshToken) {}
 public record MfaCode(@Email @NotBlank String email,
   @NotBlank String session,
   @Pattern(regexp="SOFTWARE_TOKEN_MFA|SMS_MFA") String challenge,
   @Pattern(regexp="[0-9]{6,8}") String code) {}
 public record LoginResult(String status,String accessToken,String idToken,
   String refreshToken,Integer expiresIn,String challenge,String session) {}

 private LoginResult tokens(AuthenticationResultType result) {
  if(result==null || result.accessToken()==null)
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,"Cognito did not return tokens");
  return new LoginResult("SIGNED_IN",result.accessToken(),result.idToken(),
      result.refreshToken(),result.expiresIn(),null,null);
 }
 @PostMapping("/sign-up")
 public ResponseEntity<Map<String,Object>> signup(@Valid @RequestBody Registration input) {
  try {
   var reply=cognito.signUp(SignUpRequest.builder()
     .clientId(clientId()).username(email(input.email())).password(input.password())
     .userAttributes(
       AttributeType.builder().name("email").value(email(input.email())).build(),
       AttributeType.builder().name("name").value(input.displayName().trim()).build())
     .build());
   return privateResponse(Map.of("status",reply.userConfirmed()?"CONFIRMED":"CONFIRMATION_REQUIRED"));
  } catch (CognitoIdentityProviderException ex) {
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
      "Could not register account; check the email and password policy");
  }
 }
 @PostMapping("/confirm")
 public ResponseEntity<Map<String,String>> confirm(@Valid @RequestBody EmailCode input) {
  try {
   cognito.confirmSignUp(ConfirmSignUpRequest.builder().clientId(clientId())
     .username(email(input.email())).confirmationCode(input.code()).build());
   return privateResponse(Map.of("status","CONFIRMED"));
  } catch(CognitoIdentityProviderException ex) {
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
     "Confirmation failed or the code expired");
  }
 }
 @PostMapping("/resend-code")
 public ResponseEntity<Map<String,String>> resend(@Valid @RequestBody EmailRequest input) {
  try {
   cognito.resendConfirmationCode(ResendConfirmationCodeRequest.builder()
     .clientId(clientId()).username(email(input.email())).build());
  } catch(CognitoIdentityProviderException ignored) {
   // Avoid disclosing account existence through a public endpoint.
  }
  return privateResponse(Map.of("status","IF_ACCOUNT_EXISTS_CODE_SENT"));
 }
 @PostMapping("/sign-in")
 public ResponseEntity<LoginResult> login(@Valid @RequestBody PasswordLogin input) {
  try {
   var reply=cognito.initiateAuth(InitiateAuthRequest.builder()
     .clientId(clientId()).authFlow(AuthFlowType.USER_PASSWORD_AUTH)
     .authParameters(Map.of("USERNAME",email(input.email()),"PASSWORD",input.password()))
     .build());
   if(reply.authenticationResult()!=null)
    return privateResponse(tokens(reply.authenticationResult()));
   String challenge=reply.challengeNameAsString();
   if(!"SOFTWARE_TOKEN_MFA".equals(challenge) && !"SMS_MFA".equals(challenge))
    throw new ResponseStatusException(HttpStatus.PRECONDITION_REQUIRED,
      "Cognito requires additional account setup or an unsupported challenge");
   return privateResponse(new LoginResult("CHALLENGE_REQUIRED",null,null,null,null,
     challenge,reply.session()));
  } catch(CognitoIdentityProviderException ex) {
   throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,
     "Invalid credentials or unconfirmed account");
  }
 }
 @PostMapping("/confirm-mfa")
 public ResponseEntity<LoginResult> mfa(@Valid @RequestBody MfaCode input) {
  try {
   var response=cognito.respondToAuthChallenge(RespondToAuthChallengeRequest.builder()
     .clientId(clientId()).challengeName(ChallengeNameType.fromValue(input.challenge()))
     .session(input.session())
     .challengeResponses(Map.of(
       "USERNAME",email(input.email()),
       input.challenge().equals("SOFTWARE_TOKEN_MFA")?"SOFTWARE_TOKEN_MFA_CODE":"SMS_MFA_CODE",input.code()))
     .build());
   return privateResponse(tokens(response.authenticationResult()));
  } catch(CognitoIdentityProviderException ex) {
   throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,"MFA verification failed");
  }
 }
 @PostMapping("/refresh")
 public ResponseEntity<LoginResult> refresh(@Valid @RequestBody Refresh input) {
  try {
   var reply=cognito.initiateAuth(InitiateAuthRequest.builder()
     .clientId(clientId()).authFlow(AuthFlowType.REFRESH_TOKEN_AUTH)
     .authParameters(Map.of("REFRESH_TOKEN",input.refreshToken())).build());
   return privateResponse(tokens(reply.authenticationResult()));
  } catch(CognitoIdentityProviderException ex) {
   throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,"Session expired; sign in again");
  }
 }
 @PostMapping("/forgot-password")
 public ResponseEntity<Map<String,String>> forgot(@Valid @RequestBody EmailRequest input) {
  try {
   cognito.forgotPassword(ForgotPasswordRequest.builder()
     .clientId(clientId()).username(email(input.email())).build());
  } catch(CognitoIdentityProviderException ignored) {
   // Avoid leaking which accounts exist.
  }
  return privateResponse(Map.of("status","IF_ACCOUNT_EXISTS_CODE_SENT"));
 }
 @PostMapping("/reset-password")
 public ResponseEntity<Map<String,String>> reset(@Valid @RequestBody ResetPassword input) {
  try {
   cognito.confirmForgotPassword(ConfirmForgotPasswordRequest.builder()
     .clientId(clientId()).username(email(input.email()))
     .confirmationCode(input.code()).password(input.newPassword()).build());
   return privateResponse(Map.of("status","PASSWORD_UPDATED"));
  } catch(CognitoIdentityProviderException ex) {
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Password reset failed or code expired");
  }
 }
}
