import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/youtube_upload_rules.dart';

void main() {
  test('YouTube formats include common and legacy video containers', () {
    for (final filename in [
      'clip.mp4', 'clip.MOV', 'clip.AVI', 'clip.webm', 'clip.wmv',
      'clip.flv', 'clip.3gp', 'clip.mpg', 'clip.vob'
    ]) {
      expect(YouTubeUploadRules.mimeForFilename(filename), isNotNull);
    }
    expect(YouTubeUploadRules.mimeForFilename('clip.mp3'), isNull);
    expect(YouTubeUploadRules.mimeForFilename('clip.exe'), isNull);
  });

  test('YouTube title max is 100 Unicode characters without angle brackets', () {
    expect(YouTubeUploadRules.titleError('Some title'), isNull);
    expect(YouTubeUploadRules.titleError(List.filled(100, '😀').join()), isNull);
    expect(YouTubeUploadRules.titleError(List.filled(101, 'x').join()), isNotNull);
    expect(YouTubeUploadRules.titleError('hello <world>'), isNotNull);
  });

  test('YouTube description max is UTF-8 bytes, not glyph count', () {
    expect(YouTubeUploadRules.descriptionError(List.filled(5000, 'a').join()), isNull);
    expect(YouTubeUploadRules.descriptionError(List.filled(1250, '😀').join()), isNull);
    expect(YouTubeUploadRules.descriptionError(List.filled(1251, '😀').join()), isNotNull);
    expect(YouTubeUploadRules.descriptionError('a>b'), isNotNull);
  });

  test('direct gateway capacity must not be misrepresented as YouTube cap', () {
    expect(YouTubeUploadRules.youtubeMaxBytes, greaterThan(
      YouTubeUploadRules.directGatewayMaxBytes));
    expect(YouTubeUploadRules.youtubeMaxDurationSeconds, 12*3600);
  });
}
