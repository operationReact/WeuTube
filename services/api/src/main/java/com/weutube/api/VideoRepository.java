package com.weutube.api;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
public interface VideoRepository extends JpaRepository<VideoSubmission,UUID> {
 List<VideoSubmission> findByCreatorCognitoSubOrderByCreatedAtDesc(String sub);
 List<VideoSubmission> findByStatus(String status, Pageable pageable);
}
