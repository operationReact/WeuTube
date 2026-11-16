package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.oauth2.jwt.Jwt;

class AdminChannelGrantControllerTest {
 private final JdbcTemplate jdbc=mock(JdbcTemplate.class);
 private final AdminChannelGrantController controller=
   new AdminChannelGrantController(jdbc,"weutube-admin");
 private final Jwt admin=Jwt.withTokenValue("test").header("alg","none")
   .subject("admin-creator").claim("cognito:groups",List.of("weutube-admin")).build();
 private final Jwt creator=Jwt.withTokenValue("test").header("alg","none")
   .subject("ordinary-creator").build();

 @Test void selfGrantUsesVerifiedJwtSubjectAndConnectedChannel() {
  when(jdbc.update(anyString(),eq("admin-creator"),eq("admin-creator"),eq("UC_test")))
    .thenReturn(1);
  var result=controller.grantMe(admin,"UC_test");
  assertEquals("granted",result.get("status"));
  assertEquals("admin-creator",result.get("creatorSubject"));
  verify(jdbc).update(anyString(),eq("admin-creator"),eq("admin-creator"),eq("UC_test"));
 }

 @Test void ordinaryCreatorCannotGrantThemselfUploadRights() {
  assertThrows(AccessDeniedException.class,()->controller.grantMe(creator,"UC_test"));
  verifyNoInteractions(jdbc);
 }
}
