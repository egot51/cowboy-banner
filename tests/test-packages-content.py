#!/usr/bin/env python3
"""РџСЂРёС‘РјРѕС‡РЅР°СЏ РїСЂРѕРІРµСЂРєР° РІСЃРµС… С„РѕСЂРјР°С‚РѕРІ РїР°РєРµС‚РѕРІ.

    python tests/test-packages-content.py

РљР°Р¶РґС‹Р№ СЃРѕР±СЂР°РЅРЅС‹Р№ РїР°РєРµС‚ СЂР°СЃРїР°РєРѕРІС‹РІР°РµС‚СЃСЏ Рё СЃРІРµСЂСЏРµС‚СЃСЏ СЃ РёСЃС…РѕРґРЅС‹Рј РґРµСЂРµРІРѕРј
linux/files: СЃРѕСЃС‚Р°РІ С„Р°Р№Р»РѕРІ, РїСЂР°РІР° Рё СЃРѕРґРµСЂР¶РёРјРѕРµ (РїРѕ sha256).

РџСЂРѕРІРµСЂСЏСЋС‚СЃСЏ:
  - .deb  (Debian, Ubuntu) - data.tar.gz РёР· ar-Р°СЂС…РёРІР°
  - .rpm  (Fedora, RHEL)   - РїРѕР»РµР·РЅР°СЏ РЅР°РіСЂСѓР·РєР° cpio С‡РµСЂРµР· rpmfile
  - .zip  (Scoop, Chocolatey, winget) - С„Р°Р№Р»С‹ Windows-С‡Р°СЃС‚Рё

РџР»СЋСЃ СЃРІРµСЂСЏСЋС‚СЃСЏ РјР°РЅРёС„РµСЃС‚С‹: sha256 РІ РЅРёС… РґРѕР»Р¶РµРЅ СЃРѕРІРїР°РґР°С‚СЊ СЃ СЃРѕР±СЂР°РЅРЅС‹Рј zip.
"""
import hashlib
import io
import os
import shutil
import sys
import tarfile
import tempfile
import zipfile

import rpmfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIST = os.path.join(REPO, "dist")
VERSION = "1.0.0"
PASS = 0
FAIL = 0


def ok(msg):
    global PASS
    PASS += 1
    print(f"  OK   {msg}")


def bad(msg):
    global FAIL
    FAIL += 1
    print(f"  FAIL {msg}")


def sha(data):
    return hashlib.sha256(data).hexdigest()


def tree(root):
    """РЎР»РѕРІР°СЂСЊ {РїСѓС‚СЊ РѕС‚РЅРѕСЃРёС‚РµР»СЊРЅРѕ РєРѕСЂРЅСЏ: (sha256, РїСЂР°РІР°)}."""
    out = {}
    for dirpath, _dirs, names in os.walk(root):
        for n in names:
            full = os.path.join(dirpath, n)
            rel = os.path.relpath(full, root).replace("\\", "/")
            with open(full, "rb") as f:
                out[rel] = (sha(f.read()), os.stat(full).st_mode & 0o777)
    return out


def compare(name, got, want, ignore_gz=False):
    """РЎСЂР°РІРЅРёРІР°РµС‚ РґРІР° РґРµСЂРµРІР°: СЃРѕСЃС‚Р°РІ, СЃРѕРґРµСЂР¶РёРјРѕРµ, РїСЂР°РІР°."""
    def norm(k):
        return k[:-3] if ignore_gz and k.endswith(".gz") else k

    got_n = {norm(k): v for k, v in got.items()}
    want_n = {norm(k): v for k, v in want.items()}

    missing = sorted(set(want_n) - set(got_n))
    extra = sorted(set(got_n) - set(want_n))
    if missing:
        bad(f"{name}: РЅРµС‚ С„Р°Р№Р»РѕРІ: {missing[:5]}")
    if extra:
        bad(f"{name}: Р»РёС€РЅРёРµ С„Р°Р№Р»С‹: {extra[:5]}")
    if not missing and not extra:
        ok(f"{name}: СЃРѕСЃС‚Р°РІ С„Р°Р№Р»РѕРІ СЃРѕРІРїР°РґР°РµС‚ ({len(want_n)})")

    diff = [k for k in sorted(set(got_n) & set(want_n))
            if want_n[k][0] and got_n[k][0] != want_n[k][0]]
    if diff:
        bad(f"{name}: СЃРѕРґРµСЂР¶РёРјРѕРµ РѕС‚Р»РёС‡Р°РµС‚СЃСЏ: {diff[:5]}")
    else:
        ok(f"{name}: СЃРѕРґРµСЂР¶РёРјРѕРµ РІСЃРµС… С„Р°Р№Р»РѕРІ СЃРѕРІРїР°РґР°РµС‚")

    # РџСЂР°РІР°: РІ РёСЃС…РѕРґРЅРѕРј РґРµСЂРµРІРµ РЅР° Windows СЂРµР¶РёРјС‹ unix РЅРµ С…СЂР°РЅСЏС‚СЃСЏ, РїРѕСЌС‚РѕРјСѓ
    # СЃСЂР°РІРЅРёРІР°РµРј С‚РѕР»СЊРєРѕ С‚Рѕ, С‡С‚Рѕ РІР°Р¶РЅРѕ, - РёСЃРїРѕР»РЅСЏРµРјРѕСЃС‚СЊ СЃРєСЂРёРїС‚РѕРІ РІ РїР°РєРµС‚Рµ.
    for rel in ("usr/bin/cowboy-banner", "usr/lib/cowboy-banner/install.sh",
                "usr/lib/cowboy-banner/remove.sh"):
        if rel in want_n and rel in got_n:
            if got_n[rel][1] & 0o111:
                ok(f"{name}: {rel} РІ РїР°РєРµС‚Рµ РёСЃРїРѕР»РЅСЏРµРјС‹Р№")
            else:
                bad(f"{name}: {rel} РІ РїР°РєРµС‚Рµ РќР• РёСЃРїРѕР»РЅСЏРµРјС‹Р№")


def ar_members(data):
    """Р Р°Р·Р±РѕСЂ ar-Р°СЂС…РёРІР° (С„РѕСЂРјР°С‚ .deb)."""
    if data[:8] != b"!<arch>\n":
        raise ValueError("РЅРµ ar-Р°СЂС…РёРІ")
    members = {}
    off = 8
    while off + 60 <= len(data):
        header = data[off:off + 60]
        name = header[0:16].decode("ascii").strip()
        size = int(header[48:58].decode("ascii").strip())
        members[name] = data[off + 60:off + 60 + size]
        off += 60 + size + (size % 2)
    return members


def check_deb(path):
    print("\n.deb (Debian, Ubuntu, Mint)")
    with open(path, "rb") as f:
        members = ar_members(f.read())
    if set(members) != {"debian-binary", "control.tar.gz", "data.tar.gz"}:
        bad(f"СЃРѕСЃС‚Р°РІ ar-Р°СЂС…РёРІР°: {sorted(members)}")
        return
    ok("СЃРѕСЃС‚Р°РІ ar-Р°СЂС…РёРІР° РІРµСЂРЅС‹Р№")

    with tarfile.open(fileobj=io.BytesIO(members["data.tar.gz"])) as tf:
        got = {}
        for m in tf.getmembers():
            if not m.isfile():
                continue
            rel = m.name.lstrip("./")
            got[rel] = (sha(tf.extractfile(m).read()), m.mode & 0o777)
    want = tree(os.path.join(REPO, "linux", "files"))
    # Debian С‚СЂРµР±СѓРµС‚ РµС‰С‘ changelog Рё copyright РІ /usr/share/doc - РёС… РґРѕР±Р°РІР»СЏРµС‚
    # СЃР°Рј СЃР±РѕСЂС‰РёРє, РІ РѕР±С‰РµРј РґРµСЂРµРІРµ РёС… РЅРµС‚.
    want["usr/share/doc/cowboy-banner/changelog.Debian.gz"] = ("", 0o644)
    want["usr/share/doc/cowboy-banner/copyright"] = ("", 0o644)
    compare("deb", got, want)

    with tarfile.open(fileobj=io.BytesIO(members["control.tar.gz"])) as tf:
        names = sorted(m.name.lstrip("./") for m in tf.getmembers() if m.isfile())
    for want_name in ("control", "md5sums", "postinst", "prerm"):
        if want_name in names:
            ok(f"control.tar.gz: РµСЃС‚СЊ {want_name}")
        else:
            bad(f"control.tar.gz: РЅРµС‚ {want_name}")


def check_rpm(path):
    print("\n.rpm (Fedora, RHEL, openSUSE)")
    import gzip
    with rpmfile.open(path) as rpm:
        members = rpm.getmembers()
        got = {}
        for m in members:
            f = rpm.extractfile(m.name)
            if f is None:
                continue
            data = f.read()
            # rpmbuild СЃР¶РёРјР°РµС‚ man-СЃС‚СЂР°РЅРёС†С‹ РІ .gz - СЂР°СЃРїР°РєРѕРІС‹РІР°РµРј, С‡С‚РѕР±С‹
            # СЃСЂР°РІРЅРёРІР°С‚СЊ СЃРѕРґРµСЂР¶РёРјРѕРµ, Р° РЅРµ СѓРїР°РєРѕРІР°РЅРЅС‹Р№ РІРёРґ.
            if m.name.endswith(".gz"):
                try:
                    data = gzip.decompress(data)
                except OSError:
                    pass
            got[m.name.lstrip("./")] = (sha(data), m.mode & 0o777)
    want = tree(os.path.join(REPO, "linux", "files"))
    # rpmbuild СЃР¶РёРјР°РµС‚ man-СЃС‚СЂР°РЅРёС†Сѓ, nfpm - РЅРµС‚.
    compare("rpm", got, want, ignore_gz=True)


def check_zip(path):
    print("\n.zip (Scoop, Chocolatey, winget)")
    with zipfile.ZipFile(path) as zf:
        got = {}
        for info in zf.infolist():
            if info.is_dir():
                continue
            rel = info.filename.lstrip("./")
            mode = (info.external_attr >> 16) & 0o777
            got[rel] = (sha(zf.read(info.filename)), mode or 0o644)
    # Р’ zip Р»РµР¶Р°С‚ С„Р°Р№Р»С‹ Windows-С‡Р°СЃС‚Рё, СЂР°СЃРєР»Р°РґРєР° РґСЂСѓРіР°СЏ.
    want = {}
    pairs = {
        "cowboy.cmd": os.path.join(REPO, "windows", "cowboy.cmd"),
        "profile.ps1": os.path.join(REPO, "windows", "profile.ps1"),
        "cowboy-banner.ps1": os.path.join(REPO, "packaging", "windows", "cowboy-banner.ps1"),
        "install.ps1": os.path.join(REPO, "packaging", "windows", "install-profile.ps1"),
        "uninstall.ps1": os.path.join(REPO, "packaging", "windows", "remove-profile.ps1"),
        "README.md": os.path.join(REPO, "linux", "files", "usr/share/doc/cowboy-banner/README.md"),
        "LICENSE": os.path.join(REPO, "linux", "files", "usr/share/licenses/cowboy-banner/LICENSE"),
    }
    for rel, full in pairs.items():
        with open(full, "rb") as f:
            want[rel] = (sha(f.read()), 0o644)
    compare("zip", got, want)


def check_manifests():
    print("\nРњР°РЅРёС„РµСЃС‚С‹ (Scoop, winget)")
    import json
    import urllib.request

    # РњР°РЅРёС„РµСЃС‚ РґРѕР»Р¶РµРЅ РѕРїРёСЃС‹РІР°С‚СЊ С‚РѕС‚ Р°СЂС…РёРІ, РєРѕС‚РѕСЂС‹Р№ Р»РµР¶РёС‚ РІ Releases: РµРіРѕ РєР°С‡Р°СЋС‚
    # Scoop, Chocolatey Рё winget. Р›РѕРєР°Р»СЊРЅР°СЏ СЃР±РѕСЂРєР° РЅРµ РіРѕРґРёС‚СЃСЏ - СЃР¶Р°С‚РёРµ
    # Р·Р°РІРёСЃРёС‚ РѕС‚ РІРµСЂСЃРёРё zlib, Р° РІ CI Рё Сѓ СЂР°Р·СЂР°Р±РѕС‚С‡РёРєР° РѕРЅР° СЂР°Р·РЅР°СЏ.
    url = ("https://github.com/egot51/cowboy-banner/releases/download/v1.0.0/"
           "cowboy-banner-1.0.0-windows.zip")
    try:
        with urllib.request.urlopen(url, timeout=60) as r:
            digest = sha(r.read())
    except Exception as e:
        bad(f"РЅРµ СѓРґР°Р»РѕСЃСЊ СЃРєР°С‡Р°С‚СЊ Р°СЂС…РёРІ СЂРµР»РёР·Р°: {e}")
        return

    targets = [
        os.path.join(REPO, "packaging", "scoop", "cowboy-banner.json"),
        os.path.join(REPO, "packaging", "winget", "manifests", "e", "egot51", "cowboy-banner", VERSION,
                     "egot51.cowboy-banner.installer.yaml"),
    ]
    for t in targets:
        text = open(t, encoding="utf-8").read()
        if digest in text:
            ok(f"sha256 СЃРѕРІРїР°РґР°РµС‚ СЃ СЂРµР»РёР·РѕРј: {os.path.relpath(t, REPO)}")
        else:
            bad(f"sha256 РІ РјР°РЅРёС„РµСЃС‚Рµ РЅРµ СЃРѕРІРїР°РґР°РµС‚ СЃ СЂРµР»РёР·РѕРј: {os.path.relpath(t, REPO)}")

    # РЎСЃС‹Р»РєРё РІ РјР°РЅРёС„РµСЃС‚Р°С… РґРѕР»Р¶РЅС‹ СѓРєР°Р·С‹РІР°С‚СЊ РЅР° СЃСѓС‰РµСЃС‚РІСѓСЋС‰РёРµ С„Р°Р№Р»С‹ СЂРµР»РёР·Р°.
    scoop = json.load(open(targets[0], encoding="utf-8"))
    if "releases/download/v1.0.0/cowboy-banner-1.0.0-windows.zip" in scoop["url"]:
        ok("СЃСЃС‹Р»РєР° РІ РјР°РЅРёС„РµСЃС‚Рµ Scoop СѓРєР°Р·С‹РІР°РµС‚ РЅР° СЂРµР»РёР· v1.0.0")
    else:
        bad(f"РЅРµРѕР¶РёРґР°РЅРЅР°СЏ СЃСЃС‹Р»РєР° РІ Scoop: {url}")


def main():
    print("РџСЂРёС‘РјРєР° РІСЃРµС… С„РѕСЂРјР°С‚РѕРІ РїР°РєРµС‚РѕРІ")
    deb = os.path.join(DIST, "cowboy-banner_1.0.0_all.deb")
    rpm = os.path.join(DIST, "cowboy-banner-1.0.0-1.noarch.rpm")
    zf = os.path.join(DIST, "cowboy-banner-1.0.0-windows.zip")

    for p in (deb, rpm, zf):
        if not os.path.exists(p):
            bad(f"РЅРµС‚ Р°СЂС‚РµС„Р°РєС‚Р°: {os.path.basename(p)}")
    if FAIL:
        print("\nСЃРЅР°С‡Р°Р»Р° СЃРѕР±РµСЂРёС‚Рµ Р°СЂС‚РµС„Р°РєС‚С‹: .\\packaging\\build-all.ps1")
        return 1

    check_deb(deb)
    check_rpm(rpm)
    check_zip(zf)
    check_manifests()

    print("")
    print(f"РёС‚РѕРіРѕ: {PASS} OK, {FAIL} FAIL")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
