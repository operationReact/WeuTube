package com.weutube.api;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.config.http.SessionCreationPolicy;
@Configuration
public class SecurityConfig {
 @Bean SecurityFilterChain security(HttpSecurity http) throws Exception {
  return http.csrf(csrf -> csrf.disable())
   .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
   .authorizeHttpRequests(a -> a
     .requestMatchers("/actuator/health","/api/public/**").permitAll()
     .requestMatchers(HttpMethod.OPTIONS,"/**").permitAll()
     .anyRequest().authenticated())
   .oauth2ResourceServer(o -> o.jwt(j -> {})).build();
 }
}