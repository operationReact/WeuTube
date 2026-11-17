import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import 'backend_client.dart';
import 'social_design_widgets.dart';
import 'youtube_embed.dart';
import 'product_ui.dart' show navy, coral, soft, slate;

/// A filled, mobile-first social experience. Public demo content is explicitly
/// labelled and cannot create real platform activity or earnings.
class SocialHub extends StatefulWidget {
  final WeuTubeApi api;
  final String section;
  final ValueChanged<String> onNavigate;
  final VoidCallback onSignIn;
  final VoidCallback onCreate;
  final VoidCallback onStudio;
  const SocialHub({
    super.key,
    required this.api,
    required this.section,
    required this.onNavigate,
    required this.onSignIn,
    required this.onCreate,
    required this.onStudio,
  });

  @override
  State<SocialHub> createState() => _SocialHubState();
}

class _SocialHubState extends State<SocialHub> {
  final Set<String> liked = {}, saved = {}, following = {};
  final Map<String, List<String>> draftComments = {};
  final search = TextEditingController();
  final PageController shortsPager = PageController();
  final PageController homePager = PageController();
  List<Map<String, dynamic>> items = [];
  bool loading = false;
  String category = 'All';
  String feedChoice = 'For you';
  String? loadError;
  String channelSyncStatus = 'PENDING';
  int importedVideoCount = 0;
  int connectedChannelCount = 0;
  int shortIndex = 0;
  int homeIndex = 0;
  bool showQuickHeart = false;
  bool playerSheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  @override
  void didUpdateWidget(covariant SocialHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section &&
        (oldWidget.section == 'Shorts' || widget.section == 'Shorts')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refresh();
      });
    }
  }

  @override
  void dispose() {
    shortsPager.dispose();
    homePager.dispose();
    search.dispose();
    super.dispose();
  }

  bool isDemo(Map<String, dynamic> item) => item['demo'] == true;
  bool isImported(Map<String, dynamic> item) => str(item['id']).startsWith('yt-');
  String str(dynamic value) => value?.toString() ?? '';
  String id(Map<String, dynamic> item) => str(item['id']);
  String image(Map<String, dynamic> item) => str(item['thumbnailUrl']);
  String avatar(Map<String, dynamic> item) => str(item['avatarUrl']);
  String followKey(Map<String,dynamic> item) =>
    str(item['creatorId']).isEmpty ? str(item['creator']) : str(item['creatorId']);
  void doubleTapLike(Map<String,dynamic> item) {
    if(isImported(item)) {
      openOnYouTube(item);
      return;
    }
    if(!liked.contains(id(item)))like(item);
    setState(()=>showQuickHeart=true);
    Future<void>.delayed(const Duration(milliseconds:550),(){
      if(mounted)setState(()=>showQuickHeart=false);
    });
  }
  String compact(dynamic raw) {
    final num? value = raw is num ? raw : num.tryParse(str(raw));
    if(value == null) return '—';
    if(value >= 1000000) return (value / 1000000).toStringAsFixed(1) + 'M';
    if(value >= 1000) return (value / 1000).toStringAsFixed(1) + 'K';
    return value.toStringAsFixed(0);
  }

  Future<void> refresh() async {
    if(loading) return;
    setState(() {loading = true;loadError = null;});
    try {
      final result = await widget.api.publicFeed(
        shorts: widget.section == 'Shorts');
      final received = (result['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((post) => post['demo'] != true).toList();
      if(!mounted) return;
      setState(() {
        items = received;
        channelSyncStatus = str(result['channelSyncStatus']);
        importedVideoCount = (result['importedVideos'] as num?)?.toInt() ?? 0;
        connectedChannelCount = (result['connectedChannels'] as num?)?.toInt() ?? 0;
        shortIndex = 0;
        homeIndex = 0;
      });
      if(widget.api.signedIn) {
        try {
          final state = await widget.api.socialState();
          if(!mounted) return;
          setState(() {
            liked.addAll((state['likedVideoIds'] as List<dynamic>? ?? []).map(str));
            saved.addAll((state['savedVideoIds'] as List<dynamic>? ?? []).map(str));
            following.addAll((state['followingCreatorIds'] as List<dynamic>? ?? []).map(str));
          });
        } catch (_) {
          // A user's reaction-state request must never hide already loaded
          // public YouTube videos or falsely trigger demo-mode fallback.
          if(mounted) setState(() =>
            loadError = 'Personal reactions unavailable; videos are still live.');
        }
      }
    } catch(_) {
      if(mounted) setState(() {
        loadError = 'Real video feed is temporarily unavailable. Retry to refresh.';
        items = [];
      });
    } finally {
      if(mounted) setState(() => loading = false);
    }
  }

  void inform(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message),
      behavior: SnackBarBehavior.floating));
  }

  Future<void> like(Map<String, dynamic> item) async {
    if(isImported(item)) {await openOnYouTube(item);return;}
    final key = id(item), already = liked.contains(key);
    if(!isDemo(item) && !widget.api.signedIn) {widget.onSignIn();return;}
    setState(() => already ? liked.remove(key) : liked.add(key));
    if(isDemo(item)) {inform('Demo reaction — not added to real statistics');return;}
    try {
      await widget.api.reactVideo(key, 'like', !already);
    } catch(e) {
      if(mounted) setState(() => already ? liked.add(key) : liked.remove(key));
      inform('Unable to update this reaction.');
    }
  }

  Future<void> save(Map<String, dynamic> item) async {
    if(isImported(item)) {await openOnYouTube(item);return;}
    final key = id(item), already = saved.contains(key);
    if(!isDemo(item) && !widget.api.signedIn) {widget.onSignIn();return;}
    setState(() => already ? saved.remove(key) : saved.add(key));
    if(isDemo(item)) {inform('Saved for this preview session');return;}
    try {await widget.api.reactVideo(key, 'save', !already);}
    catch(_) {
      if(mounted) setState(() => already ? saved.add(key) : saved.remove(key));
      inform('Unable to update saved videos.');
    }
  }

  Future<void> follow(Map<String, dynamic> item) async {
    if(isImported(item)) {
      final channel=str(item['creatorId']);
      if(RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(channel)) {
        await launchUrl(Uri.parse('https://www.youtube.com/channel/$channel'),
          mode:LaunchMode.externalApplication);
      }
      return;
    }
    final key = str(item['creatorId']).isNotEmpty ?
      str(item['creatorId']) : str(item['creator']);
    final already = following.contains(key);
    if(!isDemo(item) && !widget.api.signedIn) {widget.onSignIn();return;}
    setState(() => already ? following.remove(key) : following.add(key));
    if(isDemo(item)) {inform('Demo follow — preview only');return;}
    try {await widget.api.followCreator(key, !already);}
    catch(_) {
      if(mounted) setState(() => already ? following.add(key) : following.remove(key));
      inform('Unable to update following.');
    }
  }

  void openComments(Map<String,dynamic> item) {
    if(isImported(item)) {openOnYouTube(item);return;}
    final input = TextEditingController();
    final postId = id(item);
    final demoMode = isDemo(item);
    showModalBottomSheet<void>(context: context, isScrollControlled: true,
      useSafeArea: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) {
        return StatefulBuilder(builder: (context, localSet) {
          return Padding(padding: EdgeInsets.fromLTRB(20, 20, 20,
            16 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 35,height:4,decoration:BoxDecoration(
                color:const Color(0xFFDDE1EA),borderRadius:BorderRadius.circular(10))),
              const SizedBox(height:17),
              Row(children: [
                const Text('Conversation', style: TextStyle(
                  color:navy,fontSize:21,fontWeight:FontWeight.w900)),
                const Spacer(),
                if(demoMode) pill('DEMO',coral)
              ]),
              const SizedBox(height:14),
              ConstrainedBox(constraints:const BoxConstraints(maxHeight:300),
                child: SingleChildScrollView(child: Column(children:[
                  if(demoMode) ...[
                    const ListTile(leading:CircleAvatar(child:Icon(Icons.person_outline)),
                      title:Text('WeuTube Preview',style:TextStyle(fontWeight:FontWeight.w700)),
                      subtitle:Text('Love seeing creative stories here! This is a sample conversation.')),
                    for(final entry in draftComments[postId] ?? [])
                      ListTile(leading:const CircleAvatar(child:Icon(Icons.person_outline)),
                        title:const Text('You · Preview'),subtitle:Text(entry)),
                  ] else
                    FutureBuilder<List<Map<String,dynamic>>>(
                      future:widget.api.comments(postId),
                      builder:(context,snapshot) {
                        if(snapshot.connectionState != ConnectionState.done) {
                          return const Padding(padding:EdgeInsets.all(18),
                            child:CircularProgressIndicator());
                        }
                        if(snapshot.hasError) return const Text('Comments unavailable.');
                        final list=snapshot.data ?? [];
                        if(list.isEmpty) return const Text('Start the conversation.');
                        return Column(children: [
                          for(final c in list)
                            ListTile(leading:const CircleAvatar(
                              child:Icon(Icons.person_outline)),
                              title:Text(str(c['creator'])),
                              subtitle:Text(str(c['content'])))
                        ]);
                      })
                ]))),
              const SizedBox(height:12),
              Row(children:[
                Expanded(child:TextField(controller:input,maxLength:400,
                  decoration:InputDecoration(hintText:'Write a thoughtful comment...',
                    counterText:'',filled:true,fillColor:soft,
                    border:OutlineInputBorder(borderRadius:BorderRadius.circular(13))))),
                const SizedBox(width:8),
                IconButton.filled(style:IconButton.styleFrom(backgroundColor:coral),
                  onPressed:() async {
                    final value=input.text.trim();
                    if(value.isEmpty) return;
                    if(!demoMode && !widget.api.signedIn) {
                      Navigator.pop(sheetContext);
                      widget.onSignIn();return;
                    }
                    if(demoMode) {
                      setState(()=>draftComments.putIfAbsent(postId,()=>[]).add(value));
                      input.clear();localSet((){});
                    } else {
                      try {
                        await widget.api.postComment(postId,value);
                        if(sheetContext.mounted) Navigator.pop(sheetContext);
                        inform('Comment posted.');
                      } catch(_) {inform('Comment could not be posted.');}
                    }
                  },icon:const Icon(Icons.send_rounded))
              ])
            ]));
        });
      }).whenComplete(input.dispose);
  }

  Future<void> openOnYouTube(Map<String,dynamic> item) async {
    final raw = str(item['youtubeUrl']);
    if (youtubeVideoIdFromUrl(raw) == null) {
      inform('This video has no verified YouTube link.');
      return;
    }
    if (!await launchUrl(Uri.parse(raw), mode: LaunchMode.externalApplication)) {
      inform('Could not open YouTube on this device.');
    }
  }

  Future<void> play(Map<String,dynamic> item) async {
    if (isDemo(item)) {
      final url = str(item['videoUrl']);
      if (url.isEmpty) { inform('Sample clip unavailable.'); return; }
      await showModalBottomSheet<void>(
        context: context, isScrollControlled: true,
        backgroundColor: const Color(0xFF08132E), useSafeArea: true,
        builder: (_) => DemoVideoPlayer(url: url, title: str(item['title'])));
      return;
    }
    final videoId = youtubeVideoIdFromUrl(str(item['youtubeUrl']));
    if (videoId == null) {
      inform('This video does not have a verified playback link.');
      return;
    }
    // Suppress the feed player before mounting the modal's player. There
    // must never be two simultaneous embedded YouTube autoplay sessions.
    setState(() => playerSheetOpen = true);
    try {
      await showModalBottomSheet<void>(context: context,
        isScrollControlled: true, useSafeArea: true,
        backgroundColor: const Color(0xFF0A1631),
        builder: (sheetContext) => SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 15, 14, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text(str(item['title']), maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 16))),
              IconButton(onPressed: () => Navigator.pop(sheetContext),
                icon: const Icon(Icons.close_rounded, color: Colors.white)),
            ]),
            const SizedBox(height: 12),
            SizedBox(height: math.max(200.0,
                (MediaQuery.sizeOf(sheetContext).width - 28) * 9 / 16),
              child: WeuTubeYoutubeStage(
                videoId: videoId, thumbnailUrl: image(item), active: true)),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => openOnYouTube(item),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open on YouTube')),
          ]))));
    } finally {
      if (mounted) setState(() => playerSheetOpen = false);
    }
  }

  Widget pill(String text,Color color) => Container(
    padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
    decoration:BoxDecoration(color:color.withValues(alpha:.09),
      borderRadius:BorderRadius.circular(100)),
    child:Text(text,style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,
      letterSpacing:.5,color:color)));
  Widget card(Widget child,{EdgeInsets pad=const EdgeInsets.all(14)}) =>
    Container(padding:pad,decoration:BoxDecoration(
      color:Colors.white,borderRadius:BorderRadius.circular(21),
      border:Border.all(color:const Color(0xFFEDF0F6))),
      child:child);
  Widget actionIcon(IconData icon,String label,VoidCallback tap,
      {bool active=false}) =>
    InkWell(onTap:tap,borderRadius:BorderRadius.circular(20),
      child:Padding(padding:const EdgeInsets.symmetric(vertical:9,horizontal:7),
        child:Row(mainAxisSize:MainAxisSize.min,children:[
          Icon(icon,color:active?coral:slate,size:21),
          if(label.isNotEmpty) ...[const SizedBox(width:5),
            Text(label,style:TextStyle(color:active?coral:slate,
              fontWeight:FontWeight.w600,fontSize:12))]
        ])));


  /// Published videos keep the same immersive navy card, but WeuTube
  /// overlays and social actions are completely OUTSIDE the YouTube iframe.
  /// YouTube branding, ads and controls must remain visible and tappable.
  Widget publishedImmersivePost(Map<String,dynamic> item, int index,
      {bool shorts = false}) {
    final key = id(item);
    final ytId = youtubeVideoIdFromUrl(str(item['youtubeUrl']));
    final playing = !playerSheetOpen &&
        (shorts ? (widget.section == 'Shorts' && index == shortIndex)
                : (widget.section == 'Home' && index == homeIndex));
    final followed = following.contains(followKey(item));
    final isLiked = liked.contains(key);
    final isSaved = saved.contains(key);

    Widget action(IconData icon, String label, VoidCallback callback,
        {bool selected = false}) => Expanded(child: InkWell(
      onTap: callback,
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 22, color: selected ? coral : Colors.white),
          const SizedBox(height: 4),
          Text(label, overflow: TextOverflow.ellipsis, maxLines: 1,
            style: const TextStyle(color: Colors.white70,
              fontSize: 10, fontWeight: FontWeight.w700))
        ]))));

    final footer = Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 8),
      child: Column(mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CreatorPortrait(name: str(item['creator']),
            imageUrl: avatar(item), radius: 17, highlighted: false),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(str(item['creator']), maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w800, fontSize: 13)),
              Text(str(item['handle']), maxLines: 1,
                style: const TextStyle(color: Colors.white60, fontSize: 10))
            ])),
          Text(isImported(item) ? 'YOUTUBE' : 'PUBLISHED',
            style: const TextStyle(color: Colors.white70,
              fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 8),
        Text(str(item['title']), maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 18,
            fontWeight: FontWeight.w900, height: 1.13)),
        if (str(item['description']).trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(str(item['description']), maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11))
        ],
        const SizedBox(height: 6),
        Row(children: [
          action(followed ? Icons.person_rounded : Icons.person_add_alt_1_rounded,
            followed ? 'Following' : 'Follow', () => follow(item),
            selected: followed),
          action(isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            'Like', () => like(item), selected: isLiked),
          action(Icons.mode_comment_outlined, 'Comments',
            () => openComments(item)),
          action(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            'Save', () => save(item), selected: isSaved),
          action(Icons.share_rounded, 'Share', () => share(item))
        ]),
        Row(children: [
          const Icon(Icons.play_circle_outline_rounded,
            size: 14, color: Colors.white70),
          const SizedBox(width: 5),
          const Expanded(child: Text('Video hosted by YouTube',
            style: TextStyle(color: Colors.white60, fontSize: 10))),
          TextButton(
            onPressed: () => openOnYouTube(item),
            child: const Text('Open on YouTube',
              style: TextStyle(color: Colors.white, fontSize: 11)))
        ]),
      ]),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 3, 9, 6),
      // A dark rounded card remains; do not clip the YouTube iframe's corners.
      // Even minor masks on the official player are prohibited.
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0A1631),
          borderRadius: BorderRadius.circular(22)),
        child: LayoutBuilder(builder: (context, bounds) {
            final videoHeight = math.max(200.0,
                math.min(350.0, bounds.maxWidth * 9 / 16));
            final enoughRoom = bounds.maxHeight >= videoHeight + 235;
            return Column(children: [
              SizedBox(width: double.infinity, height: videoHeight,
                child: ytId == null
                  ? Center(child: TextButton.icon(
                      onPressed: () => openOnYouTube(item),
                      icon: const Icon(Icons.error_outline_rounded),
                      label: const Text('YouTube video unavailable')))
                  : WeuTubeYoutubeStage(
                      key: ValueKey('yt-${shorts ? 'shorts' : 'home'}-$key'),
                      videoId: ytId,
                      thumbnailUrl: image(item),
                      active: playing)),
              Expanded(child: enoughRoom
                ? Align(alignment: Alignment.bottomCenter, child: footer)
                : SingleChildScrollView(child: footer))
            ]);
          })));
  }

  /// Video-first, full-height card: content takes the screen instead of
  /// being buried under repetitive white Flutter dashboard containers.
  Widget immersivePost(Map<String,dynamic> item,int index) {
    if (!isDemo(item)) return publishedImmersivePost(item, index);
    final key=id(item),followed=following.contains(followKey(item));
    return Padding(padding:const EdgeInsets.fromLTRB(9,3,9,6),
      child:ClipRRect(borderRadius:BorderRadius.circular(22),
        child:Stack(fit:StackFit.expand,children:[
          SocialMediaStage(
            key:ValueKey('home-media-$key'),
            thumbnailUrl:image(item),
            previewUrl:isDemo(item)?str(item['videoUrl']):null,
            active:!playerSheetOpen&&widget.section=='Home'&&index==homeIndex,
            immersive:true,
            onTap:()=>play(item),
            onDoubleTap:()=>doubleTapLike(item)),
          Positioned(top:15,left:15,right:15,child:Row(children:[
            if(isDemo(item))
              Tooltip(message:'Demo sample content, not a real creator upload',
                child:pill('DEMO',Colors.white))
            else
              pill('PUBLISHED',Colors.white),
            const Spacer(),
            Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
              decoration:BoxDecoration(
                color:Colors.black.withValues(alpha:.38),
                borderRadius:BorderRadius.circular(100)),
              child:Row(children:[
                const Icon(Icons.visibility_outlined,color:Colors.white,size:15),
                const SizedBox(width:5),
                Text(compact(item['views']),
                  style:const TextStyle(color:Colors.white,fontSize:11,
                    fontWeight:FontWeight.w700))
              ]))
          ])),
          Positioned(bottom:20,left:16,right:69,child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                CreatorPortrait(name:str(item['creator']),imageUrl:avatar(item),
                  radius:19,highlighted:false),
                const SizedBox(width:9),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(str(item['creator']),maxLines:1,
                      overflow:TextOverflow.ellipsis,style:const TextStyle(
                        color:Colors.white,fontWeight:FontWeight.w900,fontSize:15)),
                    Text(str(item['handle']),maxLines:1,
                      style:const TextStyle(color:Colors.white70,fontSize:11))
                  ])),
              ]),
              const SizedBox(height:13),
              Text(str(item['title']),maxLines:3,overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:Colors.white,fontSize:23,
                  height:1.12,fontWeight:FontWeight.w900)),
              const SizedBox(height:7),
              Text(str(item['description']),maxLines:2,
                overflow:TextOverflow.ellipsis,style:const TextStyle(
                  color:Colors.white,fontSize:12,height:1.4)),
              const SizedBox(height:10),
              Row(children:[
                Icon(Icons.auto_awesome,color:coral,size:14),
                const SizedBox(width:5),
                Expanded(child:Text(str(item['category'])+'  ·  WeuTube',
                  style:const TextStyle(color:Colors.white70,
                    fontWeight:FontWeight.w700,fontSize:11))),
              ])
            ])),
          Positioned(bottom:23,right:10,child:Column(children:[
            _rail(Icons.person_add_alt_1_rounded,followed?'Following':'Follow',
              ()=>follow(item),accent:followed),
            _rail(liked.contains(key)?Icons.favorite:Icons.favorite_border,
              compact(item['likes']),()=>like(item),accent:liked.contains(key)),
            _rail(Icons.mode_comment_outlined,compact(item['comments']),
              ()=>openComments(item)),
            _rail(saved.contains(key)?Icons.bookmark:Icons.bookmark_outline,
              'Save',()=>save(item),accent:saved.contains(key)),
            _rail(Icons.share_rounded,'Share',()=>share(item))
          ])),
          if(showQuickHeart&&index==homeIndex)
            const Center(child:Icon(Icons.favorite_rounded,
              color:Colors.white,size:93)),
          Positioned(bottom:4,left:0,right:0,
            child:Center(child:Container(
              width:28,height:3,
              decoration:BoxDecoration(color:Colors.white38,
                borderRadius:BorderRadius.circular(8)))))
        ])));
  }

  Widget _rail(IconData icon,String label,VoidCallback action,
      {bool accent=false})=>Padding(padding:const EdgeInsets.only(bottom:12),
    child:InkWell(onTap:action,borderRadius:BorderRadius.circular(50),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Icon(icon,color:accent?coral:Colors.white,size:29,
          shadows:const [Shadow(color:Colors.black45,blurRadius:8)]),
        const SizedBox(height:3),
        Text(label,style:const TextStyle(color:Colors.white,fontSize:10,
          fontWeight:FontWeight.w800,
          shadows:[Shadow(color:Colors.black54,blurRadius:6)]))
      ])));

  /// Compact chronological layout for collections (not the immersive Home).
  Widget postCard(Map<String,dynamic> item) {
    final key=id(item),isLiked=liked.contains(key);
    return Padding(padding:const EdgeInsets.only(bottom:21),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Padding(padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),
          child:Row(children:[
            CreatorPortrait(name:str(item['creator']),imageUrl:avatar(item),radius:18),
            const SizedBox(width:8),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(str(item['creator']),style:const TextStyle(
                  color:navy,fontWeight:FontWeight.w800,fontSize:13)),
                Text(str(item['handle']),style:const TextStyle(
                  color:slate,fontSize:11))
              ])),
            if(isDemo(item))pill('DEMO',coral),
            TextButton(onPressed:()=>follow(item),
              child:Text(following.contains(followKey(item))?'Following':'Follow'))
          ])),
        AspectRatio(aspectRatio:1.06,
          child:SocialMediaStage(
            thumbnailUrl:image(item),previewUrl:null,
            active:false,onTap:()=>play(item),
            onDoubleTap:()=>doubleTapLike(item))),
        const SizedBox(height:9),
        Padding(padding:const EdgeInsets.symmetric(horizontal:11),
          child:Row(children:[
            actionIcon(isLiked?Icons.favorite_rounded:Icons.favorite_border_rounded,
              compact(item['likes']),()=>like(item),active:isLiked),
            actionIcon(Icons.mode_comment_outlined,
              compact(item['comments']),()=>openComments(item)),
            actionIcon(Icons.share_rounded,'',()=>share(item)),
            const Spacer(),
            actionIcon(saved.contains(key)?Icons.bookmark_rounded:Icons.bookmark_border_rounded,
              '',()=>save(item),active:saved.contains(key))
          ])),
        Padding(padding:const EdgeInsets.symmetric(horizontal:15,vertical:4),
          child:Text(str(item['title']),style:const TextStyle(
            color:navy,fontSize:17,fontWeight:FontWeight.w900))),
        Padding(padding:const EdgeInsets.symmetric(horizontal:15),
          child:Text(str(item['description']),maxLines:2,
            style:const TextStyle(color:slate,fontSize:12))),
      ]));
  }

  Future<void> share(Map<String,dynamic> item) async {
    final raw=isDemo(item)?str(item['videoUrl']):str(item['youtubeUrl']);
    final uri=Uri.tryParse(raw);
    if(uri==null||uri.scheme!='https') {
      inform('A verified share link is not available.');
      return;
    }
    final box=context.findRenderObject();
    final origin=box is RenderBox?
      (box.localToGlobal(Offset.zero)&box.size):null;
    final caption=isDemo(item)
      ?'WeuTube sample preview (not a real creator post)'
      :isImported(item)?'YouTube video discovered through WeuTube'
      :'Published on WeuTube';
    try {
      await SharePlus.instance.share(ShareParams(
        text:str(item['title'])+'\\n'+caption+'\\n'+raw,
        subject:'WeuTube · '+str(item['title']),
        sharePositionOrigin:origin));
    } catch(_) {
      inform('Sharing is unavailable on this device.');
    }
  }

  Widget sectionTitle(String title,{String? trailing,VoidCallback? onTap}) =>
    Padding(padding:const EdgeInsets.only(top:20,bottom:13),
      child:Row(children:[
        Expanded(child:Text(title,style:const TextStyle(
          color:navy,fontSize:19,fontWeight:FontWeight.w900))),
        if(trailing!=null)TextButton(onPressed:onTap,child:Text(trailing,
          style:const TextStyle(color:coral,fontWeight:FontWeight.w700)))
      ]));

  /// A compact creator-discovery row, not a Stories feature.
  Widget stories() {
    final seen=<String>{};
    final unique=items.where((p)=>seen.add(followKey(p))).take(9).toList();
    return SizedBox(height:76,child:ListView(scrollDirection:Axis.horizontal,
      padding:const EdgeInsets.symmetric(horizontal:12),
      children:[
        for(final item in unique)
          Padding(padding:const EdgeInsets.only(right:16),
            child:InkWell(onTap:()=>widget.onNavigate('Explore'),
              borderRadius:BorderRadius.circular(15),
              child:Column(children:[
                CreatorPortrait(name:str(item['creator']),
                  imageUrl:avatar(item),radius:21,highlighted:false),
                const SizedBox(height:4),
                SizedBox(width:58,child:Text(
                  str(item['creator']).split(' ').first,
                  maxLines:1,overflow:TextOverflow.ellipsis,
                  textAlign:TextAlign.center,
                  style:const TextStyle(color:navy,fontSize:10,
                    fontWeight:FontWeight.w700)))
              ])))
      ]));
  }

  Widget home() {
    List<Map<String,dynamic>> feed=List.of(items);
    if(feedChoice=='Following') {
      feed=feed.where((post)=>following.contains(followKey(post))).toList();
    } else if(feedChoice=='Latest') {
      // Real published videos have timestamps; undated demos belong last.
      feed.sort((a,b) {
        final at = DateTime.tryParse(str(a['publishedAt']));
        final bt = DateTime.tryParse(str(b['publishedAt']));
        if(at==null && bt==null) return 0;
        if(at==null) return 1;
        if(bt==null) return -1;
        return bt.compareTo(at);
      });
    }
    return Column(children:[
      Container(color:Colors.white,
        padding:const EdgeInsets.fromLTRB(15,5,10,5),
        child:Row(children:[
          for(final choice in ['For you','Following','Latest'])
            Expanded(child:InkWell(onTap:(){
                setState((){feedChoice=choice;homeIndex=0;});
                WidgetsBinding.instance.addPostFrameCallback((_){
                  if(homePager.hasClients)homePager.jumpToPage(0);
                });
              },child:Column(mainAxisSize:MainAxisSize.min,children:[
                Padding(padding:const EdgeInsets.symmetric(horizontal:2,vertical:6),
                  child:Text(choice,style:TextStyle(
                    color:choice==feedChoice?navy:slate,
                    fontSize:choice==feedChoice?16:14,
                    fontWeight:choice==feedChoice?FontWeight.w900:FontWeight.w600))),
                AnimatedContainer(duration:const Duration(milliseconds:200),
                  width:choice==feedChoice?28:0,height:3,
                  decoration:BoxDecoration(color:coral,
                    borderRadius:BorderRadius.circular(4)))
              ]))),
        ])),
      Container(color:Colors.white,
        alignment:Alignment.centerLeft,
        padding:const EdgeInsets.fromLTRB(14,8,12,5),
        child:Row(children:[
          const Expanded(child:Text('Discover creators',
            style:TextStyle(color:navy,fontSize:12,fontWeight:FontWeight.w900))),
          InkWell(onTap:()=>widget.onNavigate('Explore'),
            child:const Text('See all',style:TextStyle(
              color:coral,fontSize:11,fontWeight:FontWeight.w800)))
        ])),
      ColoredBox(color:Colors.white,child:stories()),
      if(loadError!=null)
        Container(width:double.infinity,
          padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
          color:const Color(0xFFFFF4F1),
          child:Text(loadError!,style:const TextStyle(color:navy,fontSize:10))),
      Expanded(child:feed.isEmpty
        ?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Icon(Icons.people_outline_rounded,color:coral,size:45),
          const SizedBox(height:10),
          Text(loading ? 'Loading channel videos…'
            : channelSyncStatus == 'NOT_CONNECTED'
              ? 'Connect a YouTube channel to import its videos'
              : channelSyncStatus == 'IMPORTING' ||
                channelSyncStatus == 'PENDING'
                ? 'YouTube video import is running…'
                : 'No public videos available yet',
            textAlign:TextAlign.center,
            style:const TextStyle(color:navy,
              fontWeight:FontWeight.w900,fontSize:16)),
          const SizedBox(height:7),
          Text(loadError ?? 'WeuTube does not show fictional feed videos.',
            textAlign:TextAlign.center,
            style:const TextStyle(color:slate,fontSize:12)),
          TextButton(onPressed:refresh,
            child:const Text('Refresh videos'))
        ]))
        :RefreshIndicator(
          onRefresh:refresh,
          child:PageView.builder(
          key:ValueKey('feed-$feedChoice'),
          controller:homePager,
          scrollDirection:Axis.vertical,
          onPageChanged:(i)=>setState(()=>homeIndex=i),
          itemCount:feed.length,
          itemBuilder:(context,index)=>immersivePost(feed[index],index)))),
    ]);
  }

  Widget exploreTile(Map<String,dynamic> item,int index) {
    final height=index.isEven?218.0:174.0;
    return Padding(padding:const EdgeInsets.only(bottom:10),
      child:InkWell(onTap:()=>play(item),
        borderRadius:BorderRadius.circular(16),
        child:SizedBox(height:height,
          child:ClipRRect(borderRadius:BorderRadius.circular(16),
            child:Stack(fit:StackFit.expand,children:[
              Image.network(image(item),fit:BoxFit.cover,
                errorBuilder:(_,__,___)=>const ColoredBox(color:navy,
                  child:Icon(Icons.play_circle_outline,
                    color:Colors.white,size:50))),
              const DecoratedBox(decoration:BoxDecoration(
                gradient:LinearGradient(begin:Alignment.topCenter,
                  end:Alignment.bottomCenter,
                  colors:[Colors.transparent,Color(0xD9000000)]))),
              Positioned(left:11,right:9,bottom:12,
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  if(isDemo(item))
                    const Text('DEMO',style:TextStyle(
                      color:Color(0xFFFFC5B9),fontSize:9,
                      fontWeight:FontWeight.w900,letterSpacing:.9)),
                  const SizedBox(height:4),
                  Text(str(item['title']),maxLines:2,
                    overflow:TextOverflow.ellipsis,
                    style:const TextStyle(color:Colors.white,
                      fontSize:14,fontWeight:FontWeight.w900,height:1.12)),
                  const SizedBox(height:5),
                  Text(str(item['creator']),maxLines:1,
                    overflow:TextOverflow.ellipsis,
                    style:const TextStyle(color:Colors.white70,fontSize:10))
                ])),
              const Positioned(right:8,top:9,
                child:Icon(Icons.play_circle_fill_rounded,
                  color:Colors.white,size:29))
            ])))));
  }


  /// Compact, content-first discovery. Filters do not compete with the
  /// featured video; the two-column grid works at 320dp and large text.
  Widget explore() {
    final term = search.text.trim().toLowerCase();
    final filtered = items.where((item) =>
      (category == 'All' || str(item['category']) == category) &&
      (term.isEmpty || [
        item['title'], item['description'], item['category'], item['creator']
      ].any((value) => str(value).toLowerCase().contains(term)))).toList();
    final seen = <String>{};
    final creators = items.where((p) => seen.add(followKey(p))).take(8).toList();
    final featured = term.isEmpty && category == 'All' && items.isNotEmpty
      ? items.first : null;

    return ColoredBox(color: Colors.white, child: ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
      children: [
        const Text('Explore', style: TextStyle(
          fontSize: 25, fontWeight: FontWeight.w900, color: navy)),
        const SizedBox(height: 3),
        const Text('Discover videos and creators.',
          style: TextStyle(color: slate, fontSize: 13)),
        const SizedBox(height: 14),
        SizedBox(height: 49, child: TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, color: navy, size: 22),
            suffixIcon: term.isNotEmpty ? IconButton(
              tooltip: 'Clear search',
              onPressed: () => setState(() => search.clear()),
              icon: const Icon(Icons.close_rounded, color: slate, size: 18)
            ) : null,
            hintText: 'Search videos, creators or topics',
            hintStyle: const TextStyle(color: slate, fontSize: 13),
            filled: true, fillColor: const Color(0xFFF5F6F9),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE9ECF2))),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: coral, width: 1.5)),
          ))),
        const SizedBox(height: 12),
        SizedBox(height: 40, child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final topic in ['All','Travel','Food','Art','Lifestyle',
              'Technology','Nature','Music','Storytelling','Education'])
              Padding(padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  label: Text(topic),
                  selected: category == topic,
                  showCheckmark: false,
                  selectedColor: navy,
                  backgroundColor: const Color(0xFFF5F6F9),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                  labelStyle: TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: category == topic ? Colors.white : navy),
                  onSelected: (_) => setState(() => category = topic)))
          ])),
        if (featured != null) ...[
          const SizedBox(height: 15),
          InkWell(onTap: () => play(featured), 
            borderRadius: BorderRadius.circular(17),
            child: ClipRRect(borderRadius: BorderRadius.circular(17),
              child: SizedBox(height: 170, child: Stack(
                fit: StackFit.expand, children: [
                  Image.network(image(featured), fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: navy)),
                  const DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [Color(0xEF061633), Color(0x11061633)]))),
                  Positioned(left: 14, right: 50, bottom: 13,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, children: [
                        Text(isDemo(featured) ? 'DEMO PREVIEW' : 'FEATURED',
                          style: const TextStyle(
                            color: Color(0xFFFFAD9F),fontSize: 9,
                            letterSpacing: .8,fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        Text(str(featured['title']),maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.w900, height: 1.14)),
                        const SizedBox(height: 4),
                        Text(str(featured['creator']), maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70, fontSize: 11))
                      ])),
                  const Positioned(bottom: 18,right: 13,
                    child: Icon(Icons.play_circle_fill_rounded,
                      size: 36,color: Colors.white))
                ])))),
        ],
        if (term.isEmpty && category == 'All' && creators.isNotEmpty) ...[
          sectionTitle('Creators'),
          SizedBox(height: 91, child: ListView(
            scrollDirection: Axis.horizontal, children: [
              for(final creator in creators)
                Padding(padding: const EdgeInsets.only(right: 14),
                  child: InkWell(
                    onTap: () => follow(creator),
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(width: 68,
                      child: Column(children: [
                        CreatorPortrait(name: str(creator['creator']),
                          imageUrl: avatar(creator), radius: 24,
                          highlighted: false),
                        const SizedBox(height: 4),
                        Text(str(creator['creator']).split(' ').first,
                          maxLines: 1,overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: navy,
                            fontSize: 11,fontWeight: FontWeight.w700)),
                        Text(following.contains(followKey(creator))
                            ? 'Following' : 'Follow',
                          style: const TextStyle(color: coral,
                            fontSize: 10,fontWeight: FontWeight.w700)),
                      ]))))
            ])),
        ],
        sectionTitle(term.isNotEmpty ? 'Search results' : 'Videos'),
        if (filtered.isEmpty)
          Container(padding: const EdgeInsets.symmetric(
              vertical: 36,horizontal: 12),
            child: const Column(children: [
              Icon(Icons.search_off_rounded,size: 32,color: slate),
              SizedBox(height: 8),
              Text('No matches found',style: TextStyle(
                color: navy, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('Try a different search or topic.',
                style: TextStyle(color: slate,fontSize: 12)),
            ]))
        else Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Column(children: [
              for(var i = 0; i < filtered.length; i += 2)
                exploreTile(filtered[i], i)
            ])),
            const SizedBox(width: 10),
            Expanded(child: Column(children: [
              for(var i = 1; i < filtered.length; i += 2)
                exploreTile(filtered[i], i)
            ])),
          ]),
        const SizedBox(height: 12),
        if(items.any(isDemo))
          const Text('Demo videos are labeled. Published creator videos appear after approval.',
            textAlign: TextAlign.center,
            style: TextStyle(color: slate,fontSize: 10)),
      ]));
  }

  Widget shorts() {
    if(items.isEmpty)return Center(
      child:Padding(
        padding:const EdgeInsets.all(23),
        child:Column(mainAxisSize:MainAxisSize.min,children:[
          const Icon(Icons.smart_display_outlined,
            color:coral,size:42),
          const SizedBox(height:12),
          Text(loading ? 'Loading real YouTube videos…'
            : channelSyncStatus == 'NOT_CONNECTED'
              ? 'YouTube channel not connected for discovery'
              : channelSyncStatus == 'IMPORTING' ||
                  channelSyncStatus == 'PENDING'
                ? 'Importing videos from the YouTube channel…'
                : 'No public short-form videos available yet',
            textAlign:TextAlign.center,
            style:const TextStyle(color:navy,
              fontSize:15,fontWeight:FontWeight.w800)),
          const SizedBox(height:8),
          Text(loadError ?? 'No sample Shorts or fictional creator metrics.',
            textAlign:TextAlign.center,
            style:const TextStyle(color:slate,fontSize:12)),
          TextButton.icon(onPressed:refresh,
            icon:const Icon(Icons.refresh),
            label:const Text('Refresh channel videos'))
        ]),
      ),
    );
    return PageView.builder(
      controller:shortsPager,scrollDirection:Axis.vertical,
      onPageChanged:(index)=>setState(()=>shortIndex=index),
      itemCount:items.length,
      itemBuilder:(context,index) {
        final post=items[index],key=id(post);
        if (!isDemo(post)) {
          return publishedImmersivePost(post, index, shorts: true);
        }
        return Stack(fit:StackFit.expand,children:[
          SocialMediaStage(
            key:ValueKey('shorts-media-$key'),
            thumbnailUrl:image(post),
            previewUrl:isDemo(post)?str(post['videoUrl']):null,
            active:!playerSheetOpen&&widget.section=='Shorts'&&shortIndex==index,
            immersive:true,
            onTap:()=>play(post),
            onDoubleTap:()=>doubleTapLike(post)),
          Positioned(top:18,left:17,right:15,child:Row(children:[
            const Text('Shorts',style:TextStyle(
              color:Colors.white,fontSize:22,fontWeight:FontWeight.w900)),
            const Spacer(),
            pill(isDemo(post)?'DEMO · preview':'PUBLISHED',Colors.white)
          ])),
          Positioned(bottom:43,left:16,right:73,
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                CreatorPortrait(name:str(post['creator']),
                  imageUrl:avatar(post),radius:21,highlighted:false),
                const SizedBox(width:9),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                  children:[
                    Text(str(post['creator']),style:const TextStyle(
                      color:Colors.white,fontSize:15,fontWeight:FontWeight.w900)),
                    Text(str(post['handle']),style:const TextStyle(
                      color:Colors.white70,fontSize:11))
                  ])),
                InkWell(onTap:()=>follow(post),
                  child:Container(
                    padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
                    decoration:BoxDecoration(
                      color:coral,borderRadius:BorderRadius.circular(7)),
                    child:Text(following.contains(followKey(post))?
                      'Following':'+ Follow',style:const TextStyle(
                        color:Colors.white,fontSize:10,fontWeight:FontWeight.w800))))
              ]),
              const SizedBox(height:14),
              Text(str(post['title']),maxLines:3,
                overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:Colors.white,
                  fontSize:23,height:1.1,fontWeight:FontWeight.w900)),
              const SizedBox(height:7),
              Text(str(post['description']),maxLines:2,
                overflow:TextOverflow.ellipsis,
                style:const TextStyle(color:Colors.white,fontSize:12)),
              const SizedBox(height:10),
              Row(children:[
                const Icon(Icons.music_note_rounded,size:14,color:coral),
                const SizedBox(width:6),
                Flexible(child:Text(str(post['category'])+' · WeuTube',
                  style:const TextStyle(color:Colors.white70,
                    fontSize:11,fontWeight:FontWeight.w600)))
              ])
            ])),
          Positioned(right:9,bottom:60,child:Column(children:[
            _rail(liked.contains(key)?Icons.favorite_rounded:Icons.favorite_border_rounded,
              compact(post['likes']),()=>like(post),accent:liked.contains(key)),
            _rail(Icons.mode_comment_outlined,
              compact(post['comments']),()=>openComments(post)),
            _rail(saved.contains(key)?Icons.bookmark_rounded:Icons.bookmark_border_rounded,
              'Save',()=>save(post),accent:saved.contains(key)),
            _rail(Icons.share_rounded,'Share',()=>share(post))
          ])),
          const Positioned(top:65,right:15,child:Text('SWIPE TO EXPLORE',
            style:TextStyle(color:Colors.white70,fontSize:10,
              fontWeight:FontWeight.w800,letterSpacing:1))),
          if(showQuickHeart)
            const Center(child:Icon(Icons.favorite_rounded,
              color:Colors.white,size:92))
        ]);
      });
  }


  /// Upload is the sole primary action. No stock hero/video thumbnail is
  /// used to obscure the CTA or pretend creators have uploaded anything.
  Widget create() => ColoredBox(color: Colors.white,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(19, 24, 19, 30),children: [
        const Text('Create',style: TextStyle(
          color: navy,fontSize: 26,fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text('Share a video with the WeuTube community.',
          style: TextStyle(color: slate,fontSize: 13)),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 19),
          decoration: BoxDecoration(color: navy,
            borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
            Container(width: 43,height: 43,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:.12),
                borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.video_call_rounded,
                color: Colors.white,size: 26)),
            const SizedBox(height: 16),
            Text(widget.api.signedIn
              ? 'Ready to upload?' : 'Have a video to share?',
              style: const TextStyle(color: Colors.white,
                fontSize: 22,fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Upload your own content for review before it goes public.',
              style: TextStyle(color: Colors.white70,fontSize: 13,height: 1.4)),
            const SizedBox(height: 17),
            SizedBox(width: double.infinity,height: 51,
              child: FilledButton.icon(
                onPressed: widget.onCreate,
                style: FilledButton.styleFrom(
                  backgroundColor: coral,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
                icon: Icon(widget.api.signedIn
                  ? Icons.upload_file_rounded : Icons.login_rounded,
                  size: 20),
                label: Text(widget.api.signedIn
                  ? 'Open Upload Studio' : 'Sign in to upload',
                  style: const TextStyle(fontWeight: FontWeight.w800,
                    fontSize: 14))))
          ])),
        const SizedBox(height: 25),
        const Text('How publishing works',style: TextStyle(
          color: navy,fontSize: 17,fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        for(final stage in [
          (Icons.edit_note_rounded,'1','Prepare',
            'Choose your video and add its details.'),
          (Icons.fact_check_outlined,'2','Review',
            'Your upload is reviewed before publishing.'),
          (Icons.public_rounded,'3','Publish',
            'Approved videos appear in the feed.'),
        ])
          Padding(padding: const EdgeInsets.only(bottom: 15),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start,children: [
              Container(width: 39,height: 39,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFEB),
                  borderRadius: BorderRadius.circular(12)),
                child: Icon(stage.$1,color: coral,size: 21)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,children: [
                  Text('${stage.$2}. ${stage.$3}',
                    style: const TextStyle(color: navy,
                      fontSize: 14,fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(stage.$4,style: const TextStyle(
                    color: slate,fontSize: 12,height: 1.4))
                ]))
            ])),
        const SizedBox(height: 4),
        const Text('Only upload videos you own or are authorized to share.',
          style: TextStyle(color: slate,fontSize: 11)),
      ]));
  

  /// Account first, collections second, tools third. Avoid demo followers,
  /// oversized decorative panels and fictional account statistics.
  Widget profile() {
    final signedIn = widget.api.signedIn;
    return ColoredBox(color: Colors.white,child: ListView(
      padding: const EdgeInsets.fromLTRB(17, 16, 17, 28),children: [
        const Text('You',style: TextStyle(
          color: navy,fontSize: 26,fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        Row(children: [
          Container(width: 62,height: 62,
            decoration: BoxDecoration(color: const Color(0xFFEFF2F8),
              shape: BoxShape.circle),
            child: Icon(signedIn
              ? Icons.person_rounded : Icons.person_outline_rounded,
              color: navy,size: 32)),
          const SizedBox(width: 13),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,children: [
              Text(signedIn ? 'Your WeuTube account' : 'Welcome to WeuTube',
                style: const TextStyle(color: navy,fontSize: 17,
                  fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(signedIn
                ? 'Manage videos and creator tools.'
                : 'Sign in to save and follow creators.',
                style: const TextStyle(color: slate,fontSize: 12,height: 1.35))
            ])),
        ]),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity,height: 49,
          child: FilledButton.icon(
            onPressed: signedIn ? widget.onStudio : widget.onSignIn,
            style: FilledButton.styleFrom(
              backgroundColor: coral, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            icon: Icon(signedIn
              ? Icons.dashboard_outlined : Icons.login_rounded,size: 20),
            label: Text(signedIn ? 'Open Creator Studio'
              : 'Sign In / Create Account',
              style: const TextStyle(fontWeight: FontWeight.w800)))),
        const SizedBox(height: 22),
        const Text('Your collection',style: TextStyle(
          color: navy,fontSize: 17,fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        _accountLink('Saved videos', 'Videos you bookmarked',
          Icons.bookmark_outline_rounded, () => widget.onNavigate('Saved')),
        _accountLink('Following', 'Creators you follow',
          Icons.people_outline_rounded, () => widget.onNavigate('Following')),
        if(signedIn) ...[
          const SizedBox(height: 18),
          const Text('Creator tools',style: TextStyle(
            color: navy,fontSize: 17,fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _accountLink('My Videos', 'Drafts, reviews and published videos',
            Icons.video_library_outlined,
            () => widget.onNavigate('My Videos')),
          _accountLink('Analytics', 'Verified engagement statistics',
            Icons.insights_rounded,
            () => widget.onNavigate('Analytics')),
          _accountLink('Wallet', 'Your balance and payout records',
            Icons.account_balance_wallet_outlined,
            () => widget.onNavigate('Wallet')),
          _accountLink('Settings', 'Account and sign-out options',
            Icons.settings_outlined,
            () => widget.onNavigate('Settings')),
        ],
        const SizedBox(height: 17),
        const Text('Browse videos without signing in. Sign in to save, follow or upload.',
          textAlign: TextAlign.center,
          style: TextStyle(color: slate,fontSize: 11,height: 1.45)),
      ]));
  }

  Widget _accountLink(String title,String subtitle,
      IconData icon,VoidCallback onTap) =>
    Column(children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.symmetric(
          horizontal: 3,vertical: 11),
          child: Row(children: [
            Container(width: 40,height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(icon,color: navy,size: 21)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,children: [
                Text(title,style: const TextStyle(color: navy,
                  fontSize: 14,fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(subtitle,style: const TextStyle(
                  color: slate,fontSize: 11))
              ])),
            const Icon(Icons.chevron_right_rounded,color: slate)
          ]))),
      const Divider(color: Color(0xFFEDF0F4),height: 1),
    ]);

  Widget savedView() => ListView(
    padding:const EdgeInsets.all(15),
    children:[
      sectionTitle('Saved stories'),
      if(saved.isEmpty)const Text('Tap the bookmark on a video to save it.'),
      for(final item in items.where((p)=>saved.contains(id(p))))postCard(item)
    ]);
  Widget followingView() => ListView(
    padding:const EdgeInsets.all(15),
    children:[
      sectionTitle('Following'),
      if(following.isEmpty)const Text('Follow creators to see them here.'),
      for(final item in items.where((p)=>following.contains(
        str(p['creatorId']).isNotEmpty?str(p['creatorId']):str(p['creator']))))postCard(item)
    ]);

  @override
  Widget build(BuildContext context) => switch(widget.section) {
    'Home' => home(),
    'Explore' => explore(),
    'Shorts' => shorts(),
    'Create' => create(),
    'You' => profile(),
    'Saved' => savedView(),
    'Following' => followingView(),
    _ => home()
  };
}

class DemoVideoPlayer extends StatefulWidget {
  final String url,title;
  const DemoVideoPlayer({super.key,required this.url,required this.title});
  @override
  State<DemoVideoPlayer> createState() => _DemoVideoPlayerState();
}

class _DemoVideoPlayerState extends State<DemoVideoPlayer> {
  late final VideoPlayerController player;
  bool failed=false;
  @override
  void initState() {
    super.initState();
    player=VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if(mounted) setState((){});
        player.play();
      }).catchError((Object _) {
        if(mounted)setState(()=>failed=true);
      });
  }
  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Padding(
    padding:const EdgeInsets.fromLTRB(14,17,14,30),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Row(children:[
        Expanded(child:Text(widget.title,maxLines:1,
          style:const TextStyle(color:Colors.white,
            fontWeight:FontWeight.w900,fontSize:17))),
        IconButton(onPressed:()=>Navigator.pop(context),
          icon:const Icon(Icons.close,color:Colors.white))
      ]),
      const SizedBox(height:10),
      AspectRatio(aspectRatio:player.value.isInitialized
        ?player.value.aspectRatio:16/9,
        child:failed?const Center(child:Text('Demo video unavailable.',
          style:TextStyle(color:Colors.white)))
          :player.value.isInitialized?GestureDetector(
            onTap:(){
              if(player.value.isPlaying)player.pause();
              else player.play();
              setState((){});
            },
            child:VideoPlayer(player))
            :const Center(child:CircularProgressIndicator(color:coral))),
      const SizedBox(height:15),
      Row(children:[
        IconButton(onPressed:(){
          if(!player.value.isInitialized)return;
          if(player.value.isPlaying)player.pause();
          else player.play();
          setState((){});
        },icon:Icon(player.value.isPlaying?Icons.pause:Icons.play_arrow,
          color:Colors.white)),
        Expanded(child:player.value.isInitialized
          ?VideoProgressIndicator(player,allowScrubbing:true,
             colors:const VideoProgressColors(playedColor:coral))
          :const SizedBox(height:3)),
      ]),
      const SizedBox(height:8),
      const Text('Sample clip — not a creator upload or a YouTube publication.',
        style:TextStyle(color:Colors.white70,fontSize:11))
    ]));
}
