import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

import 'backend_client.dart';
import 'social_demo_data.dart';
import 'social_design_widgets.dart';
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
  static const demo = socialDemoPosts;
  final Set<String> liked = {}, saved = {}, following = {};
  final Map<String, List<String>> draftComments = {};
  final search = TextEditingController();
  final PageController shortsPager = PageController();
  final PageController homePager = PageController();
  List<Map<String, dynamic>> items = List.from(demo);
  bool loading = false;
  String category = 'All';
  String feedChoice = 'For you';
  String? loadError;
  int shortIndex = 0;
  int homeIndex = 0;
  bool showQuickHeart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  @override
  void dispose() {
    shortsPager.dispose();
    homePager.dispose();
    search.dispose();
    super.dispose();
  }

  bool isDemo(Map<String, dynamic> item) => item['demo'] == true;
  String str(dynamic value) => value?.toString() ?? '';
  String id(Map<String, dynamic> item) => str(item['id']);
  String image(Map<String, dynamic> item) => str(item['thumbnailUrl']);
  String avatar(Map<String, dynamic> item) => str(item['avatarUrl']);
  String followKey(Map<String,dynamic> item) =>
    str(item['creatorId']).isEmpty ? str(item['creator']) : str(item['creatorId']);
  void doubleTapLike(Map<String,dynamic> item) {
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
      final result = await widget.api.publicFeed();
      final received = (result['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>().toList();
      if(!mounted) return;
      setState(() {items = received.isEmpty ? List.of(demo) : received;});
      if(widget.api.signedIn) {
        final state = await widget.api.socialState();
        if(!mounted) return;
        setState(() {
          liked.addAll((state['likedVideoIds'] as List<dynamic>? ?? []).map(str));
          saved.addAll((state['savedVideoIds'] as List<dynamic>? ?? []).map(str));
          following.addAll((state['followingCreatorIds'] as List<dynamic>? ?? []).map(str));
        });
      }
    } catch(_) {
      if(mounted) setState(() {
        loadError = 'Preview feed shown. Live discovery is temporarily unavailable.';
        items = List.of(demo);
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

  Future<void> play(Map<String,dynamic> item) async {
    if(isDemo(item)) {
      final url = str(item['videoUrl']);
      if(url.isEmpty) {inform('Sample clip unavailable.');return;}
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,
        backgroundColor:const Color(0xFF08132E),useSafeArea:true,
        builder:(_) => DemoVideoPlayer(url:url,title:str(item['title'])));
    } else {
      final raw = str(item['youtubeUrl']);
      final uri = Uri.tryParse(raw);
      if(uri == null || uri.scheme != 'https' ||
          !['www.youtube.com','youtube.com'].contains(uri.host)) {
        inform('This video does not have a verified playback link.');return;
      }
      if(!await launchUrl(uri,mode:LaunchMode.externalApplication)) {
        inform('Unable to open the published video.');
      }
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

  /// Video-first, full-height card: content takes the screen instead of
  /// being buried under repetitive white Flutter dashboard containers.
  Widget immersivePost(Map<String,dynamic> item,int index) {
    final key=id(item),followed=following.contains(followKey(item));
    return Padding(padding:const EdgeInsets.fromLTRB(9,3,9,6),
      child:ClipRRect(borderRadius:BorderRadius.circular(22),
        child:Stack(fit:StackFit.expand,children:[
          SocialMediaStage(
            key:ValueKey('home-media-$key'),
            thumbnailUrl:image(item),
            previewUrl:isDemo(item)?str(item['videoUrl']):null,
            active:widget.section=='Home'&&index==homeIndex,
            immersive:true,
            onTap:()=>play(item),
            onDoubleTap:()=>doubleTapLike(item)),
          Positioned(top:15,left:15,right:15,child:Row(children:[
            if(isDemo(item))
              pill('DEMO · sample content',Colors.white)
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
                  radius:19,highlighted:true),
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

  Widget stories() {
    final seen=<String>{};
    final unique=items.where((p)=>seen.add(followKey(p))).take(9).toList();
    return SizedBox(height:85,child:ListView(scrollDirection:Axis.horizontal,
      padding:const EdgeInsets.symmetric(horizontal:12),
      children:[
        Padding(padding:const EdgeInsets.only(right:16),
          child:InkWell(onTap:widget.onCreate,
            borderRadius:BorderRadius.circular(15),
            child:Column(children:[
              Container(width:48,height:48,
                decoration:BoxDecoration(
                  color:coral.withValues(alpha:.10),shape:BoxShape.circle,
                  border:Border.all(color:coral.withValues(alpha:.25))),
                child:const Icon(Icons.add_rounded,color:coral,size:24)),
              const SizedBox(height:4),
              const Text('Your video',style:TextStyle(
                color:slate,fontSize:10,fontWeight:FontWeight.w700))
            ]))),
        for(final item in unique)
          Padding(padding:const EdgeInsets.only(right:16),
            child:InkWell(onTap:()=>play(item),
              borderRadius:BorderRadius.circular(15),
              child:Column(children:[
                CreatorPortrait(name:str(item['creator']),
                  imageUrl:avatar(item),radius:23,highlighted:true),
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
    } else if(feedChoice=='Fresh') {
      feed=feed.reversed.toList();
    }
    return Column(children:[
      Container(color:Colors.white,
        padding:const EdgeInsets.fromLTRB(15,5,10,5),
        child:Row(children:[
          for(final choice in ['For you','Following','Fresh'])
            Padding(padding:const EdgeInsets.only(right:13),
              child:InkWell(onTap:(){
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
          const Spacer(),
          IconButton(onPressed:()=>widget.onNavigate('Explore'),
            tooltip:'Search creators and topics',
            icon:const Icon(Icons.search_rounded,color:navy,size:25)),
          IconButton(onPressed:refresh,
            tooltip:'Refresh feed',icon:const Icon(Icons.refresh_rounded,color:slate))
        ])),
      Container(color:Colors.white,
        alignment:Alignment.centerLeft,
        padding:const EdgeInsets.fromLTRB(14,8,12,5),
        child:Row(children:[
          const Expanded(child:Text('Creators worth discovering',
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
          const Text('Your circle starts here',
            style:TextStyle(color:navy,fontWeight:FontWeight.w900,fontSize:19)),
          const SizedBox(height:7),
          const Text('Follow a creator and their stories will appear here.',
            style:TextStyle(color:slate,fontSize:12)),
          TextButton(onPressed:()=>widget.onNavigate('Explore'),
            child:const Text('Discover creators'))
        ]))
        :PageView.builder(
          key:ValueKey('feed-$feedChoice'),
          controller:homePager,
          scrollDirection:Axis.vertical,
          onPageChanged:(i)=>setState(()=>homeIndex=i),
          itemCount:feed.length,
          itemBuilder:(context,index)=>immersivePost(feed[index],index))),
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

  Widget explore() {
    final term=search.text.trim().toLowerCase();
    final filtered=items.where((item)=>
      (category=='All'||str(item['category'])==category) &&
      (term.isEmpty||[
        item['title'],item['description'],item['category'],item['creator']
      ].any((value)=>str(value).toLowerCase().contains(term)))).toList();
    final distinct=<String>{};
    final creators=items.where((p)=>distinct.add(followKey(p))).take(8).toList();
    return ListView(padding:const EdgeInsets.fromLTRB(15,12,15,28),children:[
      const Text('Explore',style:TextStyle(
        fontSize:28,fontWeight:FontWeight.w900,color:navy)),
      const SizedBox(height:5),
      const Text('People, passions and places worth finding.',
        style:TextStyle(color:slate,fontSize:13)),
      const SizedBox(height:15),
      TextField(controller:search,onChanged:(_)=>setState((){}),
        decoration:InputDecoration(
          prefixIcon:const Icon(Icons.search_rounded,color:navy),
          hintText:'Search creators, videos or topics',
          hintStyle:const TextStyle(color:slate,fontSize:13),
          contentPadding:const EdgeInsets.symmetric(vertical:14),
          fillColor:Colors.white,filled:true,
          enabledBorder:OutlineInputBorder(
            borderRadius:BorderRadius.circular(15),
            borderSide:const BorderSide(color:Color(0xFFE8EBF1))),
          focusedBorder:OutlineInputBorder(
            borderRadius:BorderRadius.circular(15),
            borderSide:const BorderSide(color:coral,width:1.5)))),
      const SizedBox(height:14),
      SingleChildScrollView(scrollDirection:Axis.horizontal,
        child:Row(children:[
          for(final t in ['All','Travel','Food','Art','Lifestyle','Technology',
            'Nature','Music','Storytelling','Education'])
            Padding(padding:const EdgeInsets.only(right:7),
              child:ChoiceChip(label:Text(t),selected:category==t,
                showCheckmark:false,
                backgroundColor:Colors.white,
                selectedColor:coral.withValues(alpha:.12),
                side:BorderSide(color:category==t?coral.withValues(alpha:.3):
                  const Color(0xFFE6E9EF)),
                labelStyle:TextStyle(fontWeight:FontWeight.w700,
                  color:category==t?coral:navy,fontSize:12),
                onSelected:(_)=>setState(()=>category=t)))
        ])),
      const SizedBox(height:13),
      if(term.isEmpty&&category=='All'&&items.isNotEmpty)
        InkWell(onTap:()=>play(items.first),child:ClipRRect(
          borderRadius:BorderRadius.circular(20),
          child:SizedBox(height:150,child:Stack(fit:StackFit.expand,children:[
            Image.network(image(items.first),fit:BoxFit.cover,
              errorBuilder:(_,__,___)=>const ColoredBox(color:navy)),
            const DecoratedBox(decoration:BoxDecoration(
              gradient:LinearGradient(begin:Alignment.centerLeft,
                end:Alignment.centerRight,
                colors:[Color(0xD9031B4B),Colors.transparent]))),
            const Positioned(left:18,top:18,right:70,
              child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('SPOTLIGHT',style:TextStyle(
                  color:Color(0xFFFFB2A4),fontWeight:FontWeight.w900,
                  fontSize:10,letterSpacing:1)),
                SizedBox(height:9),
                Text('Discover something\nunexpected.',style:TextStyle(
                  color:Colors.white,fontWeight:FontWeight.w900,
                  fontSize:22,height:1.12)),
                SizedBox(height:6),
                Text('Curated preview stories',
                  style:TextStyle(color:Colors.white70,fontSize:11))
              ])),
            const Positioned(right:18,bottom:18,child:Icon(
              Icons.play_circle_fill_rounded,color:Colors.white,size:45))
          ])))),
      sectionTitle('Meet the creators',
        trailing:'See stories',onTap:()=>widget.onNavigate('Home')),
      SizedBox(height:100,child:ListView(scrollDirection:Axis.horizontal,
        children:[
          for(final creator in creators)
            Padding(padding:const EdgeInsets.only(right:15),
              child:InkWell(onTap:()=>follow(creator),
                child:Column(children:[
                  CreatorPortrait(name:str(creator['creator']),
                    imageUrl:avatar(creator),radius:27,highlighted:true),
                  const SizedBox(height:5),
                  SizedBox(width:66,child:Text(
                    str(creator['creator']).split(' ').first,
                    maxLines:1,overflow:TextOverflow.ellipsis,
                    textAlign:TextAlign.center,style:const TextStyle(
                      color:navy,fontWeight:FontWeight.w700,fontSize:11))),
                  Text(following.contains(followKey(creator))?'Following':'+ Follow',
                    style:const TextStyle(color:coral,
                      fontWeight:FontWeight.w800,fontSize:10))
                ])))
        ])),
      sectionTitle('For your curiosity'),
      if(filtered.isEmpty)const Padding(
        padding:EdgeInsets.symmetric(vertical:30),
        child:Text('Nothing matches yet. Try another topic.',
          style:TextStyle(color:slate))),
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Expanded(child:Column(children:[
          for(var i=0;i<filtered.length;i+=2)exploreTile(filtered[i],i)
        ])),
        const SizedBox(width:10),
        Expanded(child:Column(children:[
          for(var i=1;i<filtered.length;i+=2)exploreTile(filtered[i],i)
        ]))
      ]),
      const SizedBox(height:12),
      const Center(child:Text('Demo content is labeled. Real creator posts appear after approval.',
        style:TextStyle(color:slate,fontSize:10)))
    ]);
  }

  Widget shorts() {
    if(items.isEmpty)return const Center(child:CircularProgressIndicator());
    return PageView.builder(
      controller:shortsPager,scrollDirection:Axis.vertical,
      onPageChanged:(index)=>setState(()=>shortIndex=index),
      itemCount:items.length,
      itemBuilder:(context,index) {
        final post=items[index],key=id(post);
        return Stack(fit:StackFit.expand,children:[
          SocialMediaStage(
            key:ValueKey('shorts-media-$key'),
            thumbnailUrl:image(post),
            previewUrl:isDemo(post)?str(post['videoUrl']):null,
            active:widget.section=='Shorts'&&shortIndex==index,
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
                  imageUrl:avatar(post),radius:21,highlighted:true),
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

  Widget create() => ListView(padding:const EdgeInsets.all(19),children:[
    const SizedBox(height:6),
    const Text('Create something great.',style:TextStyle(
      color:navy,fontSize:28,fontWeight:FontWeight.w900)),
    const SizedBox(height:6),
    const Text('A simple route from your idea to the community.',
      style:TextStyle(color:slate)),
    const SizedBox(height:22),
    card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      ClipRRect(borderRadius:BorderRadius.circular(16),
        child:SizedBox(height:195,width:double.infinity,
          child:Image.network(image(items.first),fit:BoxFit.cover,
            errorBuilder:(_,__,___)=>const ColoredBox(color:soft,
              child:Icon(Icons.video_collection,color:coral,size:50))))),
      const SizedBox(height:16),
      const Text('Your next story starts here',
        style:TextStyle(fontWeight:FontWeight.w900,fontSize:21,color:navy)),
      const SizedBox(height:9),
      const Text('Upload privately. Get it reviewed. Publish with confidence.',
        style:TextStyle(color:slate)),
      const SizedBox(height:20),
      SizedBox(width:double.infinity,
        child:FilledButton.icon(onPressed:widget.onCreate,
          style:FilledButton.styleFrom(backgroundColor:coral,
            padding:const EdgeInsets.all(16)),
          icon:const Icon(Icons.cloud_upload_outlined),
          label:Text(widget.api.signedIn?'Open Upload Studio':'Sign in to upload')))
    ])),
    sectionTitle('Your creator journey'),
    card(Column(children:[
      for(final row in [
        [Icons.edit_note,'01','Prepare','Add your title and choose a video'],
        [Icons.fact_check_outlined,'02','Review','Your private upload goes to moderation'],
        [Icons.public_rounded,'03','Publish','Approved work appears in discovery']
      ])
        ListTile(leading:CircleAvatar(backgroundColor:coral.withValues(alpha:.09),
            child:Icon(row[0] as IconData,color:coral)),
          title:Text(row[2] as String,style:const TextStyle(
            fontWeight:FontWeight.w800,color:navy)),
          subtitle:Text(row[3] as String),
          trailing:Text(row[1] as String,style:const TextStyle(
            color:coral,fontWeight:FontWeight.w800)))
    ]))
  ]);

  Widget profile() => ListView(
    padding:const EdgeInsets.fromLTRB(14,12,14,30),children:[
      Container(padding:const EdgeInsets.all(20),
        decoration:BoxDecoration(color:navy,
          borderRadius:BorderRadius.circular(24)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Row(children:[
            Text('YOUR WORLD',style:TextStyle(color:Color(0xFFFFA99A),
              fontWeight:FontWeight.w900,fontSize:11,letterSpacing:1.1)),
            Spacer(),
            Icon(Icons.auto_awesome_rounded,color:coral,size:23)
          ]),
          const SizedBox(height:16),
          Row(children:[
            Container(width:72,height:72,
              decoration:BoxDecoration(shape:BoxShape.circle,
                color:Colors.white.withValues(alpha:.11),
                border:Border.all(color:Colors.white30)),
              child:const Icon(Icons.person_rounded,color:Colors.white,size:43)),
            const SizedBox(width:15),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Text(widget.api.signedIn?'Your creator profile':'Your story starts here',
                  maxLines:2,style:const TextStyle(
                    color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),
                const SizedBox(height:5),
                Text(widget.api.signedIn?'Connected to your WeuTube account':
                  'Discover creators. Save what inspires you.',
                  style:const TextStyle(color:Colors.white70,fontSize:12))
              ]))
          ]),
          const SizedBox(height:19),
          Row(children:[
            Expanded(child:_profileStat(following.length.toString(),'Following')),
            const SizedBox(width:12),
            Expanded(child:_profileStat(saved.length.toString(),'Saved')),
            const SizedBox(width:12),
            Expanded(child:_profileStat(
              widget.api.signedIn?'Live':'Guest','Mode'))
          ]),
          const SizedBox(height:17),
          SizedBox(width:double.infinity,
            child:FilledButton.icon(
              style:FilledButton.styleFrom(
                backgroundColor:coral,
                padding:const EdgeInsets.symmetric(vertical:13)),
              onPressed:widget.api.signedIn?widget.onStudio:widget.onSignIn,
              icon:Icon(widget.api.signedIn?Icons.dashboard_outlined:Icons.login_rounded),
              label:Text(widget.api.signedIn?'Open Creator Studio':'Sign in / Create account')))
        ])),
      sectionTitle('Your collection'),
      Row(children:[
        Expanded(child:_collectionTile('Saved stories',
          Icons.bookmark_rounded,()=>widget.onNavigate('Saved'))),
        const SizedBox(width:10),
        Expanded(child:_collectionTile('People you follow',
          Icons.people_alt_rounded,()=>widget.onNavigate('Following')))
      ]),
      sectionTitle('Creators to discover',
        trailing:'Explore',onTap:()=>widget.onNavigate('Explore')),
      SizedBox(height:155,child:ListView(scrollDirection:Axis.horizontal,
        children:[
          for(final p in items.take(6))
            Padding(padding:const EdgeInsets.only(right:10),
              child:InkWell(onTap:()=>follow(p),
                borderRadius:BorderRadius.circular(16),
                child:Container(width:110,padding:const EdgeInsets.all(10),
                  decoration:BoxDecoration(color:Colors.white,
                    borderRadius:BorderRadius.circular(16)),
                  child:Column(children:[
                    CreatorPortrait(name:str(p['creator']),
                      imageUrl:avatar(p),radius:28),
                    const SizedBox(height:8),
                    Text(str(p['creator']),maxLines:1,
                      overflow:TextOverflow.ellipsis,
                      style:const TextStyle(color:navy,
                        fontWeight:FontWeight.w800,fontSize:11)),
                    const SizedBox(height:5),
                    Text(following.contains(followKey(p))?'Following':'+ Follow',
                      style:const TextStyle(color:coral,
                        fontWeight:FontWeight.w800,fontSize:11))
                  ]))))
        ])),
      sectionTitle('Creator tools'),
      Container(decoration:BoxDecoration(color:Colors.white,
        borderRadius:BorderRadius.circular(16)),
        child:Column(children:[
          for(final entry in [
            ['My Videos',Icons.video_library_outlined],
            ['Analytics',Icons.insights_rounded],
            ['Wallet',Icons.account_balance_wallet_outlined],
            ['Settings',Icons.settings_outlined]
          ])
            ListTile(leading:Icon(entry[1] as IconData,color:navy),
              title:Text(entry[0] as String),
              trailing:const Icon(Icons.chevron_right,color:slate),
              onTap:()=>widget.api.signedIn?
                widget.onNavigate(entry[0] as String):widget.onSignIn())
        ])),
      const SizedBox(height:17),
      const Text('Preview creators and sample reactions are demonstration data.',
        textAlign:TextAlign.center,
        style:TextStyle(color:slate,fontSize:10))
    ]);
  Widget _profileStat(String count,String title) =>
    Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(count,style:const TextStyle(color:Colors.white,
        fontSize:22,fontWeight:FontWeight.w900)),
      const SizedBox(height:3),
      Text(title,style:const TextStyle(
        color:Colors.white70,fontSize:11))
    ]);
  Widget _collectionTile(String name,IconData icon,VoidCallback tap) =>
    InkWell(onTap:tap,borderRadius:BorderRadius.circular(17),
      child:Container(height:109,padding:const EdgeInsets.all(15),
        decoration:BoxDecoration(color:Colors.white,
          borderRadius:BorderRadius.circular(17)),
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(icon,color:coral,size:25),
          const Spacer(),
          Text(name,style:const TextStyle(color:navy,
            fontWeight:FontWeight.w900,fontSize:12))
        ])));

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
