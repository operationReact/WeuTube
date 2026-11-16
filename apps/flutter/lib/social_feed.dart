import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import 'backend_client.dart';
import 'social_demo_data.dart';
import 'social_design_widgets.dart';
import 'product_ui.dart' show navy, coral, soft, slate, success;

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
  Widget thumbnail(Map<String,dynamic> item,{double? height,
      BorderRadius? radius}) {
    return ClipRRect(borderRadius:radius ?? BorderRadius.circular(17),
      child:Stack(fit:StackFit.expand,children:[
        Container(color:navy.withValues(alpha:.13),
          child:Image.network(image(item),fit:BoxFit.cover,
            errorBuilder:(_,__,___)=>Container(
              decoration:const BoxDecoration(gradient:LinearGradient(
                colors:[Color(0xFF13295C),Color(0xFF4E6A94)])),
              child:const Center(child:Icon(Icons.landscape_outlined,
                color:Colors.white,size:62))))),
        Container(decoration:BoxDecoration(gradient:LinearGradient(
          begin:Alignment.topCenter,end:Alignment.bottomCenter,
          colors:[Colors.transparent,Colors.black.withValues(alpha:.34)]))),
        Center(child:Container(padding:const EdgeInsets.all(12),
          decoration:BoxDecoration(color:Colors.white.withValues(alpha:.94),
            borderRadius:BorderRadius.circular(100)),
          child:const Icon(Icons.play_arrow_rounded,color:coral,size:28))),
        Positioned(bottom:10,right:10,child:Container(
          padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),
          decoration:BoxDecoration(color:Colors.black.withValues(alpha:.72),
            borderRadius:BorderRadius.circular(7)),
          child:Text(str(item['duration']),style:const TextStyle(
            color:Colors.white,fontSize:10,fontWeight:FontWeight.w700))))
      ]));
  }

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
    final raw = isDemo(item) ? str(item['videoUrl']) : str(item['youtubeUrl']);
    final uri = Uri.tryParse(raw);
    if(uri != null && uri.scheme=='https') {
      await launchUrl(uri,mode:LaunchMode.externalApplication);
    } else {
      inform('A share link is not available.');
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
    final tops=items.take(5).toList();
    return SizedBox(height:91,child:ListView(
      scrollDirection:Axis.horizontal,children:[
        Padding(padding:const EdgeInsets.only(right:14),
          child:GestureDetector(onTap:widget.onCreate,
            child:Column(children:[
              CircleAvatar(radius:29,backgroundColor:coral.withValues(alpha:.1),
                child:const Icon(Icons.add_rounded,color:coral)),
              const SizedBox(height:5),
              const Text('Your story',style:TextStyle(color:navy,fontSize:11))
            ]))),
        for(final item in tops) Padding(padding:const EdgeInsets.only(right:14),
          child:GestureDetector(onTap:()=>play(item),child:Column(children:[
            Container(width:62,height:62,padding:const EdgeInsets.all(3),
              decoration:BoxDecoration(shape:BoxShape.circle,
                border:Border.all(color:coral,width:2)),
              child:ClipOval(child:Image.network(image(item),fit:BoxFit.cover,
                errorBuilder:(_,__,___)=>const ColoredBox(color:soft,
                  child:Icon(Icons.person_outline,color:navy))))),
            const SizedBox(height:4),
            Text(str(item['category']),style:const TextStyle(
              color:navy,fontSize:10))
          ])))
      ]));
  }

  Widget home() {
    List<Map<String,dynamic>> list=List.from(items);
    if(feedChoice=='Following') {
      list=list.where((item)=>following.contains(
        str(item['creatorId']).isEmpty ? str(item['creator']) : str(item['creatorId']))).toList();
    } else if(feedChoice=='Fresh') {
      list=list.reversed.toList();
    }
    return RefreshIndicator(color:coral,onRefresh:refresh,
      child:ListView(padding:const EdgeInsets.fromLTRB(17,16,17,24),children:[
        Row(children:[
          const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
            children:[
              Text('YOUR CORNER OF THE INTERNET',style:TextStyle(
                color:coral,fontWeight:FontWeight.w800,fontSize:10,letterSpacing:1)),
              SizedBox(height:5),
              Text('Find your next spark.',style:TextStyle(
                color:navy,fontSize:25,fontWeight:FontWeight.w900))
            ])),
          IconButton(onPressed:refresh,icon:const Icon(Icons.refresh_rounded,color:navy))
        ]),
        const SizedBox(height:12),
        if(loadError!=null) Padding(padding:const EdgeInsets.only(bottom:8),
          child:Text(loadError!,style:const TextStyle(color:slate,fontSize:11))),
        Wrap(spacing:8,children:[
          for(final option in ['For you','Following','Fresh'])
            ChoiceChip(label:Text(option),selected:feedChoice==option,
              selectedColor:coral.withValues(alpha:.14),
              onSelected:(_)=>setState(()=>feedChoice=option))
        ]),
        sectionTitle('Your circle',trailing:'Discover',onTap:()=>widget.onNavigate('Explore')),
        stories(),
        const SizedBox(height:12),
        GestureDetector(onTap:()=>play(items.first),
          child:Container(height:126,clipBehavior:Clip.antiAlias,
            decoration:BoxDecoration(color:navy,
              borderRadius:BorderRadius.circular(20)),
            child:Stack(children:[
              Positioned.fill(child:Opacity(opacity:.35,
                child:Image.network(image(items.first),fit:BoxFit.cover,
                  errorBuilder:(_,__,___)=>const SizedBox.shrink()))),
              const Positioned(left:17,top:19,child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text("TODAY'S SPARK",style:TextStyle(
                    color:Color(0xFFFFB7AB),fontSize:10,fontWeight:FontWeight.w900)),
                  SizedBox(height:8),
                  Text('Stories that take\nyou places.',style:TextStyle(
                    color:Colors.white,fontWeight:FontWeight.w900,fontSize:20)),
                ])),
              const Positioned(right:22,bottom:23,
                child:Icon(Icons.play_circle_fill_rounded,color:Colors.white,size:44)),
            ]))),
        sectionTitle('Fresh from the community',
          trailing:loading?'Loading…':null),
        if(list.isEmpty) Padding(padding:const EdgeInsets.symmetric(vertical:24),
          child:Column(children:[
            const Text('Your following feed is getting started.',
              style:TextStyle(color:slate)),
            const SizedBox(height:10),
            TextButton(onPressed:()=>setState(()=>feedChoice='For you'),
              child:const Text('Explore all stories'))
          ])),
        for(final item in list)postCard(item)
      ]));
  }

  Widget explore() {
    final term=search.text.trim().toLowerCase();
    final filtered=items.where((item)=>
      (category=='All'||str(item['category'])==category) &&
      (term.isEmpty||[
        item['title'],item['description'],item['category'],item['creator']
      ].any((value)=>str(value).toLowerCase().contains(term)))).toList();
    return ListView(padding:const EdgeInsets.fromLTRB(17,19,17,28),children:[
      const Text('Explore your world',style:TextStyle(
        fontSize:26,fontWeight:FontWeight.w900,color:navy)),
      const SizedBox(height:6),
      const Text('Curiosity looks good on you.',style:TextStyle(color:slate)),
      const SizedBox(height:18),
      TextField(controller:search,onChanged:(_)=>setState((){}),
        decoration:InputDecoration(
          prefixIcon:const Icon(Icons.search_rounded,color:navy),
          hintText:'Creators, videos, topics…',
          fillColor:Colors.white,filled:true,
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(16)))),
      const SizedBox(height:14),
      SingleChildScrollView(scrollDirection:Axis.horizontal,
        child:Row(children:[
          for(final t in ['All','Travel','Art','Lifestyle','Storytelling','Stories'])
            Padding(padding:const EdgeInsets.only(right:7),
              child:ChoiceChip(label:Text(t),selected:category==t,
                selectedColor:coral.withValues(alpha:.15),
                onSelected:(_)=>setState(()=>category=t)))
        ])),
      sectionTitle('Trending discoveries'),
      if(filtered.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:25),
        child:Text('Nothing matches this search. Try another topic.',
          style:TextStyle(color:slate))),
      for(final item in filtered)
        Padding(padding:const EdgeInsets.only(bottom:10),
          child:InkWell(onTap:()=>play(item),
            borderRadius:BorderRadius.circular(17),
            child:card(Row(children:[
              SizedBox(width:113,height:96,child:thumbnail(item)),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,
                children:[
                  Text(str(item['title']),maxLines:2,overflow:TextOverflow.ellipsis,
                    style:const TextStyle(color:navy,fontWeight:FontWeight.w800)),
                  const SizedBox(height:5),
                  Text(str(item['category'])+' · '+str(item['creator']),
                    style:const TextStyle(color:slate,fontSize:11)),
                  const SizedBox(height:7),
                  pill(isDemo(item)?'SAMPLE':'PUBLISHED',
                    isDemo(item)?coral:success)
                ]))
            ]),pad:const EdgeInsets.all(10)))),
      sectionTitle('Creators to know'),
      card(Column(children:[
        for(final item in items.take(3))
          ListTile(contentPadding:EdgeInsets.zero,
            leading:CircleAvatar(backgroundColor:coral.withValues(alpha:.12),
              child:const Icon(Icons.person,color:coral)),
            title:Text(str(item['creator']),style:const TextStyle(
              fontWeight:FontWeight.w800,color:navy)),
            subtitle:Text(str(item['category'])+' stories',
              style:const TextStyle(fontSize:11)),
            trailing:TextButton(onPressed:()=>follow(item),child:const Text('Follow')))
      ]))
    ]);
  }

  Widget shorts() {
    if(items.isEmpty)return const Center(child:CircularProgressIndicator());
    return PageView.builder(controller:shortsPager,
      scrollDirection:Axis.vertical,
      onPageChanged:(i)=>setState(()=>shortIndex=i),
      itemCount:items.length,
      itemBuilder:(context,index) {
        final post=items[index],key=id(post);
        return Stack(fit:StackFit.expand,children:[
          Container(color:navy,child:Image.network(image(post),
            fit:BoxFit.cover,errorBuilder:(_,__,___)=>const ColoredBox(
              color:Color(0xFF142B5B),
              child:Center(child:Icon(Icons.movie_outlined,
                color:Colors.white,size:80))))),
          Container(decoration:BoxDecoration(gradient:LinearGradient(
            begin:Alignment.topCenter,end:Alignment.bottomCenter,
            colors:[Colors.black.withValues(alpha:.25),Colors.transparent,
              Colors.black.withValues(alpha:.84)]))),
          Positioned(top:23,left:20,right:15,child:Row(children:[
            const Text('Shorts',style:TextStyle(color:Colors.white,
              fontSize:22,fontWeight:FontWeight.w900)),
            const Spacer(),pill('DEMO & REAL',Colors.white)
          ])),
          Center(child:IconButton(onPressed:()=>play(post),
            icon:const Icon(Icons.play_circle_fill_rounded,
              size:75,color:Colors.white))),
          Positioned(bottom:30,left:20,right:68,child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[
                const CircleAvatar(radius:17,backgroundColor:coral,
                  child:Icon(Icons.people_rounded,color:Colors.white,size:19)),
                const SizedBox(width:8),
                Expanded(child:Text(str(post['creator']),style:const TextStyle(
                  color:Colors.white,fontWeight:FontWeight.w800))),
              ]),
              const SizedBox(height:10),
              Text(str(post['title']),style:const TextStyle(
                color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),
              const SizedBox(height:6),
              Text(str(post['description']),maxLines:2,
                style:const TextStyle(color:Colors.white70,fontSize:12)),
              if(isDemo(post))const Padding(padding:EdgeInsets.only(top:8),
                child:Text('SAMPLE VIDEO · preview only',style:TextStyle(
                  color:Color(0xFFFFB1A6),fontSize:11)))
            ])),
          Positioned(right:10,bottom:65,child:Column(children:[
            _shortAction(liked.contains(key)?Icons.favorite:Icons.favorite_border,
              compact(post['likes']),()=>like(post)),
            _shortAction(Icons.mode_comment_outlined,
              compact(post['comments']),()=>openComments(post)),
            _shortAction(saved.contains(key)?Icons.bookmark:Icons.bookmark_border,
              'Save',()=>save(post)),
            _shortAction(Icons.share_outlined,'Share',()=>share(post)),
          ]))
        ]);
      });
  }

  Widget _shortAction(IconData icon,String caption,VoidCallback tap) =>
    Padding(padding:const EdgeInsets.only(bottom:12),child:Column(children:[
      IconButton(onPressed:tap,icon:Icon(icon,size:29,color:Colors.white)),
      Text(caption,style:const TextStyle(color:Colors.white,fontSize:11,
        fontWeight:FontWeight.w700))
    ]));

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

  Widget profile() => ListView(padding:const EdgeInsets.all(19),children:[
    const SizedBox(height:6),
    card(Column(children:[
      const CircleAvatar(radius:39,backgroundColor:soft,
        child:Icon(Icons.person_outline_rounded,size:43,color:navy)),
      const SizedBox(height:13),
      Text(widget.api.signedIn?'Your WeuTube space':'Join the community',
        style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900,color:navy)),
      const SizedBox(height:6),
      Text(widget.api.signedIn
        ? 'Manage content, performance and verified payouts.'
        : 'Follow creators, join conversations and share your own stories.',
        textAlign:TextAlign.center,style:const TextStyle(color:slate)),
      const SizedBox(height:17),
      if(!widget.api.signedIn)
        SizedBox(width:double.infinity,child:FilledButton(
          onPressed:widget.onSignIn,
          style:FilledButton.styleFrom(backgroundColor:coral),
          child:const Text('Sign in or create an account'))),
      if(widget.api.signedIn)
        SizedBox(width:double.infinity,child:FilledButton.icon(
          onPressed:widget.onStudio,icon:const Icon(Icons.dashboard_outlined),
          style:FilledButton.styleFrom(backgroundColor:coral),
          label:const Text('Open Creator Studio')))
    ])),
    sectionTitle('Your collection'),
    card(Column(children:[
      ListTile(leading:const Icon(Icons.bookmarks_outlined,color:coral),
        title:const Text('Saved stories'),
        trailing:Text(saved.length.toString(),style:const TextStyle(
          color:navy,fontWeight:FontWeight.w900)),
        onTap:()=>widget.onNavigate('Saved')),
      ListTile(leading:const Icon(Icons.people_alt_outlined,color:coral),
        title:const Text('Following'),
        trailing:Text(following.length.toString(),style:const TextStyle(
          color:navy,fontWeight:FontWeight.w900)),
        onTap:()=>widget.onNavigate('Following'))
    ])),
    sectionTitle('Creator tools'),
    card(Column(children:[
      for(final entry in [
        ['My Videos',Icons.video_library_outlined],
        ['Analytics',Icons.bar_chart_rounded],
        ['Wallet',Icons.account_balance_wallet_outlined],
        ['Settings',Icons.settings_outlined]
      ])
        ListTile(leading:Icon(entry[1] as IconData,color:navy),
          title:Text(entry[0] as String),
          trailing:const Icon(Icons.chevron_right,color:slate),
          onTap:()=>widget.api.signedIn?
            widget.onNavigate(entry[0] as String):widget.onSignIn())
    ])),
    const SizedBox(height:16),
    const Text('Demo posts and interactions are for preview only. Real content and earnings are never fabricated.',
      textAlign:TextAlign.center,style:TextStyle(color:slate,fontSize:11))
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
