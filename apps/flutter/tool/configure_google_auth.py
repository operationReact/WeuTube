#!/usr/bin/env python3
"""Configure generated Flutter Android/iOS runners for Cognito Google login.
No credentials embedded; OAuth code/PKCE returns via the weutube:// URI.
This script runs immediately after 'flutter create' in CI/deployment.
"""
from pathlib import Path
import plistlib

root = Path(__file__).resolve().parents[1]
manifest = root / "android/app/src/main/AndroidManifest.xml"
if manifest.exists():
    xml = manifest.read_text()
    if "com.linusu.flutter_web_auth_2.CallbackActivity" not in xml:
        activity = """
        <activity
            android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
            android:exported="true"
            android:taskAffinity="">
            <intent-filter android:label="weutube-google-auth">
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="weutube" android:host="auth-callback" />
            </intent-filter>
        </activity>
"""
        assert "</application>" in xml
        xml = xml.replace("</application>", activity + "    </application>")
        manifest.write_text(xml)

plist = root / "ios/Runner/Info.plist"
if plist.exists():
    with plist.open("rb") as stream:
        data = plistlib.load(stream)
    types = data.setdefault("CFBundleURLTypes", [])
    if not any("weutube" in t.get("CFBundleURLSchemes", []) for t in types):
        types.append({
            "CFBundleURLName": "com.weutube.oauth",
            "CFBundleURLSchemes": ["weutube"],
        })
        with plist.open("wb") as stream:
            plistlib.dump(data, stream)
