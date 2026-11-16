import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:weutube/youtube_embed.dart';

void main() {
  group('Strict published YouTube video ID parsing', () {
    test('accepts official watch, shorts, embed, live, and short URLs', () {
      expect(youtubeVideoIdFromUrl(
          'https://www.youtube.com/watch?v=M7lc1UVf-VE'), 'M7lc1UVf-VE');
      expect(youtubeVideoIdFromUrl(
          'https://m.youtube.com/shorts/M7lc1UVf-VE'), 'M7lc1UVf-VE');
      expect(youtubeVideoIdFromUrl(
          'https://youtube.com/embed/M7lc1UVf-VE'), 'M7lc1UVf-VE');
      expect(youtubeVideoIdFromUrl(
          'https://youtube.com/live/M7lc1UVf-VE'), 'M7lc1UVf-VE');
      expect(youtubeVideoIdFromUrl(
          'https://youtu.be/M7lc1UVf-VE?t=10'), 'M7lc1UVf-VE');
    });
    test('rejects impostor domains, HTTP, credentials, and malformed IDs', () {
      expect(youtubeVideoIdFromUrl(
          'https://www.youtube.com.evil.test/watch?v=M7lc1UVf-VE'), isNull);
      expect(youtubeVideoIdFromUrl(
          'http://youtube.com/watch?v=M7lc1UVf-VE'), isNull);
      expect(youtubeVideoIdFromUrl(
          'https://user@youtube.com/watch?v=M7lc1UVf-VE'), isNull);
      expect(youtubeVideoIdFromUrl(
          'https://youtube.com:8443/watch?v=M7lc1UVf-VE'), isNull);
      expect(youtubeVideoIdFromUrl(
          'https://youtube.com/watch?v=not-valid'), isNull);
      expect(youtubeVideoIdFromUrl(''), isNull);
    });
  });

  testWidgets('offscreen video shows poster without mounting an iframe',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      SizedBox(width: 360, height: 204,
        child: WeuTubeYoutubeStage(
          videoId: 'M7lc1UVf-VE',
          thumbnailUrl: '',
          active: false)))));
    expect(find.byType(YoutubePlayer), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsWidgets);
  });
}
