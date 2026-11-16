package com.weutube.api;

import java.util.Map;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

/** Owner-scoped upload: only admin-granted channels, always private. */
@RestController
@RequestMapping("/api/creator/videos")
public class CreatorPrivateUploadController {
 private final JdbcTemplate jdbc;
 private final GooglePrivateUploadService uploader;
 public CreatorPrivateUploadController(JdbcTemplate jdbc,GooglePrivateUploadService uploader) {
  this.jdbc=jdbc;this.uploader=uploader;
 }
 public record UploadedVideo(UUID id,String youtubeVideoId,String status) {}

 @PostMapping(value="/{id}/private-upload",consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
 public UploadedVideo upload(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,
   @RequestParam("channelId") String channelId,@RequestPart("file") MultipartFile file) {
  if(channelId==null || channelId.isBlank() || channelId.length()>128)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid channel ID");
  if(file.getSize()<=0 || file.getSize()>GooglePrivateUploadService.MAX_UPLOAD_BYTES)
   throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE,"Video must be 1-256 MB");
  // Verify ownership and channel assignment in one atomic transition.
  var drafts=jdbc.query("""
    SELECT v.title FROM video_submissions v
    JOIN creators c ON c.id=v.creator_id
    JOIN creator_channel_grants g ON g.creator_id=c.id
    JOIN youtube_oauth_credentials auth ON auth.youtube_channel_id=g.youtube_channel_id
    WHERE v.id=? AND v.status='DRAFT' AND c.cognito_sub=? AND g.youtube_channel_id=?
    """,(rs,row)->rs.getString(1),id,jwt.getSubject(),channelId);
  if(drafts.isEmpty())
   throw new ResponseStatusException(HttpStatus.NOT_FOUND,"Owned draft or channel grant not found");
  String title=drafts.get(0);
  if(title.length()>100)
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"YouTube titles must be at most 100 characters");
  int claimed=jdbc.update("""
    UPDATE video_submissions v
    SET status='UPLOADING',updated_at=now()
    WHERE v.id=? AND v.status='DRAFT'
      AND EXISTS (
        SELECT 1 FROM creators c JOIN creator_channel_grants g ON g.creator_id=c.id
        JOIN youtube_oauth_credentials auth ON auth.youtube_channel_id=g.youtube_channel_id
        WHERE c.id=v.creator_id AND c.cognito_sub=? AND g.youtube_channel_id=?
      )
    """,id,jwt.getSubject(),channelId);
  if(claimed!=1)
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Upload already started");
  // Do not wrap remote Google upload in a long-running database transaction.
  // UPLOADING is retained on uncertain failure to avoid accidental duplicate uploads.
  GooglePrivateUploadService.Uploaded result;
  try {
   result=uploader.upload(channelId,title,file);
  } catch (IllegalArgumentException ex) {
   jdbc.update("UPDATE video_submissions SET status='DRAFT',updated_at=now() WHERE id=? AND status='UPLOADING'",
      id);
   throw new ResponseStatusException(HttpStatus.BAD_REQUEST,"Unsupported upload request");
  } catch (RuntimeException ex) {
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
     "Google upload failed; the submission requires reconciliation before retry");
  }
  int updated=jdbc.update("""
    UPDATE video_submissions
    SET status='PRIVATE_REVIEW',youtube_video_id=?,
      youtube_channel_id=(SELECT id FROM youtube_channels WHERE youtube_channel_id=?),
      updated_at=now()
    WHERE id=? AND status='UPLOADING'
    """,result.id(),channelId,id);
  if(updated!=1)
   throw new ResponseStatusException(HttpStatus.CONFLICT,"Upload completed but status reconciliation failed");
  return new UploadedVideo(id,result.id(),"PRIVATE_REVIEW");
 }
}
