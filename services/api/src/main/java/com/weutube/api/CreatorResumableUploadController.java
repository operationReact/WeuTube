package com.weutube.api;

import jakarta.servlet.http.HttpServletRequest;
import java.io.IOException;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

/**
 * User-scoped, S3-free video upload. The original remains on the client's
 * device; only bounded chunks cross this API on their way to Google.
 * Google upload-session URIs and owner-channel OAuth tokens are NEVER returned.
 */
@RestController
@RequestMapping("/api/creator/uploads")
public class CreatorResumableUploadController {
 private final JdbcTemplate jdbc;
 private final YouTubeResumableRelay google;

 public CreatorResumableUploadController(JdbcTemplate jdbc,
   YouTubeResumableRelay google) {
  this.jdbc=jdbc;this.google=google;
 }

 public record Start(UUID draftId,String channelId,String fileName,long totalBytes) {}
 public record Status(UUID id,UUID draftId,String status,long totalBytes,
   long acknowledgedBytes,int chunkBytes,String youtubeVideoId) {}
 private record Draft(String title,String description,String status) {}
 private record Session(UUID id,UUID draftId,String creatorSub,String channelId,
   String fileName,String mediaType,long total,long acknowledged,
   String uri,String status,String youtubeVideoId) {}

 private static ResponseStatusException conflict(String description) {
  return new ResponseStatusException(HttpStatus.CONFLICT,description);
 }
 private static ResponseStatusException bad(String description) {
  return new ResponseStatusException(HttpStatus.BAD_REQUEST,description);
 }
 private Session session(UUID id,String subject) {
  List<Session> found=jdbc.query("""
    SELECT u.id,u.draft_id,u.creator_sub,u.channel_id,u.file_name,u.file_mime,
      u.total_bytes,u.acknowledged_bytes,u.youtube_session_uri,u.status,u.youtube_video_id
    FROM youtube_resumable_uploads u
    WHERE u.id=? AND u.creator_sub=?
      AND EXISTS (
        SELECT 1 FROM creator_channel_grants g
        JOIN creators c ON c.id=g.creator_id
        JOIN youtube_oauth_credentials oauth ON oauth.youtube_channel_id=g.youtube_channel_id
        WHERE c.cognito_sub=u.creator_sub AND g.youtube_channel_id=u.channel_id
      )
    """,(rs,i)->new Session((UUID)rs.getObject(1),(UUID)rs.getObject(2),
     rs.getString(3),rs.getString(4),rs.getString(5),rs.getString(6),
     rs.getLong(7),rs.getLong(8),rs.getString(9),rs.getString(10),rs.getString(11)),
     id,subject);
  if(found.isEmpty()) throw new ResponseStatusException(HttpStatus.NOT_FOUND,
    "Upload session not found or channel permission revoked");
  return found.get(0);
 }
 private Status publicStatus(Session session) {
  return new Status(session.id(),session.draftId(),session.status(),
    session.total(),session.acknowledged(),
    YouTubeResumableRanges.RELAY_CHUNK_BYTES,session.youtubeVideoId());
 }
 private Status publicStatus(UUID id,String subject) {
  return publicStatus(session(id,subject));
 }

 @PostMapping
 public Status start(@AuthenticationPrincipal Jwt jwt,@RequestBody Start input) {
  if(input==null || input.draftId()==null || input.channelId()==null
      || input.channelId().isBlank() || input.channelId().length()>128)
   throw bad("A draft and authorized YouTube channel are required");
  if(input.fileName()==null || input.fileName().isBlank()
      || input.fileName().length()>255)
   throw bad("Invalid video file name");
  try {YouTubeResumableRanges.validateFileLength(input.totalBytes());}
  catch(IllegalArgumentException ex) {throw bad("Video exceeds YouTube's file-size limit");}
  String mime=YouTubeUploadConstraints.mimeForName(input.fileName());
  if(mime==null) throw bad("YouTube does not support this video container");

  List<Draft> drafts=jdbc.query("""
    SELECT v.title,v.description,v.status FROM video_submissions v
    JOIN creators c ON c.id=v.creator_id
    JOIN creator_channel_grants g ON g.creator_id=c.id
    JOIN youtube_oauth_credentials oauth ON oauth.youtube_channel_id=g.youtube_channel_id
    WHERE v.id=? AND c.cognito_sub=? AND g.youtube_channel_id=?
    """,(rs,i)->new Draft(rs.getString(1),rs.getString(2),rs.getString(3)),
      input.draftId(),jwt.getSubject(),input.channelId());
  if(drafts.isEmpty())
   throw new ResponseStatusException(HttpStatus.NOT_FOUND,
     "Owned draft or connected channel grant not found");
  Draft draft=drafts.get(0);
  String title=YouTubeUploadConstraints.validatedTitle(draft.title());
  String description=YouTubeUploadConstraints.validatedDescription(draft.description());

  // A draft has exactly one active provider upload. Repeated start requests
  // return that session instead of creating duplicate YouTube videos.
  List<UUID> existing=jdbc.query("""
    SELECT id FROM youtube_resumable_uploads WHERE draft_id=? AND creator_sub=?
    """,(rs,i)->(UUID)rs.getObject(1),input.draftId(),jwt.getSubject());
  if(!existing.isEmpty()) {
   Session previous=session(existing.get(0),jwt.getSubject());
   if(!previous.fileName().equals(input.fileName()) ||
     previous.total()!=input.totalBytes() ||
     !previous.channelId().equals(input.channelId()))
    throw conflict("This draft already has a different upload session");
   return publicStatus(previous);
  }
  if(!"DRAFT".equals(draft.status()))
   throw conflict("Only draft videos can start uploading");

  UUID id=UUID.randomUUID();
  int inserted=jdbc.update("""
    INSERT INTO youtube_resumable_uploads
      (id,draft_id,creator_sub,channel_id,file_name,file_mime,total_bytes,status)
    VALUES (?,?,?,?,?,?,?,'INITIATING')
    ON CONFLICT (draft_id) DO NOTHING
    """,id,input.draftId(),jwt.getSubject(),input.channelId(),
      input.fileName(),mime,input.totalBytes());
  if(inserted!=1)
   throw conflict("Another request is already starting this upload");
  int claimed=jdbc.update("""
    UPDATE video_submissions SET status='UPLOADING',updated_at=now()
    WHERE id=? AND status='DRAFT'
    """,input.draftId());
  if(claimed!=1) {
   jdbc.update("DELETE FROM youtube_resumable_uploads WHERE id=? AND status='INITIATING'",id);
   throw conflict("Another upload already claimed this draft");
  }
  try {
   String uri=google.initiate(input.channelId(),title,description,mime,
     input.totalBytes());
   jdbc.update("""
     UPDATE youtube_resumable_uploads
     SET youtube_session_uri=?,status='ACTIVE',updated_at=now()
     WHERE id=? AND status='INITIATING'
     """,uri,id);
   return publicStatus(id,jwt.getSubject());
  } catch(RuntimeException ex) {
   // A failed start cannot expose an arbitrary Google session URL.
   jdbc.update("""
     DELETE FROM youtube_resumable_uploads WHERE id=? AND status='INITIATING'
     """,id);
   jdbc.update("""
     UPDATE video_submissions SET status='DRAFT',updated_at=now()
     WHERE id=? AND status='UPLOADING'
     """,input.draftId());
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
     "Could not start the YouTube upload",ex);
  }
 }

 private void recordProgress(Session s,YouTubeResumableRelay.Progress progress) {
  if(progress.acknowledgedBytes()<s.acknowledged() ||
    progress.acknowledgedBytes()>s.total())
   throw conflict("YouTube returned an inconsistent upload offset");
  if(progress.completed()) {
   if(progress.youtubeVideoId()==null || progress.youtubeVideoId().isBlank())
    throw conflict("YouTube did not confirm a video ID");
   jdbc.update("""
     UPDATE youtube_resumable_uploads
       SET acknowledged_bytes=?,youtube_video_id=?,status='COMPLETED',updated_at=now()
     WHERE id=? AND status IN ('SENDING','RECONCILE')
     """,s.total(),progress.youtubeVideoId(),s.id());
   // Safe to repeat after a crash between the two DB updates.
   jdbc.update("""
     UPDATE video_submissions
     SET status='PRIVATE_REVIEW',youtube_video_id=?,
       youtube_channel_id=(SELECT id FROM youtube_channels
         WHERE youtube_channel_id=?),updated_at=now()
     WHERE id=? AND status='UPLOADING'
     """,progress.youtubeVideoId(),s.channelId(),s.draftId());
  } else {
   jdbc.update("""
     UPDATE youtube_resumable_uploads
       SET acknowledged_bytes=?,status='ACTIVE',updated_at=now()
     WHERE id=? AND status IN ('SENDING','RECONCILE')
     """,progress.acknowledgedBytes(),s.id());
  }
 }

 @GetMapping("/{id}")
 public Status status(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  Session s=session(id,jwt.getSubject());
  if("COMPLETED".equals(s.status())) {
   if(s.youtubeVideoId()!=null) jdbc.update("""
     UPDATE video_submissions SET status='PRIVATE_REVIEW',youtube_video_id=?,
       youtube_channel_id=(SELECT id FROM youtube_channels
         WHERE youtube_channel_id=?),updated_at=now()
     WHERE id=? AND status='UPLOADING'
     """,s.youtubeVideoId(),s.channelId(),s.draftId());
   return publicStatus(s);
  }
  if("SENDING".equals(s.status())) {
   // Do not probe Google while an ongoing upload request may still be active.
   // A stale write claim can safely be reconciled after the server restarts.
   int changed=jdbc.update("""
     UPDATE youtube_resumable_uploads
     SET status='RECONCILE',updated_at=now()
     WHERE id=? AND status='SENDING'
       AND updated_at<now()-interval '3 minutes'
     """,id);
   if(changed==0) return publicStatus(s);
   s=session(id,jwt.getSubject());
  }
  if(!"RECONCILE".equals(s.status())) return publicStatus(s);
  int locked=jdbc.update("""
    UPDATE youtube_resumable_uploads
    SET status='SENDING',updated_at=now()
    WHERE id=? AND status='RECONCILE'
    """,id);
  if(locked!=1) return publicStatus(id,jwt.getSubject());
  try {
   var progress=google.probe(s.channelId(),s.uri(),s.mediaType(),s.total());
   recordProgress(s,progress);
  } catch(RuntimeException ex) {
   jdbc.update("""
     UPDATE youtube_resumable_uploads SET status='RECONCILE',updated_at=now()
     WHERE id=? AND status='SENDING'
     """,id);
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
     "Unable to reconcile upload progress with YouTube",ex);
  }
  return publicStatus(id,jwt.getSubject());
 }

 @PutMapping(value="/{id}/chunk",consumes="application/octet-stream")
 public Status chunk(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id,
   @RequestHeader("Content-Range") String contentRange,
   HttpServletRequest request) throws IOException {
  long contentLength=request.getContentLengthLong();
  if(contentLength<=0 || contentLength>YouTubeResumableRanges.RELAY_CHUNK_BYTES)
   throw bad("Invalid upload chunk size");
  YouTubeResumableRanges.Chunk range;
  try {range=YouTubeResumableRanges.parseChunk(contentRange,contentLength);}
  catch(IllegalArgumentException ex) {throw bad("Invalid or nonsequential video byte range");}
  Session s=session(id,jwt.getSubject());
  if(range.total()!=s.total()) throw bad("Chunk does not match original video length");
  if(!"ACTIVE".equals(s.status()))
   throw conflict("Upload is not ready; check session progress before retrying");
  try {YouTubeResumableRanges.requireNextChunk(range,s.acknowledged());}
  catch(IllegalArgumentException ex) {throw conflict("Chunk is not at YouTube-confirmed offset");}
  int locked=jdbc.update("""
    UPDATE youtube_resumable_uploads SET status='SENDING',updated_at=now()
    WHERE id=? AND status='ACTIVE' AND acknowledged_bytes=?
    """,id,s.acknowledged());
  if(locked!=1) throw conflict("Upload already sending; check status");
  try {
   // The buffer cannot exceed 8 MiB; there is no multipart tempfile or S3.
   byte[] data=request.getInputStream().readNBytes((int)contentLength+1);
   if(data.length!=contentLength)
    throw bad("Upload chunk body does not match Content-Range");
   var progress=google.send(s.channelId(),s.uri(),s.mediaType(),range,data);
   recordProgress(s,progress);
   return publicStatus(id,jwt.getSubject());
  } catch(RuntimeException|IOException ex) {
   // A timeout might have reached YouTube. Never assume zero bytes arrived;
   // the next status request MUST probe Google before another chunk.
   jdbc.update("""
     UPDATE youtube_resumable_uploads SET status='RECONCILE',updated_at=now()
     WHERE id=? AND status='SENDING'
     """,id);
   if(ex instanceof ResponseStatusException status) throw status;
   throw new ResponseStatusException(HttpStatus.BAD_GATEWAY,
     "Chunk outcome uncertain. Query status before resuming.",ex);
  }
 }

 @DeleteMapping("/{id}")
 public Status cancel(@AuthenticationPrincipal Jwt jwt,@PathVariable UUID id) {
  Session s=session(id,jwt.getSubject());
  if("SENDING".equals(s.status()))
   throw conflict("Cannot cancel while a chunk is in flight");
  if(!"COMPLETED".equals(s.status())) jdbc.update("""
    UPDATE youtube_resumable_uploads SET status='CANCELLED',updated_at=now()
    WHERE id=? AND status IN ('ACTIVE','RECONCILE','INITIATING')
    """,id);
  return publicStatus(id,jwt.getSubject());
 }
}
