package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.server.ResponseStatusException;

class CreatorGrantedChannelControllerTest {
 private final JdbcTemplate jdbc=mock(JdbcTemplate.class);
 private final Jwt user=Jwt.withTokenValue("test").header("alg","none")
   .subject("creator-sub").build();
 private final CreatorGrantedChannelController.GrantedChannel channel=
   new CreatorGrantedChannelController.GrantedChannel("UC_verified","Platform channel");

 @Test void optInCreatorGetsOnlyTheOneConnectedPlatformChannel() {
  when(jdbc.query(anyString(),any(RowMapper.class))).thenReturn(List.of(channel));
  when(jdbc.queryForObject(anyString(),eq(Boolean.class),
    eq("creator-sub"),eq("UC_verified"))).thenReturn(false);
  var granted=new CreatorGrantedChannelController(jdbc,true).activate(user);
  assertEquals("UC_verified",granted.channelId());
  verify(jdbc).update(contains("INSERT INTO creator_channel_grants"),
    eq("UC_verified"),eq("weutube:creator-onboarding"),eq("creator-sub"));
 }

 @Test void autoUploadDisabledDoesNotQueryOrGrantAnything() {
  var ex=assertThrows(ResponseStatusException.class,
    ()->new CreatorGrantedChannelController(jdbc,false).activate(user));
  assertEquals(HttpStatus.FORBIDDEN,ex.getStatusCode());
  verifyNoInteractions(jdbc);
 }

 @Test void adminRevocationBlocksAutomaticRegrant() {
  when(jdbc.query(anyString(),any(RowMapper.class))).thenReturn(List.of(channel));
  when(jdbc.queryForObject(anyString(),eq(Boolean.class),
    eq("creator-sub"),eq("UC_verified"))).thenReturn(true);
  var ex=assertThrows(ResponseStatusException.class,
    ()->new CreatorGrantedChannelController(jdbc,true).activate(user));
  assertEquals(HttpStatus.FORBIDDEN,ex.getStatusCode());
  verify(jdbc,never()).update(anyString(),any(),any(),any());
 }

 @Test void unconnectedChannelFailsClosed() {
  when(jdbc.query(anyString(),any(RowMapper.class))).thenReturn(List.of());
  var ex=assertThrows(ResponseStatusException.class,
    ()->new CreatorGrantedChannelController(jdbc,true).activate(user));
  assertEquals(HttpStatus.SERVICE_UNAVAILABLE,ex.getStatusCode());
 }

 @Test void multipleConnectedChannelsNeedExplicitAdministratorChoice() {
  when(jdbc.query(anyString(),any(RowMapper.class))).thenReturn(List.of(
    channel,new CreatorGrantedChannelController.GrantedChannel("UC_other","Other")));
  var ex=assertThrows(ResponseStatusException.class,
    ()->new CreatorGrantedChannelController(jdbc,true).activate(user));
  assertEquals(HttpStatus.CONFLICT,ex.getStatusCode());
 }
}
