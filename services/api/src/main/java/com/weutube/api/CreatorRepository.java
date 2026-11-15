package com.weutube.api;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
public interface CreatorRepository extends JpaRepository<Creator,UUID> {
 Optional<Creator> findByCognitoSub(String cognitoSub);
}
