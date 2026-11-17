import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'backend_client.dart';
import 'product_ui.dart' show navy, coral, slate;

/// Production API-backed moderation and connected-channel management.
/// The server, not this UI, enforces Cognito weutube-admin permissions.
class WeuTubeAdminPanel extends StatefulWidget {
  final WeuTubeApi api;
  const WeuTubeAdminPanel({super.key,required this.api});
  @override State<WeuTubeAdminPanel> createState()=>_WeuTubeAdminPanelState();
}
class _WeuTubeAdminPanelState extends State<WeuTubeAdminPanel> {
  String section='Reviews',error='',message='';
  bool loading=false;
  List<Map<String,dynamic>> rows=[];
  Map<String,dynamic> catalogState={};
  final reason=TextEditingController();
  final grantSub=TextEditingController();
  final grantChannel=TextEditingController();

  @override void initState() {super.initState(); WidgetsBinding.instance.addPostFrameCallback((_)=>load());}
  @override void dispose(){reason.dispose();grantSub.dispose();grantChannel.dispose();super.dispose();}
  Future<void> task(Future<void> Function() action) async {
    if(loading) return;
    setState(()=>loading=true);
    try {await action(); if(mounted) setState(()=>error='');}
    on ApiFailure catch(e){if(mounted)setState(()=>error=e.message);}
    catch(_){if(mounted)setState(()=>error='The operation did not complete.');}
    finally{if(mounted)setState(()=>loading=false);}
  }
  Future<void> load() => task(() async {
    final result=switch(section) {
      'Reviews'=>await widget.api.reviewQueue(),
      'Publishing'=>await widget.api.pendingPublication(),
      'Channels'=>await widget.api.adminChannels(),
      _=>await widget.api.payoutQueue(),
    };
    Map<String,dynamic> feedState={};
    if(section=='Channels') {
      try {feedState=await widget.api.publicFeed();}
      catch (_) {
        // Channel management must remain available if discovery is offline.
      }
    }
    if(mounted)setState(() {
      rows=result;
      if(section=='Channels')catalogState=feedState;
    });
  });
  Future<void> switchTo(String next) async {setState(()=>section=next);await load();}
  void toast(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content:Text(text)));}
  Widget button(String label,VoidCallback callback,{bool secondary=false}) =>
    secondary ? OutlinedButton(onPressed:loading?null:callback,
      child:Text(label)) :
      FilledButton(style:FilledButton.styleFrom(backgroundColor:coral),
        onPressed:loading?null:callback,child:Text(label));
  Widget panel(Widget content)=>Container(padding:const EdgeInsets.all(16),
    decoration:BoxDecoration(color:Colors.white,
      border:Border.all(color:const Color(0xFFE7EBF3)),
      borderRadius:BorderRadius.circular(15)),child:content);
  Widget input(String label,TextEditingController controller)=>Padding(
    padding:const EdgeInsets.only(bottom:10),
    child:TextField(controller:controller,
      decoration:InputDecoration(labelText:label,filled:true,fillColor:Colors.white,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(10)))));
  Future<void> decision(String id,String action) => task(() async {
    if(action=='REJECTED'&&reason.text.trim().isEmpty) {
      throw const ApiFailure('A rejection reason is required.');
    }
    await widget.api.reviewDecision(id,action,reason.text.trim());
    reason.clear();toast('Video '+action.toLowerCase());rows=await widget.api.reviewQueue();
    if(mounted)setState((){});
  });
  Future<void> publish(String id,bool reconcile) => task(() async {
    if(reconcile) await widget.api.reconcilePublish(id);
    else await widget.api.publishVideo(id);
    toast('YouTube publication status verified.');
    rows=await widget.api.pendingPublication();if(mounted)setState((){});
  });
  Future<void> payoutDecision(String id,String action) => task(() async {
    if(action=='REJECTED'&&reason.text.trim().isEmpty) {
      throw const ApiFailure('Enter a rejection reason.');
    }
    await widget.api.payoutDecision(id,action,reason.text.trim());
    reason.clear();rows=await widget.api.payoutQueue();
    toast('Payout review recorded; no bank transfer initiated.');if(mounted)setState((){});
  });
  Future<void> connect() => task(() async {
    final result=await widget.api.channelAuthorization();
    final value=result['url'];
    if(value is! String)throw const ApiFailure('Google authorization URL was not returned.');
    final uri=Uri.tryParse(value);
    if(uri==null||uri.scheme!='https'||uri.host!='accounts.google.com') {
      throw const ApiFailure('Invalid Google authorization URL.');
    }
    if(!await launchUrl(uri,mode:LaunchMode.externalApplication)) {
      throw const ApiFailure('Could not open Google consent page.');
    }
    toast('Authorize the channel in Google, then refresh the channel list.');
  });
  Future<void> grantToMe(String channelId) => task(() async {
    await widget.api.grantChannelToMyAccount(channelId);
    toast('Upload permission granted to your administrator account. Open Create to upload.');
  });
  Future<void> grant() => task(() async {
    if(grantChannel.text.trim().isEmpty||grantSub.text.trim().isEmpty) {
      throw const ApiFailure('Channel ID and creator subject are required.');
    }
    await widget.api.grantChannel(grantChannel.text.trim(),grantSub.text.trim());
    toast('Creator granted access to the connected channel.');
  });

  Widget content() {
    if(rows.isEmpty) return panel(Text(
      section=='Reviews'?'No videos awaiting approval.':
      section=='Publishing'?'No approved or pending publication videos.':
      section=='Channels'?'No connected YouTube channels.':'No pending withdrawal requests.',
      style:const TextStyle(color:slate)));
    return Column(children:[
      for(final row in rows) Padding(padding:const EdgeInsets.only(bottom:10),
        child:panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(section=='Reviews'?row['title']?.toString()??'Untitled':
            section=='Publishing'?row['title']?.toString()??'Untitled':
            section=='Channels'?row['displayName']?.toString()??'Channel':
            'Withdrawal request',style:const TextStyle(color:navy,fontWeight:FontWeight.w800)),
          const SizedBox(height:8),
          Text('Status: '+(row['status']?.toString()??section),
            style:const TextStyle(color:slate,fontSize:12)),
          if(section=='Channels')Text('Channel ID: '+(row['channelId']?.toString()??''),
            style:const TextStyle(color:slate,fontSize:12)),
          if(section=='Channels' && (row['channelId']?.toString() ?? '').isNotEmpty) ...[
            const SizedBox(height:10),
            button('Allow uploads from my account',
              ()=>grantToMe(row['channelId'].toString()))
          ],
          if(section=='Payouts')Text('Amount minor units: '+(row['amountMinor']?.toString()??'0'),
            style:const TextStyle(color:slate,fontSize:12)),
          if(section=='Publishing')Text('Channel: '+(row['channelId']?.toString()??''),
            style:const TextStyle(color:slate,fontSize:12)),
          if(section=='Reviews'||section=='Payouts') ...[
            const SizedBox(height:10),input('Reason for rejection',reason),
            Wrap(spacing:8,runSpacing:8,children:[
              button('Approve',()=>section=='Reviews'?
                decision(row['id'].toString(),'APPROVED'):
                payoutDecision(row['id'].toString(),'APPROVED')),
              button('Reject',()=>section=='Reviews'?
                decision(row['id'].toString(),'REJECTED'):
                payoutDecision(row['id'].toString(),'REJECTED'),secondary:true)
            ])
          ],
          if(section=='Publishing') ...[
            const SizedBox(height:10),
            button(row['status']=='PUBLISHING'?'Verify Publication':'Publish to YouTube',
              ()=>publish(row['id'].toString(),row['status']=='PUBLISHING'))
          ]
        ])))
    ]);
  }

  @override Widget build(BuildContext context)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Admin Operations',style:TextStyle(
        fontSize:25,fontWeight:FontWeight.w900,color:navy)),
      const SizedBox(height:5),
      const Text('Connected channels, creator reviews, publishing and payouts.',
        style:TextStyle(color:slate)),
      const SizedBox(height:14),
      SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[
        for(final item in ['Reviews','Publishing','Channels','Payouts']) ...[
          Padding(padding:const EdgeInsets.only(right:7),
            child:ChoiceChip(label:Text(item),selected:item==section,
              onSelected:(_)=>switchTo(item)))
        ]
      ])),
      const SizedBox(height:15),
      if(loading)const LinearProgressIndicator(color:coral),
      if(error.isNotEmpty) Padding(padding:const EdgeInsets.all(10),
        child:Text(error,style:const TextStyle(color:coral))),
      if(section=='Channels') ...[
        panel(Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('YouTube Channel Connection',style:TextStyle(
            fontWeight:FontWeight.w800,color:navy)),
          const SizedBox(height:12),
          button('Connect with Google',connect),
          const SizedBox(height:12),
          if(catalogState.isNotEmpty) ...[
            Text('Connected channels: ${catalogState['connectedChannels'] ?? '—'}',
              style:const TextStyle(color:navy,fontWeight:FontWeight.w700)),
            Text('Imported public videos: ${catalogState['importedVideos'] ?? '—'}',
              style:const TextStyle(color:slate)),
            Text('Video import: ${catalogState['channelSyncStatus'] ?? 'UNKNOWN'}',
              style:const TextStyle(color:slate)),
            const SizedBox(height:12),
          ],
          const Text('Google API credentials alone do not connect a YouTube '
            'channel. Connection requires completed Google authorization.',
            style:TextStyle(color:slate,fontSize:12)),
          const SizedBox(height:12),
          input('Connected Channel ID',grantChannel),
          input('Creator Cognito Subject',grantSub),
          button('Grant Creator Upload Access',grant),
          const SizedBox(height:7),
          const Text('Google authentication and publishing require the configured owner account.',
            style:TextStyle(color:slate,fontSize:12))
        ])),const SizedBox(height:15),
      ],
      content(),const SizedBox(height:15),
      button('Refresh',load,secondary:true)
    ]);
}
