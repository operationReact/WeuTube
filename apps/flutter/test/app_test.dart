import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weutube/main.dart';
import 'package:weutube/immersive_sign_in.dart';
import 'package:weutube/upload_composer.dart';
import 'package:weutube/backend_client.dart';
import 'package:weutube/product_ui.dart' show WeuTubeBrand;

void main() {
  testWidgets('opens social Home directly with a populated feed', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    expect(find.byType(WeuTubeBrand), findsOneWidget);
    expect(find.text('Discover creators'), findsOneWidget);
    expect(find.byTooltip('Search creators and videos'), findsOneWidget);
    expect(find.text('Your video'), findsNothing);
    expect(find.text('Latest'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Shorts'), findsWidgets);
    expect(find.text('Create'), findsWidgets);
  });

  testWidgets('Explore has discovery without forcing login', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Explore').first);
    await tester.pump();
    expect(find.text('Discover videos and creators.'), findsOneWidget);
    expect(find.text('Search videos, creators or topics'), findsOneWidget);
    expect(find.byTooltip('Search creators and videos'), findsNothing);
  });

  testWidgets('Sign-in is available when a person wants to create', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create').last);
    await tester.pump();
    expect(find.text('Create video'), findsOneWidget);
    await tester.ensureVisible(find.text('Sign in to upload'));
    await tester.pump();
    await tester.tap(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    await tester.ensureVisible(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    expect(find.text('Full Name'), findsOneWidget);
  });
  testWidgets('Latest tab selects recent-first feed without duplicate search',
      (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Latest').first);
    await tester.pump();
    expect(find.text('Latest'), findsOneWidget);
    expect(find.byTooltip('Search creators and videos'), findsOneWidget);
  });

  testWidgets('Shorts has a dedicated immersive layout', (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Shorts').last);
    await tester.pump();
    expect(find.byType(WeuTubeBrand), findsNothing);
    expect(find.text('Shorts'), findsWidgets);
  });

  testWidgets('mobile auth uses one brand and compact accessible fields',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create').last);
    await tester.pump();
    await tester.ensureVisible(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    expect(find.byType(WeuTubeBrand), findsOneWidget);
    expect(find.byTooltip('Sign in'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    await tester.ensureVisible(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    expect(find.byType(WeuTubeBrand), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(4));
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Use at least 12 characters for your password.'),
      findsOneWidget);
  });

  testWidgets('Premium sign-in renders animated original brand and Google-first CTA',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create').last);
    await tester.pump();
    await tester.ensureVisible(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    expect(find.byType(ImmersiveBrandHero), findsOneWidget);
    expect(find.byType(WeuTubeBrand), findsOneWidget);
    expect(find.text('Your stories. Our community.'), findsOneWidget);
    expect(find.byKey(const ValueKey('google-sign-in-button')), findsOneWidget);
    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Immersive sign-in fits responsive hero and keeps Google secondary',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create').last);
    await tester.pump();
    await tester.ensureVisible(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    final hero = find.byKey(const ValueKey('immersive-brand-hero'));
    expect(hero, findsOneWidget);
    expect(tester.getSize(hero).height, 202);
    expect(find.byType(WeuTubeBrand), findsOneWidget);
    final google = find.byKey(const ValueKey('google-sign-in-button'));
    expect(google, findsOneWidget);
    expect(find.ancestor(of: google, matching: find.byType(OutlinedButton)),
      findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Immersive hero stops motion when user prefers reduced animation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: ImmersiveBrandHero(compact: true),
      )),
    ));
    expect(find.byType(WeuTubeBrand), findsOneWidget);
    expect(find.byKey(const ValueKey('immersive-brand-hero')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('immersive-brand-hero')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact 320dp sign-in remains scrollable without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create').last);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: 'Before opening sign-in');
    await tester.ensureVisible(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Create route at 320dp');
    await tester.tap(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Initial sign-in at 320dp');
    await tester.ensureVisible(find.text('Sign In').last);
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsWidgets);
    expect(tester.takeException(), isNull, reason: 'After scrolling sign-in form');
  });

  testWidgets('signup rejects mismatched passwords without API call',
      (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create').last);
    await tester.pump();
    await tester.ensureVisible(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in to upload'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to WeuTube? Create Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('auth-full-name')),
      'Example Person');
    await tester.enterText(find.byKey(const ValueKey('auth-email-address')),
      'sample@example.com');
    await tester.enterText(find.byKey(const ValueKey('auth-password')),
      'long-example-password-123');
    await tester.enterText(find.byKey(const ValueKey('auth-confirm-password')),
      'long-example-password-456');
    final submit = find.widgetWithText(FilledButton, 'Create Account');
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('You tab is a concise account page without demo statistics',
      (tester) async {
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('You').last);
    await tester.pump();
    expect(find.text('Welcome to WeuTube'), findsOneWidget);
    expect(find.text('Your collection'), findsOneWidget);
    expect(find.text('Saved videos'), findsOneWidget);
    expect(find.text('Sign In / Create Account'), findsOneWidget);
    expect(find.text('Creator tools'), findsNothing);
    expect(find.text('Guest'), findsNothing);
  });

  testWidgets('Explore search and empty-state remain useful at 320dp',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const WeuTubeApp());
    expect(tester.takeException(), isNull,
      reason: 'Home must not overflow before navigating to Explore');
    await tester.tap(find.text('Explore').last);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField).first, '___no_matching_video___');
    await tester.pump();
    expect(find.text('No matches found'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Create is the actual upload entry with the correct selected tab',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const WeuTubeApp());
    await tester.tap(find.text('Create').last);
    await tester.pumpAndSettle();
    expect(find.text('Create video'), findsOneWidget);
    expect(find.text('Open Upload Studio'), findsNothing);
    expect(find.text('How publishing works'), findsNothing);
    expect(find.text('Sign in to upload'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('No channel grant blocks upload before any form fields appear',
      (tester) async {
    final api = _ComposerFakeApi([]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      WeuTubeUploadComposer(api: api, onSignIn: () {}, onViewVideos: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Upload access unavailable'), findsOneWidget);
    expect(find.text('Refresh channel status'), findsOneWidget);
    expect(find.text('App revision: unversioned'), findsOneWidget);
    expect(find.byKey(const ValueKey('upload-video-title')), findsNothing);
    expect(find.text('Upload privately for review'), findsNothing);
    api.dispose();
  });

  testWidgets('Eligible new creator gets an upload form after private-channel activation',
      (tester) async {
    final api = _ComposerFakeApi([], autoActivate: true);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      WeuTubeUploadComposer(api: api, onSignIn: () {}, onViewVideos: () {}))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('upload-video-title')), findsOneWidget);
    expect(find.text('Authorized YouTube channel'), findsOneWidget);
    expect(find.text('Channel permission needed'), findsNothing);
    api.dispose();
  });

  testWidgets('READY session with no listed channel retries secure activation',
      (tester) async {
    final api = _ComposerFakeApi([], autoActivate: true, readyButEmpty: true);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      WeuTubeUploadComposer(api: api, onSignIn: () {}, onViewVideos: () {}))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('upload-video-title')), findsOneWidget);
    expect(find.text('Authorized YouTube channel'), findsOneWidget);
    api.dispose();
  });

  testWidgets('Disconnected channel is distinct from a missing grant',
      (tester) async {
    final api = _ComposerFakeApi([], disconnected: true);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      WeuTubeUploadComposer(api: api, onSignIn: () {}, onViewVideos: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('YouTube channel setup pending'), findsOneWidget);
    expect(find.textContaining('platform YouTube channel'), findsOneWidget);
    expect(find.byKey(const ValueKey('upload-video-title')), findsNothing);
    api.dispose();
  });

  testWidgets('Forbidden channel lookup never reveals a runnable upload form',
      (tester) async {
    final api = _ComposerFakeApi([], denied: true);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      WeuTubeUploadComposer(api: api, onSignIn: () {}, onViewVideos: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in verification failed'), findsOneWidget);
    expect(find.text('Sign in again'), findsOneWidget);
    expect(find.textContaining('rejected by the API'), findsOneWidget);
    expect(find.byKey(const ValueKey('upload-video-title')), findsNothing);
    api.dispose();
  });

  testWidgets('Channel API 403 is distinguished from valid Cognito login',
      (tester) async {
    final api=_ComposerFakeApi([
      {'channelId':'UC_Example_123','displayName':'Authorized channel'},
    ], channelDenied:true);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      WeuTubeUploadComposer(api:api,onSignIn:(){},onViewVideos:(){}))));
    await tester.pumpAndSettle();
    expect(find.text('Sign-in verification failed'),findsOneWidget);
    expect(find.textContaining('Your sign-in is valid'),findsOneWidget);
    expect(find.byKey(const ValueKey('upload-video-title')),findsNothing);
    api.dispose();
  });

  testWidgets('Authorized channel shows a compact upload composer',
      (tester) async {
    final api = _ComposerFakeApi([
      {'channelId':'UC_Example_123','displayName':'Authorized channel'},
    ]);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      WeuTubeUploadComposer(api: api, onSignIn: () {}, onViewVideos: () {}))));
    await tester.pumpAndSettle();
    expect(find.text('Choose a video'), findsOneWidget);
    expect(find.byKey(const ValueKey('upload-video-title')), findsOneWidget);
    expect(find.text('Upload privately for review'), findsOneWidget);
    expect(find.text('Authorized YouTube channel'), findsOneWidget);
    expect(tester.takeException(), isNull);
    api.dispose();
  });

}

class _ComposerFakeApi extends WeuTubeApi {
  _ComposerFakeApi(this.channels, {this.denied = false,
      this.channelDenied = false, this.disconnected = false,
      this.autoActivate = false, this.readyButEmpty = false}) {
    accessToken = 'test-token';
  }
  final List<Map<String,dynamic>> channels;
  final bool denied;
  final bool channelDenied;
  final bool disconnected;
  final bool autoActivate;
  final bool readyButEmpty;
  @override
  Future<Map<String,dynamic>> activateCreatorChannel() async {
    if (!autoActivate) throw ApiFailure(
      disconnected ? 'No connected channel' : 'Creator access not enabled',
      disconnected ? 503 : 403);
    channels.add({'channelId':'UC_Example_123','displayName':'WeuTube upload channel'});
    return channels.first;
  }
  @override
  Future<Map<String,dynamic>> creatorSession() async {
    if (denied) throw const ApiFailure('Access denied.',403);
    return {
      'authenticated': true,
      'uploadAccess': disconnected ? 'CHANNEL_NOT_CONNECTED' :
        readyButEmpty ? 'READY' :
        channels.isEmpty ? 'NO_CHANNEL_GRANT' : 'READY',
      'channelGranted': disconnected || channels.isNotEmpty,
      'channelConnected': !disconnected && channels.isNotEmpty,
    };
  }
  @override
  Future<List<Map<String,dynamic>>> grantedChannels() async {
    if (denied || channelDenied) throw const ApiFailure('Access denied.',403);
    return channels;
  }
}
