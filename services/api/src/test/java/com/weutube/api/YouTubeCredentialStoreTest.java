package com.weutube.api;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
class YouTubeCredentialStoreTest {
 private static String key() {
  return Base64.getEncoder().encodeToString("0123456789abcdef0123456789abcdef".getBytes(StandardCharsets.UTF_8));
 }
 @Test void encryptionRoundTripAndUniqueNonces() {
  var store=new YouTubeCredentialStore(mock(JdbcTemplate.class),key());
  String first=store.encrypt("refresh-secret","channel-1");
  String second=store.encrypt("refresh-secret","channel-1");
  assertNotEquals(first,second);
  assertEquals("refresh-secret",store.decrypt(first,"channel-1"));
  assertNotEquals("refresh-secret",first);
 }
 @Test void wrongChannelCannotDecrypt() {
  var store=new YouTubeCredentialStore(mock(JdbcTemplate.class),key());
  String ciphertext=store.encrypt("refresh-secret","channel-1");
  assertThrows(IllegalStateException.class,()->store.decrypt(ciphertext,"channel-2"));
 }
 @Test void missingKeyFailsClosed() {
  var store=new YouTubeCredentialStore(mock(JdbcTemplate.class),"");
  assertFalse(store.configured());
  assertThrows(IllegalStateException.class,()->store.encrypt("secret","channel-1"));
 }
}
