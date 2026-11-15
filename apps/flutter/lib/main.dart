import 'package:flutter/material.dart';

void main() => runApp(const WeuTubeApp());

class Brand {
  static const navy = Color(0xFF0B1F4D);
  static const coral = Color(0xFFFF4B3A);
  static const bg = Color(0xFFF8F9FC);
  static const muted = Color(0xFF657087);
}

class WeuTubeApp extends StatelessWidget {
  const WeuTubeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'WeuTube', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: Brand.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: Brand.navy, primary: Brand.navy, secondary: Brand.coral),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: Brand.coral,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.all(16)))),
    home: const WeuTubeShell(),
  );
}

class WeuTubeShell extends StatefulWidget {
  const WeuTubeShell({super.key});
  @override
  State<WeuTubeShell> createState() => _WeuTubeShellState();
}

class _WeuTubeShellState extends State<WeuTubeShell> {
  String page = 'Welcome';
  bool signedIn = false;
  bool admin = false;
  final pages = ['Dashboard','Upload Video','My Videos','Analytics','Earnings','Wallet','Transactions','Notifications','Profile','Settings'];
  final adminPages = ['Admin Overview','Review Videos','YouTube Channels','Creators','Payouts','Guidelines'];
  void go(String p) => setState(() => page = p);
  void toast(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Widget brand({double size = 26}) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: size + 12, height: size + 12, alignment: Alignment.center,
      decoration: BoxDecoration(color: Brand.navy, borderRadius: BorderRadius.circular(12)),
      child: Text('W',style: TextStyle(color: Brand.coral,fontSize: size,fontWeight: FontWeight.w900))),
    const SizedBox(width: 9), Text('Weu',style: TextStyle(color: Brand.navy,fontSize: size,fontWeight: FontWeight.w800)),
    Text('Tube',style: TextStyle(color: Brand.coral,fontSize: size,fontWeight: FontWeight.w800))
  ]);
  Widget field(String hint,{bool secret=false}) => Padding(padding: const EdgeInsets.only(bottom: 12),
    child: TextField(obscureText: secret, decoration: InputDecoration(labelText: hint,filled: true,fillColor: Colors.white)));
  Widget action(String label,VoidCallback onTap) => SizedBox(width: double.infinity,child: FilledButton(onPressed:onTap,child:Text(label)));
  Widget panel(String title,Widget child) => Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,
    children:[Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w800,color:Brand.navy)),const SizedBox(height:15),child])));
  Widget stat(String title,String value,IconData icon) => Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,color:Brand.coral),const SizedBox(height:10),
      Text(value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.w800,color:Brand.navy)),
      Text(title,style:const TextStyle(color:Brand.muted))])));
  Widget auth() => Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:440),
    child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(children:[
      brand(size:32),const SizedBox(height:28),
      panel(page == 'Welcome'?'Your stories deserve a stage':page,Column(children:[
        if(page=='Create Account') field('Full name'),
        if(page!='Welcome') field('Email address'),
        if(page=='Sign In'||page=='Create Account') field('Password',secret:true),
        if(page=='Welcome') ...[const Text('Share videos, track performance and manage earnings in one place.'),
          const SizedBox(height:18),action('Sign In',()=>go('Sign In')),
          TextButton(onPressed:()=>go('Create Account'),child:const Text('Create Account'))],
        if(page=='Sign In') ...[action('Sign In',(){setState(()=>signedIn=true);go('Dashboard');}),
          TextButton(onPressed:()=>go('Reset Password'),child:const Text('Forgot password?')),
          TextButton(onPressed:()=>go('Create Account'),child:const Text('Create Account'))],
        if(page=='Create Account') ...[action('Create Account',(){setState(()=>signedIn=true);go('Dashboard');}),
          TextButton(onPressed:()=>go('Sign In'),child:const Text('Already have an account? Sign In'))],
        if(page=='Reset Password') action('Send Reset Link',()=>toast('Demo only: no email sent')),
      ])),
      const SizedBox(height:10),const Text('Frontend demonstration — no account is created.',style:TextStyle(color:Brand.muted))
    ]))));
  Widget videoList({bool review=false}) => Column(children:List.generate(5,(i)=>Card(child:ListTile(
    leading:Container(width:62,height:55,decoration:BoxDecoration(color:Brand.navy.withValues(alpha:.09),
      borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.movie_outlined,color:Brand.navy)),
    title:Text(['Weekend travel vlog','Easy home cooking','Street photography','Morning fitness','Technology tips'][i]),
    subtitle:Text(review?'Pending Review':'${[12840,7450,2130,980,340][i]} views · ${i.isEven?'Published':'Pending Review'}'),
    trailing:const Icon(Icons.chevron_right),onTap:()=>go(review?'Review Detail':'Video Details')))));
  Widget content() {
    switch(page) {
      case 'Dashboard': return Column(children:[
        const Align(alignment:Alignment.centerLeft,child:Text('Welcome back, Creator',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800))),
        const SizedBox(height:12),LayoutBuilder(builder:(context,c)=>GridView.count(
          shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:c.maxWidth>650?4:2,
          childAspectRatio:c.maxWidth>650?1.65:1.4,children:[
            stat('Total Views','23,740',Icons.visibility_outlined),stat('My Videos','12',Icons.video_library_outlined),
            stat('Estimated Earnings','₹1,840',Icons.currency_rupee),stat('Subscribers','1,290',Icons.people_outline)])),
        panel('Recent Videos',videoList()),action('Upload Video',()=>go('Upload Video'))]);
      case 'Upload Video': return panel('Submit a video for review',Column(children:[
        const Icon(Icons.cloud_upload_outlined,size:65,color:Brand.coral),
        const Text('Select a video to upload (UI demonstration)'),
        const SizedBox(height:12),field('Video title'),field('Description'),field('Category'),
        const Text('Your video will remain private until an admin approves publishing.',
          style:TextStyle(color:Brand.muted)),const SizedBox(height:14),
        action('Choose Video',()=>toast('File picker will be connected during integration')),
        action('Submit for Review',()=>toast('Demo only: no video was uploaded'))]));
      case 'My Videos': return panel('Your uploaded videos',videoList());
      case 'Video Details': return panel('Video details',Column(children:[
        const ListTile(title:Text('Weekend travel vlog'),subtitle:Text('Published · 12,840 views')),
        action('View Analytics',()=>go('Analytics')),action('Back to My Videos',()=>go('My Videos'))]));
      case 'Analytics': return Column(children:[Wrap(spacing:10,runSpacing:10,children:[
        SizedBox(width:170,child:stat('Views','23,740',Icons.visibility)),
        SizedBox(width:170,child:stat('Likes','1,450',Icons.favorite_border)),
        SizedBox(width:170,child:stat('Watch Time','960 hrs',Icons.schedule))]),
        panel('Performance',const Text('Video-level and date-range analytics will use YouTube reporting data.'))]);
      case 'Earnings': return Column(children:[stat('Estimated Earnings','₹1,840',Icons.currency_rupee),
        panel('Earnings details',const Text('Estimated amounts are examples. Final payouts depend on verified revenue and payout rules.'))]);
      case 'Wallet': return Column(children:[stat('Available Balance','₹0',Icons.account_balance_wallet_outlined),
        panel('Withdraw funds',Column(children:[field('Withdrawal amount'),field('Payment account'),
          action('Request Withdrawal',()=>toast('Demo only: no payout request submitted'))]))]);
      case 'Transactions': return panel('Transactions',const Text('No real transactions. Sample payments will appear after backend integration.'));
      case 'Notifications': return panel('Notifications',const Column(children:[
        ListTile(leading:Icon(Icons.hourglass_empty),title:Text('Video awaiting review')),
        ListTile(leading:Icon(Icons.check_circle_outline),title:Text('Sample video approved'))]));
      case 'Profile': return panel('My Profile',Column(children:[field('Display name'),field('Bio'),field('Location'),
        action('Save Profile',()=>toast('Demo only: changes not saved'))]));
      case 'Settings': return panel('Account Settings',Column(children:[
        SwitchListTile(title:const Text('Email notifications'),value:true,onChanged:(_)=>toast('Demo setting')),
        ListTile(title:const Text('Privacy Policy'),onTap:()=>go('Privacy Policy')),
        ListTile(title:const Text('Terms of Service'),onTap:()=>go('Terms of Service')),
        action('Sign Out',(){setState(()=>signedIn=false);go('Welcome');})]));
      case 'Admin Overview': return Column(children:[stat('Pending Reviews','5',Icons.fact_check_outlined),
        panel('Review queue',videoList(review:true))]);
      case 'Review Videos': return panel('Videos awaiting review',videoList(review:true));
      case 'Review Detail': return panel('Review submission',Column(children:[
        const Text('Review copyright, consent, safety and advertiser suitability before publishing.'),
        const SizedBox(height:16),action('Approve',()=>toast('Demo: no approval saved')),
        action('Reject',()=>toast('Demo: no rejection saved')),
        action('Publish to YouTube',()=>toast('Demo: no YouTube publishing performed'))]));
      case 'YouTube Channels': return panel('YouTube Channels',Column(children:[
        const ListTile(title:Text('Main channel'),subtitle:Text('Monetization status must be verified per channel')),
        action('Connect YouTube Channel',()=>toast('OAuth integration pending'))]));
      case 'Creators': return panel('Creators',const Text('Creator directory and account moderation.'));
      case 'Payouts': return panel('Payouts',const Text('Payout review and reconciliation — integration pending.'));
      case 'Guidelines': return panel('Content Guidelines',const Text('Original content, creator rights, consent and community safety are required.'));
      default: return panel(page,const Text('This page will be populated with production content during integration.'));
    }
  }
  @override
  Widget build(BuildContext context) {
    if(!signedIn) return Scaffold(body:auth());
    final items=admin?adminPages:pages;
    final wide=MediaQuery.sizeOf(context).width>=850;
    final nav=ListView(children:[
      Padding(padding:const EdgeInsets.all(18),child:brand()),
      ...items.map((p)=>ListTile(dense:true,selected:page==p,selectedColor:Brand.coral,
        title:Text(p),onTap:()=>go(p))),
      const Divider(),
      ListTile(title:Text(admin?'Creator Mode':'Admin Demo'),leading:const Icon(Icons.swap_horiz),
        onTap:(){setState(()=>admin=!admin);go(admin?'Admin Overview':'Dashboard');}),
      ListTile(title:const Text('Sign Out'),leading:const Icon(Icons.logout),
        onTap:(){setState(()=>signedIn=false);go('Welcome');})
    ]);
    return Scaffold(
      appBar:AppBar(backgroundColor:Colors.white,title:wide?Text(page):brand(size:22),
        actions:[IconButton(onPressed:()=>go('Notifications'),icon:const Icon(Icons.notifications_none)),
          IconButton(onPressed:()=>go('Profile'),icon:const Icon(Icons.account_circle_outlined))]),
      drawer:wide?null:Drawer(child:nav),
      body:Row(children:[
        if(wide) SizedBox(width:240,child:Material(color:Colors.white,child:nav)),
        Expanded(child:SingleChildScrollView(padding:const EdgeInsets.all(20),
          child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1100),
            child:content())))
      ]),
      bottomNavigationBar:wide?null:NavigationBar(selectedIndex:page=='Dashboard'?0:page=='Upload Video'?1:page=='My Videos'?2:page=='Wallet'?3:4,
        onDestinationSelected:(i)=>go(['Dashboard','Upload Video','My Videos','Wallet','Profile'][i]),
        destinations:const [
          NavigationDestination(icon:Icon(Icons.home_outlined),label:'Home'),
          NavigationDestination(icon:Icon(Icons.add_circle_outline),label:'Upload'),
          NavigationDestination(icon:Icon(Icons.video_library_outlined),label:'Videos'),
          NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),label:'Wallet'),
          NavigationDestination(icon:Icon(Icons.person_outline),label:'Profile')
        ])
    );
  }
}
