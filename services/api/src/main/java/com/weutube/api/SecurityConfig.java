package com.weutube.api;
import jakarta.servlet.DispatcherType;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.server.resource.BearerTokenError;
import org.springframework.security.oauth2.server.resource.BearerTokenErrorCodes;
import org.springframework.security.oauth2.server.resource.web.BearerTokenAuthenticationEntryPoint;
import org.springframework.security.oauth2.server.resource.web.access.BearerTokenAccessDeniedHandler;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.config.http.SessionCreationPolicy;
@Configuration
public class SecurityConfig {
 static OAuth2AuthenticationException invalidToken() {
  return new OAuth2AuthenticationException(new BearerTokenError(
    BearerTokenErrorCodes.INVALID_TOKEN,HttpStatus.UNAUTHORIZED,
    "Invalid Cognito access token for this application",null));
 }
 @Bean CorsConfigurationSource corsConfigurationSource() {
  var cors=new CorsConfiguration();
  cors.setAllowedOrigins(List.of("https://weutube.com","https://www.weutube.com"));
  cors.setAllowedMethods(List.of("GET","POST","PUT","PATCH","DELETE","OPTIONS"));
  cors.setAllowedHeaders(List.of("Authorization","Content-Type","Content-Range"));
  cors.setMaxAge(3600L);
  cors.setAllowCredentials(false);
  cors.setExposedHeaders(List.of("X-WeuTube-Auth-Status"));
  var source=new UrlBasedCorsConfigurationSource();
  source.registerCorsConfiguration("/api/**",cors);
  return source;
 }
 @Bean SecurityFilterChain security(HttpSecurity http,
  @Value("${weutube.cognito.client-id:}") String expectedClientId) throws Exception {
  return http.cors(org.springframework.security.config.Customizer.withDefaults())
   .csrf(csrf -> csrf.disable())
   .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
   .exceptionHandling(errors -> errors
     .authenticationEntryPoint((request,response,exception) -> {
       response.setHeader("X-WeuTube-Auth-Status","AUTHENTICATION_REQUIRED");
       new BearerTokenAuthenticationEntryPoint()
         .commence(request,response,exception);
     })
     .accessDeniedHandler((request,response,exception) -> {
       response.setHeader("X-WeuTube-Auth-Status","AUTHORIZATION_DENIED");
       new BearerTokenAccessDeniedHandler()
         .handle(request,response,exception);
     }))
   .authorizeHttpRequests(a -> a
     .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
     .requestMatchers("/actuator/health","/api/public/**").permitAll()
     .requestMatchers(HttpMethod.GET,"/api/social/videos/*/comments").permitAll()
     .requestMatchers(HttpMethod.GET,"/api/admin/youtube/callback").permitAll()
     .requestMatchers(HttpMethod.OPTIONS,"/**").permitAll()
     .anyRequest().authenticated())
   .oauth2ResourceServer(o -> o.jwt(j -> j.jwtAuthenticationConverter(token -> {
      if (!"access".equals(token.getClaimAsString("token_use")))
       throw invalidToken();
      if(!expectedClientId.isBlank()
        && !expectedClientId.equals(token.getClaimAsString("client_id")))
       throw invalidToken();
      return new JwtAuthenticationToken(token);
    }))).build();
 }
}