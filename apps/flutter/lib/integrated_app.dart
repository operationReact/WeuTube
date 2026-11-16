import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'backend_client.dart';
import 'admin_panel.dart';
import 'social_feed.dart';
import 'product_ui.dart' show WeuTubeBrand, navy, coral, soft, slate, success;

/// Responsive production API-connected creator experience for Android, iOS and web.
class WeuTubeIntegratedApp extends StatefulWidget {
  const WeuTubeIntegratedApp({super.key});
  @override
  State<WeuTubeIntegratedApp> createState() => _WeuTubeIntegratedAppState();
}

class _WeuTubeIntegratedAppState extends State<WeuTubeIntegratedApp> {
  final api = WeuTubeApi();
  final email = TextEditingController(), password = TextEditingController();
  final fullName = TextEditingController(), code = TextEditingController();
  final title = TextEditingController(), channelId = TextEditingController();
  final displayName = TextEditingController();
  final form = GlobalKey<FormState>();

  String page = 'Home', challenge = '', challengeSession = '';
  String afterLogin = 'Home';
  String videoFilter = 'All', selectedVideo = '';
  bool busy = false, showPassword = false;
  Map<String,dynamic> dashboardData = {}, walletData = {}, analyticsData = {}, profileData = {};
  List<Map<String,dynamic>> videoData = [], notificationData = [], withdrawalData = [];
  String error = '';
  PlatformFile? selectedFile;
  static const nav = ['Dashboard','Upload Video','My Videos','Analytics',
    'Earnings','Wallet','Notifications','Profile','Settings'];
  static const navIcons = [Icons.dashboard_outlined,Icons.cloud_upload_outlined,
    Icons.video_library_outlined,Icons.insights_outlined,Icons.paid_outlined,
    Icons.account_balance_wallet_outlined,Icons.notifications_none,
    Icons.person_outline,Icons.settings_outlined];

  @override
  void dispose() {
    for(final input in [email,password,fullName,code,title,channelId,displayName]) {
      input.dispose();
    }
    api.dispose();
    super.dispose();
  }

  void message(String msg) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  Future<void> perform(Future<void> Function() operation) async {
    if(busy) return;
    setState(() {busy=true;error='';});
    try {await operation();}
    on ApiFailure catch(ex) {if(mounted) setState(() => error=ex.message);}
    catch(_) {if(mounted) setState(() => error='Something went wrong. Try again.');}
    finally {if(mounted) setState(() => busy=false);}
  }
  Future<void> navigate(String p) async {
    if(!api.signedIn && (nav.contains(p) || p == 'Admin Operations')) {
      afterLogin=p;
      setState(() {page='Sign In';error='';});
      return;
    }
    setState(() {page=p;error='';});
    if(!api.signedIn || !nav.contains(p)) return;
    await perform(() async {
      switch(p) {
        case 'Dashboard':
          dashboardData=await api.dashboard();
          break;
        case 'My Videos':
          videoData=await api.videos();
          break;
        case 'Analytics':
          analyticsData=await api.analytics();
          break;
        case 'Earnings':
        case 'Wallet':
          walletData=await api.wallet();
          withdrawalData=await api.withdrawals();
          break;
        case 'Notifications':
          notificationData=await api.notifications();
          break;
        case 'Profile':
          profileData=await api.profile();
          displayName.text=profileData['displayName']?.toString() ?? '';
          break;
      }
    });
  }
  Future<void> signIn() => perform(() async {
    if(!(form.currentState?.validate() ?? false)) return;
    final result=await api.login(email.text.trim(),password.text);
    if(!mounted) return;
    if(result['status']=='CHALLENGE_REQUIRED') {
      challenge=result['challenge']?.toString()??'';
      challengeSession=result['session']?.toString()??'';
      setState(() => page='MFA');
    } else {
      await navigate(afterLogin);
      afterLogin='Home';
    }
  });
  Future<void> signUp() => perform(() async {
    if(!(form.currentState?.validate() ?? false)) return;
    if(password.text.length<12) throw const ApiFailure('Password needs at least 12 characters.');
    final result=await api.signUp(fullName.text.trim(),email.text.trim(),password.text);
    if(!mounted) return;
    setState(() => page=result['status']=='CONFIRMED'?'Sign In':'Confirm Email');
    message(result['status']=='CONFIRMED'?'Account created. Sign in.':'Enter the verification code emailed by Cognito.');
  });
  Future<void> signOut() => perform(() async {
    try {await api.logout();}
    finally {
      if(mounted) setState(() {
        page='Home';dashboardData={};walletData={};videoData=[];
        password.clear();challenge='';challengeSession='';
      });
    }
  });
  Widget button(String label,VoidCallback onPressed,
      {bool secondary=false,IconData? icon}) {
    final child=Row(mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,children: [
        if(icon!=null) ...[Icon(icon,size:19),const SizedBox(width:7)],
        Text(label,style:const TextStyle(fontWeight:FontWeight.w700))]);
    return secondary
      ? OutlinedButton(onPressed:busy?null:onPressed,
          style:OutlinedButton.styleFrom(foregroundColor:navy,
            side:const BorderSide(color:navy),
            padding:const EdgeInsets.symmetric(vertical:14,horizontal:16)),
          child:child)
      : FilledButton(onPressed:busy?null:onPressed,
          style:FilledButton.styleFrom(backgroundColor:coral,foregroundColor:Colors.white,
            padding:const EdgeInsets.symmetric(vertical:14,horizontal:16)),
          child:child);
  }
  Widget panel(Widget child) => Container(
    padding:const EdgeInsets.all(18),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(18),
      border:Border.all(color:const Color(0xFFE7ECF4))),
    child:child);
  Widget heading(String h,String sub) => Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(h,style:const TextStyle(fontSize:25,fontWeight:FontWeight.w900,color:navy)),
      const SizedBox(height:5),Text(sub,style:const TextStyle(color:slate,fontSize:13))
    ]);
  Widget field(String label,TextEditingController input,{bool secret=false,int lines=1,
    bool required=true}) => Padding(padding:const EdgeInsets.only(bottom:14),
    child:TextFormField(controller:input,maxLines:lines,
      obscureText:secret&&!showPassword,
      validator: required ? (v)=>(v==null||v.trim().isEmpty)?'Enter '+label:null : null,
      decoration:InputDecoration(labelText:label,filled:true,fillColor:Colors.white,
        suffixIcon:secret?IconButton(onPressed:()=>setState(()=>showPassword=!showPassword),
          icon:Icon(showPassword?Icons.visibility_off_outlined:Icons.visibility_outlined)):null)));
  Widget notice(String text) => panel(Row(children:[
    const Icon(Icons.info_outline,color:navy),const SizedBox(width:10),
    Expanded(child:Text(text,style:const TextStyle(color:slate,fontSize:13)))]));
  Widget banner() => error.isEmpty?const SizedBox.shrink():
    Padding(padding:const EdgeInsets.only(bottom:14),
      child:Container(width:double.infinity,padding:const EdgeInsets.all(12),
        decoration:BoxDecoration(color:coral.withValues(alpha:.09),
          borderRadius:BorderRadius.circular(10)),
        child:Text(error,style:const TextStyle(color:navy,fontWeight:FontWeight.w600))));
  Widget statistic(String name,String value,IconData icon) => panel(Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Icon(icon,color:coral),const SizedBox(height:12),
      Text(name,style:const TextStyle(color:slate,fontSize:12)),
      const SizedBox(height:4),
      Text(value,style:const TextStyle(color:navy,fontSize:23,fontWeight:FontWeight.w900))
    ]));
  Widget metrics(double width,List<Widget> items) => GridView.count(
    shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
    crossAxisCount:width>=750?4:2,
    childAspectRatio:width>=750?1.55:1.22,
    mainAxisSpacing:10,crossAxisSpacing:10,children:items);
  String money(dynamic minor) {
    final amount=minor is num?minor.toDouble():0.0;
    return '₹'+(amount/100).toStringAsFixed(2);
  }

  Widget landing(double width) {
    final headline=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('A CREATOR-FIRST COMMUNITY',style:TextStyle(color:coral,
        fontWeight:FontWeight.w900,fontSize:12)),
      const SizedBox(height:16),
      Text('Create. Connect.\nGrow together.',style:TextStyle(fontSize:width>850?48:34,
        color:navy,fontWeight:FontWeight.w900,height:1.13)),
      const SizedBox(height:18),
      const Text('Your stories deserve an audience. Manage your videos, review status and verified earnings in one place.',
        style:TextStyle(color:slate,fontSize:15,height:1.6)),
      const SizedBox(height:24),
      Wrap(spacing:12,runSpacing:12,children:[
        button('Create Account',()=>navigate('Create Account')),
        button('Sign In',()=>navigate('Sign In'),secondary:true)
      ])
    ]);
    final preview=panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Row(children:[Icon(Icons.groups,color:coral),SizedBox(width:9),
        Text('Your creator space',style:TextStyle(color:navy,
          fontSize:18,fontWeight:FontWeight.w900))]),
      const SizedBox(height:24),
      const Text('Upload your story',style:TextStyle(color:navy,fontWeight:FontWeight.w700)),
      const SizedBox(height:10),
      const LinearProgressIndicator(value:.75,color:coral,backgroundColor:soft),
      const SizedBox(height:20),
      const Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        Icon(Icons.cloud_upload_outlined,color:coral),
        Icon(Icons.arrow_forward,color:slate),
        Icon(Icons.fact_check_outlined,color:navy),
        Icon(Icons.arrow_forward,color:slate),
        Icon(Icons.public_outlined,color:success)]),
      const SizedBox(height:15),
      const Text('Create → Review → Publish',style:TextStyle(color:slate)),
      const SizedBox(height:16),
      const Text('Creator-first workflow',style:TextStyle(color:navy,
        fontSize:16,fontWeight:FontWeight.w800))
    ]));
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const SizedBox(height:34),
      width>850?Row(children:[Expanded(child:headline),const SizedBox(width:30),
        Expanded(child:preview)]):Column(children:[headline,const SizedBox(height:25),preview]),
      const SizedBox(height:42),heading('Built for creators','Everything in one connected workspace.'),
      const SizedBox(height:18),
      Wrap(spacing:12,runSpacing:12,children:[
        SizedBox(width:250,child:panel(const Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.video_library_outlined,color:coral),SizedBox(height:12),
          Text('Video Management',style:TextStyle(color:navy,fontWeight:FontWeight.w900)),
          Text('Draft, upload and track reviews.',style:TextStyle(color:slate))]))),
        SizedBox(width:250,child:panel(const Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.bar_chart,color:coral),SizedBox(height:12),
          Text('Real Analytics',style:TextStyle(color:navy,fontWeight:FontWeight.w900)),
          Text('Views and engagement from YouTube.',style:TextStyle(color:slate))]))),
        SizedBox(width:250,child:panel(const Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(Icons.account_balance_wallet_outlined,color:coral),SizedBox(height:12),
          Text('Verified Earnings',style:TextStyle(color:navy,fontWeight:FontWeight.w900)),
          Text('No invented revenue estimates.',style:TextStyle(color:slate))])))
      ])
    ]);
  }

  Widget auth() {
    final signup=page=='Create Account';
    final confirm=page=='Confirm Email';
    final forgot=page=='Forgot Password';
    final reset=page=='Reset Password';
    final mfa=page=='MFA';
    final signInPage=page=='Sign In';
    String titleText=signup?'Create Account':confirm?'Verify Your Email':
      forgot?'Forgot Password':reset?'Reset Password':mfa?'Confirm Security Code':'Welcome Back';
    return Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),
      child:panel(Form(key:form,child:Column(
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Center(child:WeuTubeBrand(size:28)),
          const SizedBox(height:24),heading(titleText,'Secure WeuTube creator account'),
          const SizedBox(height:24),
          if(signup) field('Full Name',fullName),
          if(!reset&&!mfa) field('Email Address',email),
          if(signInPage||signup) field('Password',password,secret:true),
          if(confirm||reset||mfa) field('Verification Code',code),
          if(reset) field('New Password',password,secret:true),
          if(signInPage) Align(alignment:Alignment.centerRight,
            child:TextButton(onPressed:()=>navigate('Forgot Password'),
              child:const Text('Forgot password?'))),
          if(signInPage) button('Sign In',signIn),
          if(signup) button('Create Account',signUp),
          if(confirm) button('Confirm Email',()=>perform(() async {
            await api.confirm(email.text.trim(),code.text.trim());
            code.clear();await navigate('Sign In');
            message('Email confirmed. Please sign in.');
          })),
          if(forgot) button('Send Reset Code',()=>perform(() async {
            await api.forgot(email.text.trim());
            await navigate('Reset Password');
            message('If the account exists, a reset code has been sent.');
          })),
          if(reset) button('Update Password',()=>perform(() async {
            await api.reset(email.text.trim(),code.text.trim(),password.text);
            password.clear();code.clear();
            await navigate('Sign In');message('Password updated.');
          })),
          if(mfa) button('Verify Code',()=>perform(() async {
            final r=await api.completeMfa(email.text.trim(),challengeSession,
              challenge,code.text.trim());
            if(r['status']=='SIGNED_IN') {
              await navigate(afterLogin);
              afterLogin='Home';
            }
          })),
          const SizedBox(height:12),
          if(confirm) TextButton(onPressed:()=>perform(() async {
            await api.resend(email.text.trim());message('A new code was requested.');
          }),child:const Text('Resend verification code')),
          TextButton(onPressed:()=>navigate(signup?'Sign In':'Create Account'),
            child:Text(signup?'Already registered? Sign In':'New creator? Create Account'))
        ])))));
  }

  Widget dashboard(double width) => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    heading('Creator Dashboard','Account-specific content from the WeuTube API.'),
    const SizedBox(height:17),
    metrics(width,[
      statistic('My Videos',(dashboardData['videos']??0).toString(),Icons.video_library_outlined),
      statistic('Drafts',(dashboardData['drafts']??0).toString(),Icons.edit_note),
      statistic('Awaiting Review',(dashboardData['pendingReview']??0).toString(),Icons.fact_check_outlined),
      statistic('Published',(dashboardData['published']??0).toString(),Icons.public_outlined)
    ]),
    const SizedBox(height:18),
    panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Your publishing journey',style:TextStyle(
        color:navy,fontSize:18,fontWeight:FontWeight.w900)),
      const SizedBox(height:10),
      const Text('Create a draft, upload privately to an authorized YouTube channel, then track review and publication.',
        style:TextStyle(color:slate)),
      const SizedBox(height:15),
      button('Create Video Draft',()=>navigate('Upload Video'),icon:Icons.add_circle_outline)
    ])),
    const SizedBox(height:15),
    notice('Views and subscriber data are not estimated here. Open Analytics to retrieve available YouTube statistics.')
  ]);

  Widget videos() {
    final filtered=videoData.where((v)=>videoFilter=='All'||
      v['status']==videoFilter).toList();
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      heading('My Videos','Live submissions for your signed-in creator account.'),
      const SizedBox(height:16),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        for(final s in ['All','DRAFT','UPLOADING','PRIVATE_REVIEW','APPROVED','PUBLISHED','REJECTED']) ...[
          Padding(padding:const EdgeInsets.only(right:7),
            child:ChoiceChip(label:Text(s.replaceAll('_',' ')),
              selected:videoFilter==s,
              onSelected:(_)=>setState(()=>videoFilter=s)))
        ]
      ])),
      const SizedBox(height:15),
      if(filtered.isEmpty) notice('No videos in this category. Create your first draft to begin.'),
      for(final v in filtered)
        Padding(padding:const EdgeInsets.only(bottom:10),
          child:panel(Row(children:[
            const Icon(Icons.movie_creation_outlined,color:coral),
            const SizedBox(width:12),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(v['title']?.toString()??'Untitled',
                style:const TextStyle(color:navy,fontWeight:FontWeight.w800)),
              Text(v['status']?.toString()??'UNKNOWN',
                style:const TextStyle(color:slate,fontSize:12))])),
            IconButton(onPressed:(){
              selectedVideo=v['id'].toString();navigate('Video Details');
            },icon:const Icon(Icons.chevron_right))
          ]))),
      const SizedBox(height:12),
      button('New Draft',()=>navigate('Upload Video'),icon:Icons.add)
    ]);
  }

  Widget videoDetail() => FutureBuilder<Map<String,dynamic>>(
    future:api.video(selectedVideo),
    builder:(context,snapshot) {
      if(snapshot.hasError) return notice('Unable to retrieve video details.');
      if(!snapshot.hasData) return const Center(child:CircularProgressIndicator());
      final v=snapshot.data!;
      return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        heading(v['title']?.toString()??'Video Details','Ownership and review status'),
        const SizedBox(height:16),
        panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Status: '+(v['status']?.toString()??'Unknown'),
            style:const TextStyle(color:navy,fontWeight:FontWeight.w800)),
          const SizedBox(height:10),
          Text('YouTube Video ID: '+(v['youtubeVideoId']?.toString()??'Not uploaded'),
            style:const TextStyle(color:slate)),
          if(v['rejectionReason']!=null) Text('Review feedback: '+v['rejectionReason'].toString(),
            style:const TextStyle(color:coral)),
        ])),const SizedBox(height:12),
        button('Back to My Videos',()=>navigate('My Videos'),secondary:true)
      ]);
    });

  Widget upload() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    heading('Upload Video','Draft first, then privately upload to an authorized channel.'),
    const SizedBox(height:17),
    panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      field('Video Title',title),
      field('Authorized YouTube Channel ID',channelId),
      button(selectedFile==null?'Choose Video (max 20 MB)':
        'Selected: '+selectedFile!.name,()=>perform(() async {
        final picked=await FilePicker.platform.pickFiles(type:FileType.video,
          withData:true,allowMultiple:false);
        if(picked!=null&&picked.files.isNotEmpty) {
          final candidate=picked.files.first;
          if(candidate.size>20*1024*1024) {
            throw const ApiFailure('Testing build supports videos up to 20 MB.');
          }
          setState(()=>selectedFile=candidate);
        }
      }),secondary:true,icon:Icons.video_file_outlined),
      const SizedBox(height:14),
      button('Create Draft & Upload Privately',()=>perform(() async {
        if(title.text.trim().isEmpty) throw const ApiFailure('Enter a title.');
        if(channelId.text.trim().isEmpty) throw const ApiFailure('Enter a connected YouTube channel ID.');
        final file=selectedFile;
        if(file==null||file.bytes==null) throw const ApiFailure('Select a video file first.');
        final draft=await api.createDraft(title.text.trim());
        final id=draft['id']?.toString();
        if(id==null) throw const ApiFailure('Draft creation did not return an ID.');
        message('Draft saved. Starting private upload.');
        await api.upload(id,channelId.text.trim(),file.bytes!,file.name);
        if(!mounted) return;
        title.clear();selectedFile=null;
        message('Video uploaded privately and queued for admin review.');
        await navigate('My Videos');
      }),icon:Icons.cloud_upload_outlined),
      const SizedBox(height:15),
      const Text('Upload only content you own or are authorized to distribute. A channel admin must grant you upload permission. Public publishing requires separate approval.',
        style:TextStyle(color:slate,fontSize:12))
    ]))
  ]);

  Widget analytics(double width) => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    heading('Analytics','Verified YouTube Data API metrics, not estimated earnings.'),
    const SizedBox(height:16),
    metrics(width,[
      statistic('Views',(analyticsData['views']??0).toString(),Icons.visibility_outlined),
      statistic('Likes',(analyticsData['likes']??0).toString(),Icons.thumb_up_outlined),
      statistic('Comments',(analyticsData['comments']??0).toString(),Icons.comment_outlined),
      statistic('Verified Videos',(analyticsData['verifiedVideos']??0).toString(),Icons.verified_outlined)
    ]),
    const SizedBox(height:17),
    notice(analyticsData['partial']==true
      ? 'Some YouTube videos could not be verified. Totals are partial.'
      : 'Source: '+(analyticsData['source']?.toString()??'Not connected')),
    const SizedBox(height:12),button('Refresh',()=>navigate('Analytics'),secondary:true)
  ]);

  Widget wallet(double width) => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    heading(page,'Only verified, ledger-backed balances are displayed.'),
    const SizedBox(height:17),
    Container(width:double.infinity,padding:const EdgeInsets.all(24),
      decoration:BoxDecoration(color:navy,borderRadius:BorderRadius.circular(18)),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Available Balance',style:TextStyle(color:Colors.white70)),
        const SizedBox(height:8),
        Text(money(walletData['availableMinor']),
          style:const TextStyle(color:Colors.white,fontSize:32,fontWeight:FontWeight.w900)),
        const SizedBox(height:5),
        Text('Verified '+money(walletData['verifiedMinor'])+'  ·  Reserved '+money(walletData['reservedMinor']),
          style:const TextStyle(color:Colors.white70,fontSize:12))
      ])),
    const SizedBox(height:18),
    heading('Withdrawal History','Bank transfers are not enabled until payout setup is complete.'),
    const SizedBox(height:14),
    if(withdrawalData.isEmpty) notice('No withdrawal requests yet.'),
    for(final w in withdrawalData)
      Padding(padding:const EdgeInsets.only(bottom:8),
        child:panel(Row(children:[
          const Icon(Icons.account_balance_wallet_outlined,color:coral),
          const SizedBox(width:10),
          Expanded(child:Text(money(w['amountMinor']),style:const TextStyle(color:navy,
            fontWeight:FontWeight.w700))),
          Text(w['status']?.toString()??'',style:const TextStyle(color:slate))
        ]))),
    const SizedBox(height:12),
    button('Refresh Wallet',()=>navigate('Wallet'),secondary:true)
  ]);

  Widget notifications() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    heading('Notifications','Review and withdrawal activity from your account.'),
    const SizedBox(height:16),
    if(notificationData.isEmpty) notice('No account notifications yet.'),
    for(final n in notificationData)
      Padding(padding:const EdgeInsets.only(bottom:9),
        child:panel(ListTile(contentPadding:EdgeInsets.zero,
          leading:const Icon(Icons.notifications_none,color:coral),
          title:Text(n['title']?.toString()??'Update'),
          subtitle:Text(n['message']?.toString()??''))))
  ]);

  Widget profile() => Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    heading('Profile','Your authenticated WeuTube creator account.'),
    const SizedBox(height:18),
    panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Center(child:CircleAvatar(radius:34,backgroundColor:soft,
        child:Icon(Icons.person_outline,size:40,color:navy))),
      const SizedBox(height:15),
      Text('Subject: '+(profileData['subject']?.toString()??''),
        style:const TextStyle(color:slate,fontSize:11)),
      const SizedBox(height:15),
      field('Display Name',displayName),
      button('Save Profile',()=>perform(() async {
        if(displayName.text.trim().isEmpty) throw const ApiFailure('Enter your display name.');
        profileData=await api.updateProfile(displayName.text.trim());
        message('Profile saved.');
      }))
    ]))
  ]);

  Widget content(double width) {
    if(!api.signedIn) {
      if(['Sign In','Create Account','Confirm Email','Forgot Password','Reset Password','MFA'].contains(page)) {
        return auth();
      }
      return landing(width);
    }
    switch(page) {
      case 'Dashboard':return dashboard(width);
      case 'Upload Video':return upload();
      case 'My Videos':return videos();
      case 'Video Details':return videoDetail();
      case 'Analytics':return analytics(width);
      case 'Wallet':
      case 'Earnings':return wallet(width);
      case 'Notifications':return notifications();
      case 'Profile':return profile();
      case 'Admin Operations':return WeuTubeAdminPanel(api:api);
      case 'Settings':return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        heading('Settings','Account and session controls'),
        const SizedBox(height:16),notice('Tokens are retained only in memory for this testing build.'),
        const SizedBox(height:16),button('Sign Out',signOut)]);
      default:return dashboard(width);
    }
  }

  Widget sideNav() => Container(width:235,color:Colors.white,
    child:ListView(padding:const EdgeInsets.all(10),children:[
      for(int i=0;i<nav.length;i++)
        ListTile(
          selected:page==nav[i],selectedTileColor:navy.withValues(alpha:.07),
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),
          leading:Icon(navIcons[i],color:page==nav[i]?coral:navy),
          title:Text(nav[i],style:const TextStyle(fontSize:13)),
          onTap:()=>navigate(nav[i])),
      if(api.showAdminMenu) ListTile(leading:const Icon(Icons.admin_panel_settings_outlined,color:coral),
        title:const Text('Admin Operations'),onTap:()=>navigate('Admin Operations')),
      const Divider(),
      ListTile(leading:const Icon(Icons.logout,color:coral),
        title:const Text('Sign Out'),onTap:signOut)
    ]));

  static const socialPages = [
    'Home', 'Explore', 'Shorts', 'Create', 'You', 'Saved', 'Following'
  ];
  static const authPages = [
    'Sign In','Create Account','Confirm Email',
    'Forgot Password','Reset Password','MFA'
  ];

  void createFromSocial() {
    if(api.signedIn) {
      navigate('Upload Video');
    } else {
      afterLogin='Upload Video';
      navigate('Sign In');
    }
  }

  @override
  Widget build(BuildContext context) {
    final width=MediaQuery.sizeOf(context).width;
    final wide=width>=850;
    final isSocial=socialPages.contains(page);
    final isAuth=authPages.contains(page);
    const tabs=['Home','Explore','Shorts','Create','You'];
    const icons=[Icons.home_outlined,Icons.explore_outlined,
      Icons.play_circle_outline_rounded,Icons.add_box_outlined,Icons.person_outline];
    final selected=tabs.contains(page)?tabs.indexOf(page):4;
    return Scaffold(
      drawer:api.signedIn&&!wide&&!isSocial
        ?Drawer(child:SafeArea(child:sideNav())):null,
      body:SafeArea(child:Column(children:[
        Container(height:66,padding:const EdgeInsets.symmetric(horizontal:15),
          decoration:const BoxDecoration(color:Colors.white,
            border:Border(bottom:BorderSide(color:Color(0xFFE9ECF3)))),
          child:Row(children:[
            if(api.signedIn&&!wide&&!isSocial)
              Builder(builder:(context)=>IconButton(
                onPressed:()=>Scaffold.of(context).openDrawer(),
                icon:const Icon(Icons.menu_rounded,color:navy))),
            InkWell(onTap:()=>navigate('Home'),
              child:const WeuTubeBrand(size:22)),
            const Spacer(),
            if(!api.signedIn&&wide)
              TextButton(onPressed:()=>navigate('Sign In'),
                child:const Text('Sign In')),
            if(!api.signedIn&&!wide)
              IconButton(onPressed:()=>navigate('Sign In'),
                icon:const Icon(Icons.login_rounded,color:navy)),
            if(api.signedIn) ...[
              if(api.showAdminMenu)
                IconButton(onPressed:()=>navigate('Admin Operations'),
                  icon:const Icon(Icons.admin_panel_settings_outlined,color:coral)),
              IconButton(onPressed:()=>navigate('Notifications'),
                icon:const Icon(Icons.notifications_none_rounded,color:navy)),
              IconButton(onPressed:()=>navigate('You'),
                icon:const Icon(Icons.account_circle_outlined,color:navy)),
            ]
          ])),
        if(busy)const LinearProgressIndicator(minHeight:3,color:coral),
        Expanded(child:Row(children:[
          if(api.signedIn&&wide&&!isSocial)sideNav(),
          Expanded(child:isSocial
            ?Center(child:ConstrainedBox(
                constraints:const BoxConstraints(maxWidth:620),
                child:SocialHub(
                  api:api,
                  section:page,
                  onNavigate:navigate,
                  onSignIn:(){
                    afterLogin='You';
                    navigate('Sign In');
                  },
                  onCreate:createFromSocial,
                  onStudio:()=>navigate('Dashboard'))))
            :SingleChildScrollView(
              padding:EdgeInsets.all(width<520?15:25),
              child:Center(child:ConstrainedBox(
                constraints:const BoxConstraints(maxWidth:1050),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  banner(),content(wide?width-290:width-35),
                  const SizedBox(height:40)
                ])))))
        ]))
      ])),
      bottomNavigationBar:!isAuth?NavigationBar(
        height:68,selectedIndex:selected,
        onDestinationSelected:(i)=>navigate(tabs[i]),
        destinations:[
          for(int i=0;i<tabs.length;i++)
            NavigationDestination(icon:Icon(icons[i]),label:tabs[i])
        ]):null
    );
  }
}
