package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import org.junit.jupiter.api.Test;

class GoogleLoginConfigurationControllerTest {
 @Test void googleLoginIsDisabledWithoutASeparateIdentityProvider() {
  var config=new GoogleLoginConfigurationController(false,
    "https://weutube-prod-login.auth.ap-south-1.amazoncognito.com","public-client")
    .configuration();
  assertEquals(false,config.getBody().get("enabled"));
  assertEquals("",config.getBody().get("hostedUiDomain"));
  assertTrue(config.getHeaders().getCacheControl().contains("no-store"));
 }
 @Test void exposesOnlyPublicPkceDiscovery() {
  var result=new GoogleLoginConfigurationController(true,
    "https://weutube-prod-login.auth.ap-south-1.amazoncognito.com","public-client")
    .configuration().getBody();
  assertEquals(true,result.get("enabled"));
  assertEquals("weutube://auth-callback",result.get("nativeRedirectUri"));
  assertEquals("https://weutube.com/auth.html",result.get("webRedirectUri"));
  assertFalse(result.containsKey("clientSecret"));
  assertFalse(result.containsKey("youtubeToken"));
 }
}
