#!/usr/bin/env python3
"""Generate platform icons from the approved WeuTube SVG artwork.

This is run AFTER 'flutter create' so platform scaffolding cannot restore
Flutter's default icon. No substitute font or reconstructed mark is used.
"""
from __future__ import annotations

import io
import json
import re
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ICON = ROOT / "assets" / "brand" / "weutube-icon.svg"
LOGO = ROOT / "assets" / "brand" / "weutube-logo.svg"

for path in (ICON, LOGO):
    if not path.is_file():
        raise SystemExit(f"Missing approved brand SVG: {path}")
source = ICON.read_text()
if "#031B4B" not in source or "#FE3F23" not in source:
    raise SystemExit("Approved WeuTube SVG colors do not match the brand master")

def raster_icon(size: int, *, maskable: bool = False) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), "white")
    width = round(size * (0.69 if maskable else 0.82))
    rendered = cairosvg.svg2png(bytestring=source.encode(), output_width=width)
    artwork = Image.open(io.BytesIO(rendered)).convert("RGBA")
    xy = ((size - artwork.width) // 2, (size - artwork.height) // 2)
    canvas.alpha_composite(artwork, xy)
    return canvas.convert("RGB")

def write_png(path: Path, size: int, *, maskable: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raster_icon(size, maskable=maskable).save(path, optimize=True)

# Website favicon / installed PWA launcher.
web = ROOT / "web"
if web.is_dir():
    write_png(web / "favicon.png", 48)
    write_png(web / "icons" / "Icon-192.png", 192)
    write_png(web / "icons" / "Icon-512.png", 512)
    write_png(web / "icons" / "Icon-maskable-192.png", 192, maskable=True)
    write_png(web / "icons" / "Icon-maskable-512.png", 512, maskable=True)
    manifest = web / "manifest.json"
    if manifest.is_file():
        obj = json.loads(manifest.read_text())
        obj.update(name="WeuTube", short_name="WeuTube",
                   background_color="#FFFFFF", theme_color="#031B4B")
        manifest.write_text(json.dumps(obj, indent=2) + "\n")
    index = web / "index.html"
    if index.is_file():
        html = index.read_text()
        html = re.sub(r"<title>.*?</title>",
                      "<title>WeuTube | Creator Community</title>",
                      html, flags=re.DOTALL)
        html = re.sub(r'<meta name="apple-mobile-web-app-title" content="[^"]*">',
                      '<meta name="apple-mobile-web-app-title" content="WeuTube">', html)
        html = re.sub(r'<meta name="theme-color" content="[^"]*">',
                      '<meta name="theme-color" content="#031B4B">', html)
        index.write_text(html)

# Native Android launcher icons, copied into scaffolded mipmap folders.
android = ROOT / "android" / "app" / "src" / "main"
if android.is_dir():
    for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96),
                          ("xxhdpi", 144), ("xxxhdpi", 192)):
        write_png(android / "res" / f"mipmap-{density}" / "ic_launcher.png", size)
    manifest = android / "AndroidManifest.xml"
    if manifest.is_file():
        xml = manifest.read_text()
        xml = xml.replace('android:label="weutube"', 'android:label="WeuTube"')
        manifest.write_text(xml)

# Native iOS icon catalog; resize each icon referenced by Contents.json.
ios_catalog = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
contents = ios_catalog / "Contents.json"
if contents.is_file():
    manifest = json.loads(contents.read_text())
    for entry in manifest.get("images", []):
        filename = entry.get("filename")
        point_size = entry.get("size", "")
        scale = entry.get("scale", "1x")
        if not filename or "x" not in point_size:
            continue
        size = round(float(point_size.split("x", 1)[0]) * float(scale.rstrip("x")))
        write_png(ios_catalog / filename, size)

print("Generated WeuTube web, Android and iOS launcher branding from approved SVG.")
