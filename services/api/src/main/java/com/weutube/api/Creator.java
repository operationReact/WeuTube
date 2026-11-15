package com.weutube.api;
import jakarta.persistence.*;
import java.util.UUID;
@Entity
@Table(name="creators")
public class Creator {
 @Id public UUID id;
 @Column(name="cognito_sub",nullable=false,unique=true) public String cognitoSub;
 @Column(name="display_name",nullable=false) public String displayName;
 protected Creator() {}
 public Creator(String sub,String name) { id=UUID.randomUUID(); cognitoSub=sub; displayName=name; }
}
