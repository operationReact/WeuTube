package com.weutube.api;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.server.ResponseStatusException;
class CreatorVideoControllerTest {
 CreatorRepository creators;
 VideoRepository videos;
 CreatorVideoController controller;
 Jwt owner;
 Jwt stranger;
 @BeforeEach void setup() {
  creators=mock(CreatorRepository.class);
  videos=mock(VideoRepository.class);
  controller=new CreatorVideoController(creators,videos);
  owner=Jwt.withTokenValue("owner").header("alg","none").subject("owner").build();
  stranger=Jwt.withTokenValue("stranger").header("alg","none").subject("stranger").build();
 }
 @Test void cannotRenameAnotherCreatorsDraft() {
  Creator creator=new Creator("owner","Creator");
  VideoSubmission video=new VideoSubmission(creator,"Original");
  when(videos.findById(video.id)).thenReturn(Optional.of(video));
  ResponseStatusException error=assertThrows(ResponseStatusException.class,
   ()->controller.renameDraft(stranger,video.id,new CreatorVideoController.DraftRequest("Stolen")));
  assertEquals(HttpStatus.NOT_FOUND,error.getStatusCode());
  verify(videos,never()).save(any());
 }
 @Test void cannotDeleteNonDraft() {
  VideoSubmission video=new VideoSubmission(new Creator("owner","Creator"),"Title");
  video.status="APPROVED";
  when(videos.findById(video.id)).thenReturn(Optional.of(video));
  ResponseStatusException error=assertThrows(ResponseStatusException.class,
   ()->controller.deleteDraft(owner,video.id));
  assertEquals(HttpStatus.CONFLICT,error.getStatusCode());
  verify(videos,never()).delete(any());
 }
 @Test void canRenameOwnedDraft() {
  VideoSubmission video=new VideoSubmission(new Creator("owner","Creator"),"Original");
  when(videos.findById(video.id)).thenReturn(Optional.of(video));
  var result=controller.renameDraft(owner,video.id,new CreatorVideoController.DraftRequest(" New title "));
  assertEquals("New title",result.title());
  verify(videos).save(video);
 }
}
