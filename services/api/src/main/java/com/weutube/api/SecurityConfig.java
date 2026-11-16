package com.weutube.api;
import jakarta.servlet.DispatcherType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.config.http.SessionCreationPolicy;
@Configuration
public class SecurityConfig {
 @Bean CorsConfigurationSource corsConfigurationSource() {
  var cors=new CorsConfiguration();
  cors.setAllowedOrigins(List.of("https://weutube.com","https://www.weutube.com"));
  cors.setAllowedMethods(List.of("GET","POST","PUT","PATCH","DELETE","OPTIONS"));
  cors.setAllowedHeaders(List.of("Authorization","Content-Type"));
  cors.setMaxAge(3600L);
  cors.setAllowCredentials(false);
  var source=new UrlBasedCorsConfigurationSource();
  source.registerCorsConfiguration("/api/**",cors);
  return source;
 }
 @Bean SecurityFilterChain security(HttpSecurity http,
  @Value("${weutube.cognito.client-id:}") String expectedClientId) throws Exception {
  return http.cors(org.springframework.security.config.Customizer.withDefaults())
   .csrf(csrf -> csrf.disable())
   .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
   .authorizeHttpRequests(a -> a
     .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
     .requestMatchers("/actuator/health","/api/public/**").permitAll()
     .requestMatchers(HttpMethod.GET,"/api/social/videos/*/comments").permitAll()
     .requestMatchers(HttpMethod.GET,"/api/admin/youtube/callback").permitAll()
     .requestMatchers(HttpMethod.OPTIONS,"/**").permitAll()
     .anyRequest().authenticated())
   .oauth2ResourceServer(o -> o.jwt(j -> j.jwtAuthenticationConverter(token -> {
      if (!"access".equals(token.getClaimAsString("token_use")))
       throw new BadCredentialsException("Cognito access token required");
      if(!expectedClientId.isBlank()
        && !expectedClientId.equals(token.getClaimAsString("client_id")))
       throw new BadCredentialsException("Token is for a different app client");
      return new JwtAuthenticationToken(token);
    }))).build();
 }
}