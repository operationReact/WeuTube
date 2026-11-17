package com.weutube.api;
import java.time.Instant;
import org.springframework.beans.factory.annotation.Value;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
@RestController
@RequestMapping("/api")
public class ApiController {
 @Value("${weutube.release-sha:unversioned}") private String releaseSha;
 @GetMapping("/public/status")
 public Map<String,Object> status() { return Map.of("service","weutube-api","mode","integration-pending","time",Instant.now().toString()); }
 @GetMapping("/me")
 public Map<String,Object> me(Authentication authentication) { return Map.of("subject",authentication.getName()); }
 @PostMapping("/videos")
 public ResponseEntity<Map<String,String>> submit() {
  return ResponseEntity.status(501).body(Map.of("error","YouTube private upload and creator ownership workflow not yet configured"));
 }
 @PostMapping("/wallet/withdrawals")
 public ResponseEntity<Map<String,String>> withdrawal() {
  return ResponseEntity.status(501).body(Map.of("error","Payout reconciliation and verified balance service not yet configured"));
 }
}