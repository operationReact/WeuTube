package com.weutube.api;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;
@Entity
@Table(name="video_submissions")
public class VideoSubmission {
 @Id public UUID id;
 @ManyToOne(optional=false) @JoinColumn(name="creator_id") public Creator creator;
 @Column(nullable=false,length=200) public String title;
 @Column(nullable=false,length=32) public String status;
 @Column(name="created_at",nullable=false) public Instant createdAt;
 @Column(name="updated_at",nullable=false) public Instant updatedAt;
 protected VideoSubmission() {}
 public VideoSubmission(Creator creator,String title) {
  id=UUID.randomUUID(); this.creator=creator; this.title=title; status="DRAFT";
  createdAt=Instant.now(); updatedAt=createdAt;
 }
}
