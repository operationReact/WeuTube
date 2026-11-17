package com.weutube.api;

import java.util.Map;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Public, non-secret Cognito Google-federation discovery.
 * This is NOT YouTube channel OAuth; a separate Google Login IdP is required.
 * Google login is unavailable until the operator enables the identity provider.
 */
@RestController
@RequestMapping("/api/public/auth")
public class GoogleLoginConfigurationController {
 private final boolean enabled;
 private final String hostedUiDomain;
 private final String clientId;

 public GoogleLoginConfigurationController(
    @Value("\${weutube.cognito.google-enabled:false}") boolean enabled,
    @Value("\${weutube.cognito.hosted-ui-domain:}") String hostedUiDomain,
    @Value("\${weutube.cognito.client-id:}") String clientId) {
  this.enabled=enabled;
  this.hostedUiDomain=hostedUiDomain;
  this.clientId=clientId;
 }

 @GetMapping("/google-config")
 public ResponseEntity<Map<String,Object>> configuration() {
  boolean ready=enabled &&
    hostedUiDomain.startsWith("https://") &&
    !clientId.isBlank();
  return ResponseEntity.ok()
    .cacheControl(CacheControl.noStore())
    .body(Map.of(
      "enabled",ready,
      "hostedUiDomain",ready?hostedUiDomain:"",
      "clientId",ready?clientId:"",
      "nativeRedirectUri","weutube://auth-callback",
      "webRedirectUri","https://weutube.com/auth.html"));
 }
}
