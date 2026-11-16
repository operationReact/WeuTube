package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.server.ResponseStatusException;

class CreatorAccountControllerTest {
 private final CreatorRepository repo=mock(CreatorRepository.class);
 private final CreatorAccountController controller=new CreatorAccountController(repo);
 private final Jwt jwt=Jwt.withTokenValue("test").header("alg","none")
  .subject("creator-one").build();

 @Test void profileScopedToAuthenticatedSubject() {
  Creator creator=new Creator("creator-one","A Creator");
  when(repo.findByCognitoSub("creator-one")).thenReturn(Optional.of(creator));
  var profile=controller.profile(jwt);
  assertEquals("creator-one",profile.subject());
  assertEquals("A Creator",profile.displayName());
  verify(repo).findByCognitoSub("creator-one");
 }
 @Test void updateRejectsBlankName() {
  ResponseStatusException ex=assertThrows(ResponseStatusException.class,
   ()->controller.update(jwt,new CreatorAccountController.UpdateProfile("   ")));
  assertEquals(HttpStatus.BAD_REQUEST,ex.getStatusCode());
  verifyNoInteractions(repo);
 }
}
