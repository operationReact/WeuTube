package com.weutube.api;

import java.util.List;

/**
 * Fictional, consent-free UI fixtures. This catalog is not a live community:
 * counts, creator names and biographies are fabricated solely for preview.
 * Do not post fixture engagement to the production ledger.
 */
final class DemoSocialCatalog {
 private DemoSocialCatalog() {}
 private static final String CDN="https://storage.googleapis.com/gtv-videos-bucket/sample/";
 private static final String PHOTO="https://images.unsplash.com/";
 private static SocialFeedController.FeedItem demo(
   String key,String title,String creator,String handle,String topic,
   String description,String thumbnail,String avatar,String clip,
   long views,long likes,long comments,String duration) {
  return new SocialFeedController.FeedItem(
    "demo-"+key,title,creator,null,handle,topic,description,
    PHOTO+thumbnail+"?auto=format&fit=crop&w=1100&q=82",
    CDN+clip,null,views,likes,comments,duration,true,null,
    PHOTO+avatar+"?auto=format&fit=crop&w=200&q=80");
 }
 static List<SocialFeedController.FeedItem> items() {
  return List.of(
   demo("amalfi","Somewhere between sea and sky","Aanya Rao","@aanya.roams",
    "Travel","A slow morning on the coast. This is what being present feels like.",
    "photo-1533105079780-92b9be482077","photo-1534528741775-53994a69daeb",
    "ForBiggerEscapes.mp4",42500,3100,124,"0:15"),
   demo("coffee","The 30-second coffee ritual","Arjun Menon","@arjunmakes",
    "Lifestyle","Little routines, better mornings. What's yours?",
    "photo-1442512595331-e89e73853f31","photo-1500648767791-00dcc994a43e",
    "ForBiggerFun.mp4",18200,1400,78,"0:15"),
   demo("street","The city after everyone goes home","Meera Shah","@meeraframes",
    "Art","I love the stories hidden in the lights after dusk.",
    "photo-1519501025264-65ba15a82390","photo-1531123897727-8f129e1688ce",
    "ForBiggerJoyrides.mp4",34100,2780,69,"0:15"),
   demo("mountain","A little closer to the clouds","Kabir Sethi","@kabir.explores",
    "Travel","No rush. No noise. Just a trail and a view.",
    "photo-1464822759023-fed622ff2c3b","photo-1506794778202-cad84cf45f1d",
    "ForBiggerBlazes.mp4",61100,4900,206,"0:15"),
   demo("food","Sunday at my grandmother's table","Diya Nair","@diyakitchen",
    "Food","Comfort food tastes better when shared.",
    "photo-1547592180-85f173990554","photo-1524504388940-b1c1722653e1",
    "ForBiggerEscapes.mp4",29400,2600,91,"0:15"),
   demo("design","Inside my tiny creative studio","Rohan Das","@rohanbuilds",
    "Technology","How I built a workspace that lets ideas breathe.",
    "photo-1498050108023-c5249f4df085","photo-1507003211169-0a1dd7228f2d",
    "ForBiggerFun.mp4",12800,1160,42,"0:15"),
   demo("beach","Golden hour without a filter","Ishita Kapoor","@ishita.stories",
    "Travel","The kind of evening you remember forever.",
    "photo-1500375592092-40eb2168fd21","photo-1488426862026-3ee34a7d66df",
    "ForBiggerJoyrides.mp4",51300,3810,152,"0:15"),
   demo("books","A corner for your next favorite book","Neel Varma","@neel.reads",
    "Education","Three things I learned from a quiet weekend of reading.",
    "photo-1507842217343-583bb7270b66","photo-1506794778202-cad84cf45f1d",
    "ForBiggerBlazes.mp4",9500,730,31,"0:15"),
   demo("forest","The forest knows how to slow down","Tara Sen","@tarawild",
    "Nature","Five minutes away from the screen, a thousand miles away from the rush.",
    "photo-1448375240586-882707db888b","photo-1517841905240-472988babdf9",
    "BigBuckBunny.mp4",73600,6200,332,"9:56"),
   demo("dance","One song. One take. Pure joy.","Zoya Ali","@zoyamoves",
    "Music","The first try is sometimes the best one.",
    "photo-1508700115892-45ecd05ae2ad","photo-1534528741775-53994a69daeb",
    "ForBiggerFun.mp4",39900,4100,201,"0:15"),
   demo("architecture","There's art in every doorway","Aditya Bose","@aditya.sees",
    "Art","New details in a city I've known forever.",
    "photo-1486406146926-c627a92ad1ab","photo-1500648767791-00dcc994a43e",
    "ForBiggerEscapes.mp4",22400,1510,63,"0:15"),
   demo("camping","Stories worth staying up for","Nisha Paul","@nisha.outdoors",
    "Storytelling","When the fire gets low, the best stories begin.",
    "photo-1473448912268-2022ce9509d8","photo-1524504388940-b1c1722653e1",
    "ForBiggerBlazes.mp4",26500,1830,88,"0:15")
  );
 }
}
