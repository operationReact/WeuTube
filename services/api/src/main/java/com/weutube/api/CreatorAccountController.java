package com.weutube.api;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/** Creator profile is always derived from the verified JWT subject, never a user-supplied ID. */
@RestController
@RequestMapping("/api/creator/account")
public class CreatorAccountController {
 private final CreatorRepository creators;
 public CreatorAccountController(CreatorRepository creators) { this.creators=creators; }
 public record Profile(String displayName,String subject) {}
 public record UpdateProfile(@NotBlank @Size(max=150) String displayName) {}

 @GetMapping
 @Transactional
 public Profile profile(@AuthenticationPrincipal Jwt jwt) {
  Creator creator=creators.findByCognitoSub(jwt.getSubject())
   .orElseGet(()->creators.save(new Creator(jwt.getSubject(),"Creator")));
  return new Profile(creator.displayName,creator.cognitoSub);
 }
 @PatchMapping
 @Transactional
 public Profile update(@AuthenticationPrincipal Jwt jwt,@Valid @RequestBody UpdateProfile update) {
  String name=update.displayName().trim();
  if(name.isEmpty()) throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Display name required");
  Creator creator=creators.findByCognitoSub(jwt.getSubject())
   .orElseGet(()->creators.save(new Creator(jwt.getSubject(),name)));
  creator.displayName=name;
  creators.save(creator);
  return new Profile(creator.displayName,creator.cognitoSub);
 }
}
