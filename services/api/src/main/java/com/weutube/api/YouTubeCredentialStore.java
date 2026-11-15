package com.weutube.api;

import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.UUID;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.SecureRandom;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;

/**
 * Encrypts Google refresh tokens before database storage.
 * Configure a random 256-bit key from a secrets manager; never commit it.
 * Production should migrate to AWS KMS envelope encryption with rotation.
 */
@Service
public class YouTubeCredentialStore {
 private final JdbcTemplate jdbc;
 private final byte[] key;
 private final SecureRandom random=new SecureRandom();
 public YouTubeCredentialStore(JdbcTemplate jdbc,
   @Value("${weutube.youtube.token-key-base64:}") String encodedKey) {
  this.jdbc=jdbc;
  if (encodedKey.isBlank()) {
   key=null;
  } else {
   byte[] decoded;
   try { decoded=Base64.getDecoder().decode(encodedKey); }
   catch (IllegalArgumentException e) { throw new IllegalStateException("Invalid YouTube encryption key",e); }
   if (decoded.length != 32) throw new IllegalStateException("YouTube encryption key must be 256 bits");
   key=decoded;
  }
 }
 public boolean configured() { return key!=null; }
 private byte[] requireKey() {
  if (key==null) throw new IllegalStateException("YouTube token encryption is not configured");
  return key;
 }
 public String encrypt(String plaintext,String channelId) {
  if (plaintext==null || plaintext.isBlank() || channelId==null || channelId.isBlank())
   throw new IllegalArgumentException("Token and channel ID required");
  try {
   byte[] nonce=new byte[12]; random.nextBytes(nonce);
   Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
   cipher.init(Cipher.ENCRYPT_MODE,new SecretKeySpec(requireKey(),"AES"),new GCMParameterSpec(128,nonce));
   cipher.updateAAD(channelId.getBytes(StandardCharsets.UTF_8));
   byte[] encrypted=cipher.doFinal(plaintext.getBytes(StandardCharsets.UTF_8));
   byte[] result=new byte[nonce.length+encrypted.length];
   System.arraycopy(nonce,0,result,0,nonce.length);
   System.arraycopy(encrypted,0,result,nonce.length,encrypted.length);
   return Base64.getEncoder().encodeToString(result);
  } catch (java.security.GeneralSecurityException e) {
   throw new IllegalStateException("Could not encrypt YouTube credential",e);
  }
 }
 public String decrypt(String ciphertext,String channelId) {
  try {
   byte[] combined=Base64.getDecoder().decode(ciphertext);
   if (combined.length<29) throw new IllegalArgumentException("Invalid encrypted credential");
   byte[] nonce=java.util.Arrays.copyOfRange(combined,0,12);
   byte[] payload=java.util.Arrays.copyOfRange(combined,12,combined.length);
   Cipher cipher=Cipher.getInstance("AES/GCM/NoPadding");
   cipher.init(Cipher.DECRYPT_MODE,new SecretKeySpec(requireKey(),"AES"),new GCMParameterSpec(128,nonce));
   cipher.updateAAD(channelId.getBytes(StandardCharsets.UTF_8));
   return new String(cipher.doFinal(payload),StandardCharsets.UTF_8);
  } catch (java.security.GeneralSecurityException e) {
   throw new IllegalStateException("Could not decrypt YouTube credential",e);
  }
 }
}
