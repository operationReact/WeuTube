import 'dart:convert';
import 'package:flutter/material.dart';
import 'approved_brand_icon.dart';

const navy = Color(0xFF0B1F4D);
const coral = Color(0xFFFF4B3A);
const soft = Color(0xFFF8F9FC);
const slate = Color(0xFF657087);
const success = Color(0xFF22865B);

/// The shared design system is used for web, Android and iOS.
class WeuTubeBrand extends StatelessWidget {
  final double size;
  const WeuTubeBrand({super.key, this.size = 24});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Image.memory(base64Decode(approvedBrandIconBase64),
      width: size * 1.25, height: size, fit: BoxFit.contain),
    SizedBox(width: size * .28),
    Text('Weu', style: TextStyle(color: navy, fontSize: size, fontWeight: FontWeight.w900, letterSpacing: -.6)),
    Text('Tube', style: TextStyle(color: coral, fontSize: size, fontWeight: FontWeight.w900, letterSpacing: -.6)),
  ]);
}

class WeuTubeProduct extends StatefulWidget {
  const WeuTubeProduct({super.key});
  @override
  State<WeuTubeProduct> createState() => _WeuTubeProductState();
}

class _WeuTubeProductState extends State<WeuTubeProduct> {
  String page = 'Home';
  String filter = 'All';
  String range = '30 days';
  bool previewSession = false;
  bool notificationsEnabled = true;
  bool showPassword = false;
  final email = TextEditingController();
  final password = TextEditingController();
  final fullName = TextEditingController();
  final videoTitle = TextEditingController();
  final videoDescription = TextEditingController();
  final formKey = GlobalKey<FormState>();

  static const navigation = ['Dashboard', 'Upload Video', 'My Videos', 'Analytics',
    'Earnings', 'Wallet', 'Notifications', 'Profile', 'Settings'];
  static const navigationIcons = [Icons.grid_view_rounded, Icons.cloud_upload_outlined,
    Icons.video_library_outlined, Icons.insights_outlined, Icons.payments_outlined,
    Icons.account_balance_wallet_outlined, Icons.notifications_none,
    Icons.person_outline, Icons.settings_outlined];

  @override
  void dispose() {
    for (final c in [email, password, fullName, videoTitle, videoDescription]) {
      c.dispose();
    }
    super.dispose();
  }

  void go(String route) => setState(() => page = route);
  void inform(String message) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(message)));
  void demoLogin() {
    setState(() { previewSession = true; page = 'Dashboard'; });
    inform('Preview mode only: no account was created or authenticated.');
  }

  Widget primary(String label, VoidCallback action, {IconData? icon, bool outlined = false}) {
    final child = Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center,
      children: [if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800))]);
    return outlined
      ? OutlinedButton(onPressed: action, style: OutlinedButton.styleFrom(
          foregroundColor: navy, side: const BorderSide(color: navy),
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 15)), child: child)
      : FilledButton(onPressed: action, style: FilledButton.styleFrom(
          backgroundColor: coral, foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 15)), child: child);
  }

  Widget card(Widget child, {EdgeInsets padding = const EdgeInsets.all(17)}) => Container(
    padding: padding,
    decoration: BoxDecoration(color: Colors.white,
      border: Border.all(color: const Color(0xFFE7EBF3)),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x080B1F4D), blurRadius: 15, offset: Offset(0, 5))]),
    child: child);

  Widget heading(String title, String subtitle) => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [Text(title, style: const TextStyle(color: navy, fontSize: 26,
        fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: slate, fontSize: 13))]);

  Widget tag(String label, {Color color = success}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(24)),
    child: Text(label, style: TextStyle(color: color,
      fontSize: 11, fontWeight: FontWeight.w700)));

  Widget field(String label, TextEditingController controller,
      {bool secret = false, int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(controller: controller,
      obscureText: secret && !showPassword, maxLines: lines,
      validator: (value) => (value == null || value.trim().isEmpty)
        ? 'Enter $label' : null,
      decoration: InputDecoration(labelText: label,
        fillColor: Colors.white, filled: true,
        suffixIcon: secret ? IconButton(
          onPressed: () => setState(() => showPassword = !showPassword),
          icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined))
          : null)));

  Widget metric(String title, String value, IconData icon, {String? note}) =>
    card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: coral.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: coral)),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(color: slate, fontSize: 12)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(color: navy, fontSize: 22,
        fontWeight: FontWeight.w900)),
      if (note != null) ...[const SizedBox(height: 4),
        Text(note, style: const TextStyle(color: slate, fontSize: 10))]
    ]));

  Widget metrics(double width, List<Widget> items) => GridView.count(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: width > 780 ? 4 : 2,
    mainAxisSpacing: 10, crossAxisSpacing: 10,
    childAspectRatio: width > 780 ? 1.65 : width < 380 ? 1.05 : 1.25,
    children: items);

  Widget sampleVideo(int index) {
    const names = ['Weekend travel vlog', 'Easy home cooking',
      'Studio setup guide', 'Coastal adventures'];
    const states = ['Published', 'Pending Review', 'Draft', 'Rejected'];
    final state = states[index];
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: card(Row(children: [
        Container(width: 67, height: 57,
          decoration: BoxDecoration(color: navy.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.movie_creation_outlined, color: navy)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(names[index], maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: navy, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Illustrative item', style: TextStyle(fontSize: 11, color: slate))])),
        const SizedBox(width: 4),
        tag(state, color: index == 0 ? success : index == 3 ? coral : slate),
        IconButton(icon: const Icon(Icons.chevron_right, color: slate),
          onPressed: () => go('Video Details')),
      ]), padding: const EdgeInsets.all(10)));
  }

  Widget landing(double width) {
    final wide = width > 800;
    final pitch = Column(crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center, children: [
      tag('A CREATOR-FIRST VIDEO COMMUNITY', color: coral),
      const SizedBox(height: 17),
      Text('Create. Connect.\nGrow together.', style: TextStyle(
        color: navy, fontSize: wide ? 47 : 35,
        height: 1.12, fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      const Text('Publish your stories, reach your community and manage your creative journey in one place.',
        style: TextStyle(color: slate, height: 1.5, fontSize: 15)),
      const SizedBox(height: 20),
      Wrap(spacing: 10, runSpacing: 10, children: [
        primary('Create Account', () => go('Create Account')),
        primary('Sign In', () => go('Sign In'), outlined: true)]),
      const SizedBox(height: 13),
      const Text('Creator tools • Private review • Transparent earnings',
        style: TextStyle(color: slate, fontSize: 11)),
    ]);
    final visual = card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [Icon(Icons.auto_awesome_outlined, color: coral),
        SizedBox(width: 8), Text('Your creator space',
          style: TextStyle(color: navy, fontWeight: FontWeight.w900))]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _previewTile('MY VIDEOS', '12', Icons.video_library_outlined)),
        const SizedBox(width: 9),
        Expanded(child: _previewTile('UPDATES', '03', Icons.notifications_none))]),
      const SizedBox(height: 10),
      Container(height: 135, padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(14)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('Publishing journey',
            style: TextStyle(color: navy, fontWeight: FontWeight.w800)),
            SizedBox(height: 15),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Icon(Icons.upload_file, color: coral), Icon(Icons.arrow_forward, color: slate),
              Icon(Icons.fact_check_outlined, color: navy), Icon(Icons.arrow_forward, color: slate),
              Icon(Icons.public_outlined, color: success)]),
            SizedBox(height: 10),
            Text('Upload  →  Review  →  Publish',
              style: TextStyle(color: slate, fontSize: 12))])),
      const SizedBox(height: 11),
      const Text('Preview content only',
        style: TextStyle(color: slate, fontSize: 11))]));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.symmetric(vertical: 38),
        child: wide ? Row(children: [Expanded(child: pitch),
          const SizedBox(width: 28), Expanded(child: visual)]) :
          Column(children: [pitch, const SizedBox(height: 25), visual])),
      heading('How WeuTube Works', 'A simple journey from an idea to your audience.'),
      const SizedBox(height: 17),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _feature('Create', Icons.create_outlined, 'Prepare your story and upload your work.'),
        _feature('Review', Icons.verified_outlined, 'Track approval before publication.'),
        _feature('Grow', Icons.groups_outlined, 'Connect with audiences and build your presence.'),
        _feature('Earn', Icons.account_balance_wallet_outlined,
          'Track revenue only when it has been verified.')]),
      const SizedBox(height: 32),
      heading('Built around creators', 'More than a place to upload videos.'),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _feature('Your content', Icons.video_library_outlined, 'Drafts, approvals and published stories.'),
        _feature('Your insights', Icons.insights_outlined, 'Understand how your videos perform.'),
        _feature('Your account', Icons.security_outlined, 'Secure channel and profile management.')]),
      const SizedBox(height: 26),
      card(Column(children: [
        const Text('Start creating with WeuTube',
          style: TextStyle(color: navy, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        primary('Get Started', () => go('Create Account'))])),
      const SizedBox(height: 26),
      const Text('WeuTube  •  Privacy  •  Terms  •  Contact',
        style: TextStyle(color: slate, fontSize: 12))
    ]);
  }

  Widget _previewTile(String name, String value, IconData icon) =>
    Container(padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [Icon(icon, color: coral),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontSize: 10, color: slate)),
          Text(value, style: const TextStyle(fontSize: 23, color: navy,
            fontWeight: FontWeight.w900))]));
  Widget _feature(String name, IconData icon, String description) =>
    SizedBox(width: 240, child: card(Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [Icon(icon, color: coral, size: 29),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(color: navy,
          fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 7),
        Text(description, style: const TextStyle(color: slate, fontSize: 12))])));

  Widget auth() => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 455),
    child: card(Form(key: formKey, child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Center(child: WeuTubeBrand(size: 30)),
      const SizedBox(height: 25),
      heading(page == 'Sign In' ? 'Welcome back' :
        page == 'Create Account' ? 'Create your account' : 'Reset your password',
        'Your creative community starts here.'),
      const SizedBox(height: 22),
      if(page == 'Create Account') field('Full Name', fullName),
      field('Email Address', email),
      if(page != 'Forgot Password') field('Password', password, secret: true),
      if(page == 'Sign In') Align(alignment: Alignment.centerRight,
        child: TextButton(onPressed: () => go('Forgot Password'),
          child: const Text('Forgot password?'))),
      primary(page == 'Sign In' ? 'Sign In' :
        page == 'Create Account' ? 'Create Account' : 'Send Reset Link', () {
          if(formKey.currentState?.validate() != true) return;
          if(page == 'Forgot Password') {
            inform('Preview only: no reset email was sent.');
          } else {
            demoLogin();
          }
        }),
      const SizedBox(height: 11),
      TextButton(onPressed: () => go(page == 'Create Account'
          ? 'Sign In' : 'Create Account'),
        child: Text(page == 'Create Account'
          ? 'Already have an account? Sign In' : 'New here? Create Account')),
      const Divider(),
      const Text('UI preview only. Account creation and sign-in are not connected to a live service.',
        style: TextStyle(color: slate, fontSize: 11), textAlign: TextAlign.center)
    ])))));

  Widget dashboard(double width) => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [Expanded(child: heading('Welcome back, Creator',
        'Your stories, progress and updates in one place.')),
        if(width > 620) primary('Upload Video',
          () => go('Upload Video'), icon: Icons.cloud_upload_outlined)]),
      const SizedBox(height: 19),
      metrics(width, [
        metric('Total Views', '—', Icons.visibility_outlined),
        metric('My Videos', '—', Icons.video_library_outlined),
        metric('Verified Earnings', '₹0.00', Icons.paid_outlined),
        metric('Subscribers', '—', Icons.people_outline)]),
      const SizedBox(height: 18),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Your publishing journey', style: TextStyle(
          color: navy, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 10),
        const Text('Your drafts, reviews and published videos will appear here once your account is connected.',
          style: TextStyle(color: slate)),
        const SizedBox(height: 14),
        primary('Create a Video Draft', () => go('Upload Video'),
          icon: Icons.add_circle_outline)])),
      const SizedBox(height: 20),
      Row(children: [
        const Expanded(child: Text('Video management preview',
          style: TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 18))),
        TextButton(onPressed: () => go('My Videos'), child: const Text('View All'))]),
      for(int i = 0; i < 3; i++) sampleVideo(i),
      const Text('Sample video cards for layout review, not real account data.',
        style: TextStyle(color: slate, fontSize: 11))
    ]);

  Widget upload() => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading('Upload Video', 'Prepare content for moderation and publishing.'),
      const SizedBox(height: 18),
      card(Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        Container(height: 145, decoration: BoxDecoration(color: soft,
          border: Border.all(color: const Color(0xFFD6DEEB)),
          borderRadius: BorderRadius.circular(13)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.cloud_upload_outlined, color: coral, size: 45),
            const SizedBox(height: 8),
            const Text('Select a video to upload',
              style: TextStyle(color: navy, fontWeight: FontWeight.w800)),
            TextButton(onPressed: () => inform('File transfer is not connected yet.'),
              child: const Text('Browse files'))
          ])),
        const SizedBox(height: 18),
        field('Video Title', videoTitle),
        field('Description', videoDescription, lines: 3),
        DropdownButtonFormField<String>(initialValue: 'Education',
          decoration: const InputDecoration(labelText: 'Category'),
          items: ['Education','Entertainment','Travel','Technology','Lifestyle','Other']
            .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (_) {}),
        const SizedBox(height: 14),
        const ListTile(contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.lock_outline, color: navy),
          title: Text('Private until approved'),
          subtitle: Text('Only verified private uploads can enter admin review.')),
        primary('Submit for Review', () =>
          inform('Preview only: no video was uploaded or submitted.'))
      ]))
    ]);

  Widget videos() => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading('My Videos', 'Track videos from draft to publication.'),
      const SizedBox(height: 17),
      SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(children: [
          for(final item in ['All','Published','Pending Review','Draft','Rejected']) ...[
            ChoiceChip(label: Text(item), selected: filter == item,
              selectedColor: coral.withValues(alpha: .15),
              onSelected: (_) => setState(() => filter = item)),
            const SizedBox(width: 8)
          ]
        ])),
      const SizedBox(height: 16),
      for(int i = 0; i < 4; i++)
        if(filter == 'All' ||
            ['Published','Pending Review','Draft','Rejected'][i] == filter)
          sampleVideo(i),
      const Text('Sample entries only.', style: TextStyle(color: slate, fontSize: 11))
    ]);

  Widget analytics(double width) => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading('Analytics', 'Understand your content performance.'),
      const SizedBox(height: 12),
      DropdownButton<String>(value: range,
        items: ['7 days','30 days','90 days'].map((s) =>
          DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: (value) => setState(() => range = value!)),
      const SizedBox(height: 14),
      metrics(width, [
        metric('Views', '—', Icons.visibility_outlined),
        metric('Likes', '—', Icons.thumb_up_outlined),
        metric('Watch Time', '—', Icons.schedule_outlined),
        metric('Subscribers', '—', Icons.people_outline)]),
      const SizedBox(height: 18),
      card(const Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text('Views Over Time', style: TextStyle(color: navy,
          fontSize: 18, fontWeight: FontWeight.w900)),
        SizedBox(height: 14),
        SizedBox(height: 140, child: Center(child:
          Icon(Icons.insert_chart_outlined, color: coral, size: 65))),
        Text('Live charts will appear after analytics integration.',
          style: TextStyle(color: slate))
      ]))
    ]);

  Widget finances(bool wallet) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
    heading(wallet ? 'Wallet' : 'Earnings',
      wallet ? 'Balances, withdrawal requests and history.'
        : 'Verified revenue and payout tracking.'),
    const SizedBox(height: 17),
    Container(width: double.infinity, padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(18)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Available verified balance', style: TextStyle(color: Colors.white70)),
        SizedBox(height: 8),
        Text('₹0.00', style: TextStyle(color: Colors.white,
          fontWeight: FontWeight.w900, fontSize: 31)),
        SizedBox(height: 8),
        Text('No verified revenue is connected yet.',
          style: TextStyle(color: Colors.white70, fontSize: 12))
      ])),
    const SizedBox(height: 17),
    if(wallet) ...[primary('Request Withdrawal',
      () => inform('Withdrawals require a verified balance and payout setup.')),
      const SizedBox(height: 17)],
    card(Column(crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      Text(wallet ? 'Transaction History' : 'Revenue Breakdown',
        style: const TextStyle(color: navy, fontSize: 18,
          fontWeight: FontWeight.w900)),
      const SizedBox(height: 14),
      const Text('No verified transactions available.',
        style: TextStyle(color: slate))
    ]))
  ]);

  Widget profile() => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    heading('Profile', 'Your creator identity and account.'),
    const SizedBox(height: 17),
    card(Column(children: [
      const CircleAvatar(radius: 38, backgroundColor: soft,
        child: Icon(Icons.person_outline, color: navy, size: 45)),
      const SizedBox(height: 11),
      const Text('Creator', style: TextStyle(color: navy, fontSize: 22,
        fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      const Text('Preview account', style: TextStyle(color: slate)),
      const SizedBox(height: 20),
      primary('Edit Profile', () => inform('Profile saving requires backend authentication.'))
    ])),
    const SizedBox(height: 15),
    card(Column(children: [
      ListTile(leading: const Icon(Icons.settings_outlined),
        title: const Text('Settings'), onTap: () => go('Settings')),
      ListTile(leading: const Icon(Icons.notifications_none),
        title: const Text('Notifications'), onTap: () => go('Notifications')),
    ]))
  ]);

  Widget settings() => Column(crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    heading('Settings', 'Preferences and account security.'),
    const SizedBox(height: 17),
    card(Column(children: [
      SwitchListTile(value: notificationsEnabled,
        title: const Text('Notification preferences'),
        subtitle: const Text('Local preview setting'),
        onChanged: (v) => setState(() => notificationsEnabled = v)),
      ListTile(leading: const Icon(Icons.privacy_tip_outlined),
        title: const Text('Privacy Policy'), onTap: () => go('Privacy Policy')),
      ListTile(leading: const Icon(Icons.description_outlined),
        title: const Text('Terms of Service'), onTap: () => go('Terms of Service')),
      ListTile(leading: const Icon(Icons.help_outline),
        title: const Text('Help & Support'), onTap: () => go('Help & Support')),
      ListTile(leading: const Icon(Icons.logout, color: coral),
        title: const Text('Sign Out', style: TextStyle(color: coral)),
        onTap: () => setState(() { previewSession = false; page = 'Home'; }))
    ]))
  ]);

  Widget content(double width) {
    switch(page) {
      case 'Home':
      case 'How It Works':
      case 'FAQs':
        return landing(width);
      case 'Sign In':
      case 'Create Account':
      case 'Forgot Password':
        return auth();
      case 'Dashboard':
        return dashboard(width);
      case 'Upload Video':
        return upload();
      case 'My Videos':
        return videos();
      case 'Video Details':
        return Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          heading('Video Details', 'Submission status and performance.'),
          const SizedBox(height: 17),
          sampleVideo(0),
          primary('Back to My Videos', () => go('My Videos'), outlined: true)]);
      case 'Analytics':
        return analytics(width);
      case 'Earnings':
        return finances(false);
      case 'Wallet':
        return finances(true);
      case 'Notifications':
        return Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          heading('Notifications', 'Reviews, publishing and payout updates.'),
          const SizedBox(height: 16),
          card(const ListTile(
            leading: Icon(Icons.notifications_none, color: coral),
            title: Text('Nothing new yet'),
            subtitle: Text('Your notifications will appear here.')))]);
      case 'Profile':
        return profile();
      case 'Settings':
        return settings();
      default:
        return Column(children: [
          heading(page, 'WeuTube creator help and information.'),
          const SizedBox(height: 17),
          card(const Text('Content is being prepared.'))]);
    }
  }

  Widget sidebar() => Container(width: 228, color: Colors.white,
    child: ListView(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      children: [
      for(int i = 0; i < navigation.length; i++)
        Padding(padding: const EdgeInsets.only(bottom: 3),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
            selected: page == navigation[i], selectedColor: navy,
            selectedTileColor: navy.withValues(alpha: .09),
            leading: Icon(navigationIcons[i],
              color: page == navigation[i] ? coral : navy),
            title: Text(navigation[i], style: const TextStyle(fontSize: 13)),
            onTap: () => go(navigation[i]))),
      const Divider(),
      ListTile(leading: const Icon(Icons.logout, color: coral),
        title: const Text('Sign Out'), onTap: () => setState(() {
          previewSession = false; page = 'Home';
        }))
    ]));

  Widget topbar(bool wide) => Container(height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: const BoxDecoration(color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFE9ECF3)))),
    child: Row(children: [
      if(previewSession && !wide)
        Builder(builder: (context) => IconButton(
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu_rounded, color: navy))),
      const WeuTubeBrand(size: 22),
      const Spacer(),
      if(!previewSession && wide) ...[
        TextButton(onPressed: () => go('Home'), child: const Text('Home')),
        TextButton(onPressed: () => go('How It Works'),
          child: const Text('How It Works')),
        const SizedBox(width: 9),
        primary('Sign In', () => go('Sign In'), outlined: true),
        const SizedBox(width: 9),
        primary('Create Account', () => go('Create Account'))
      ] else if(!previewSession) ...[
        TextButton(onPressed: () => go('Sign In'), child: const Text('Sign In')),
        IconButton(onPressed: () => go('Create Account'),
          icon: const Icon(Icons.person_add_alt, color: coral))
      ] else ...[
        IconButton(onPressed: () => go('Notifications'),
          icon: const Icon(Icons.notifications_none, color: navy)),
        IconButton(onPressed: () => go('Profile'),
          icon: const Icon(Icons.account_circle_outlined, color: navy))
      ]
    ]));

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 850;
    final bottom = ['Dashboard','Upload Video','My Videos','Wallet','Profile'];
    final bottomIcons = [Icons.home_outlined, Icons.cloud_upload_outlined,
      Icons.video_library_outlined, Icons.account_balance_wallet_outlined,
      Icons.person_outline];
    return Scaffold(
      drawer: previewSession && !wide ? Drawer(child: SafeArea(child: sidebar())) : null,
      body: SafeArea(child: Column(children: [
        Builder(builder: (context) => topbar(wide)),
        Expanded(child: Row(children: [
          if(previewSession && wide) sidebar(),
          Expanded(child: SingleChildScrollView(
            padding: EdgeInsets.all(width < 520 ? 16 : 26),
            child: Center(child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: content(width < 1100 && wide ? width - 310 : width - 35)))))
        ]))
      ])),
      bottomNavigationBar: previewSession && !wide
        ? NavigationBar(height: 71, selectedIndex: bottom.contains(page) ?
            bottom.indexOf(page) : 0,
            onDestinationSelected: (index) => go(bottom[index]),
            destinations: [
              for(int i = 0; i < bottom.length; i++)
                NavigationDestination(icon: Icon(bottomIcons[i]),
                  label: ['Home','Upload','Videos','Wallet','Profile'][i])
            ])
        : null
    );
  }
}
