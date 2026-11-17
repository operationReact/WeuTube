package com.weutube.api;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;
@SpringBootApplication
@EnableScheduling
public class WeuTubeApplication {
  public static void main(String[] args) { SpringApplication.run(WeuTubeApplication.class,args); }
}