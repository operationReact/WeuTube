package com.weutube.api;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.net.URI;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.SingleConnectionDataSource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.security.oauth2.jwt.Jwt;

/** Real PostgreSQL driver and production OAuth-state schema, not a mocked JDBC binding. */
@EnabledIfEnvironmentVariable(named="WEUTUBE_TEST_POSTGRES_URL",matches=".+")
class YouTubeOAuthPostgresTest {
 @Test void createsAndPersistsOAuthAuthorizationStateWithUtcExpiry() {
  var ds=new SingleConnectionDataSource(System.getenv("WEUTUBE_TEST_POSTGRES_URL"),
   System.getenv("WEUTUBE_TEST_POSTGRES_USER"),
   System.getenv("WEUTUBE_TEST_POSTGRES_PASSWORD"),true);
  try {
   var jdbc=new JdbcTemplate(ds);
   // This database is created specifically for this CI job.
   new ResourceDatabasePopulator(new ClassPathResource(
    "db/migration/V3__youtube_oauth_attempts.sql")).execute(ds);
   var store=mock(YouTubeCredentialStore.class);
   var connection=mock(YouTubeConnectionService.class);
   when(connection.configured()).thenReturn(true);
   var controller=new YouTubeOAuthController(jdbc,store,connection,
    "test-google-client","https://api.weutube.com/api/admin/youtube/callback","weutube-admin");
   var admin=Jwt.withTokenValue("test").header("alg","none").subject("integration-admin")
    .claim("cognito:groups",List.of("weutube-admin")).build();
   Instant before=Instant.now();
   var result=controller.start(admin);
   String state=java.util.Arrays.stream(URI.create(result.url()).getRawQuery().split("&"))
    .filter(part->part.startsWith("state=")).findFirst().orElseThrow().substring(6);
   assertTrue(state.matches("[A-Za-z0-9_-]{43}"));
   OffsetDateTime expires=jdbc.queryForObject(
    "SELECT expires_at FROM youtube_oauth_attempts WHERE state=? AND admin_sub=? AND consumed_at IS NULL",
    (rs,i)->rs.getObject(1,OffsetDateTime.class),state,"integration-admin");
   assertNotNull(expires);
   assertTrue(expires.toInstant().isAfter(before.plusSeconds(590)));
   assertTrue(Math.abs(java.time.Duration.between(result.expiresAt(),expires.toInstant()).toMillis())<1);
   assertEquals(ZoneOffset.UTC,expires.getOffset());
  } finally {
   ds.destroy();
  }
 }
}
