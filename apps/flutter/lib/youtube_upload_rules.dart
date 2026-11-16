import 'dart:convert';

/// YouTube is authoritative about accepted file size, duration and formats.
/// Create uses the resumable YouTube-native API. The smaller directGateway
/// constant is retained solely for older clients using the deprecated
/// synchronous multipart endpoint; it is not the current Create video limit.
class YouTubeUploadRules {
  static const youtubeMaxBytes = 256 * 1024 * 1024 * 1024;
  static const youtubeMaxDurationSeconds = 12 * 60 * 60;
  static const unverifiedChannelMaxDurationSeconds = 15 * 60;
  static const titleMaxChars = 100;
  static const descriptionMaxUtf8Bytes = 5000;
  static const directGatewayMaxBytes = 256 * 1024 * 1024;

  static const _mime = <String,String>{
    'mp4':'video/mp4',
    'm4v':'video/mp4',
    'mov':'video/quicktime',
    'avi':'video/x-msvideo',
    'wmv':'video/x-ms-wmv',
    'webm':'video/webm',
    'flv':'video/x-flv',
    '3gp':'video/3gpp',
    '3gpp':'video/3gpp',
    'mpg':'video/mpeg',
    'mpeg':'video/mpeg',
    'm2v':'video/mpeg',
    'm2p':'video/mpeg',
    'mpg2':'video/mpeg',
    'mpeg2':'video/mpeg',
    'vob':'video/mpeg',
    'mts':'video/mp2t',
    'm2ts':'video/mp2t',
  };

  static String? mimeForFilename(String filename) {
    final name = filename.toLowerCase().trim();
    final dot = name.lastIndexOf('.');
    if(dot < 0 || dot == name.length - 1) return null;
    return _mime[name.substring(dot + 1)];
  }

  static String? titleError(String raw) {
    final title = raw.trim();
    if(title.isEmpty) return 'Enter a video title';
    if(title.runes.length > titleMaxChars) return 'Use 100 characters or fewer';
    if(title.contains('<') || title.contains('>')) {
      return 'Angle brackets are not supported by YouTube';
    }
    return null;
  }

  static String? descriptionError(String raw) {
    if(raw.contains('<') || raw.contains('>')) {
      return 'Angle brackets are not supported by YouTube';
    }
    if(utf8.encode(raw.trim()).length > descriptionMaxUtf8Bytes) {
      return 'YouTube descriptions must be 5000 UTF-8 bytes or fewer';
    }
    return null;
  }
}
