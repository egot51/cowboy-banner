#!/usr/bin/env python3
"""Приёмочная проверка всех форматов пакетов.

    python tests/test-packages-content.py

Каждый собранный пакет распаковывается и сверяется с исходным деревом
linux/files: состав файлов, права и содержимое (по sha256).

Проверяются:
  - .deb  (Debian, Ubuntu) - data.tar.gz из ar-архива
  - .rpm  (Fedora, RHEL)   - полезная нагрузка cpio через rpmfile
  - .zip  (Scoop, Chocolatey, winget) - файлы Windows-части

Плюс сверяются манифесты: sha256 в них должен совпадать с собранным zip.
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
    """Словарь {путь относительно корня: (sha256, права)}."""
    out = {}
    for dirpath, _dirs, names in os.walk(root):
        for n in names:
            full = os.path.join(dirpath, n)
            rel = os.path.relpath(full, root).replace("\\", "/")
            with open(full, "rb") as f:
                out[rel] = (sha(f.read()), os.stat(full).st_mode & 0o777)
    return out


def compare(name, got, want, ignore_gz=False):
    """Сравнивает два дерева: состав, содержимое, права."""
    def norm(k):
        return k[:-3] if ignore_gz and k.endswith(".gz") else k

    got_n = {norm(k): v for k, v in got.items()}
    want_n = {norm(k): v for k, v in want.items()}

    missing = sorted(set(want_n) - set(got_n))
    extra = sorted(set(got_n) - set(want_n))
    if missing:
        bad(f"{name}: нет файлов: {missing[:5]}")
    if extra:
        bad(f"{name}: лишние файлы: {extra[:5]}")
    if not missing and not extra:
        ok(f"{name}: состав файлов совпадает ({len(want_n)})")

    diff = [k for k in sorted(set(got_n) & set(want_n))
            if want_n[k][0] and got_n[k][0] != want_n[k][0]]
    if diff:
        bad(f"{name}: содержимое отличается: {diff[:5]}")
    else:
        ok(f"{name}: содержимое всех файлов совпадает")

    # Права: в исходном дереве на Windows режимы unix не хранятся, поэтому
    # сравниваем только то, что важно, - исполняемость скриптов в пакете.
    for rel in ("usr/bin/cowboy-banner", "usr/lib/cowboy-banner/install.sh",
                "usr/lib/cowboy-banner/remove.sh"):
        if rel in want_n and rel in got_n:
            if got_n[rel][1] & 0o111:
                ok(f"{name}: {rel} в пакете исполняемый")
            else:
                bad(f"{name}: {rel} в пакете НЕ исполняемый")


def ar_members(data):
    """Разбор ar-архива (формат .deb)."""
    if data[:8] != b"!<arch>\n":
        raise ValueError("не ar-архив")
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
        bad(f"состав ar-архива: {sorted(members)}")
        return
    ok("состав ar-архива верный")

    with tarfile.open(fileobj=io.BytesIO(members["data.tar.gz"])) as tf:
        got = {}
        for m in tf.getmembers():
            if not m.isfile():
                continue
            rel = m.name.lstrip("./")
            got[rel] = (sha(tf.extractfile(m).read()), m.mode & 0o777)
    want = tree(os.path.join(REPO, "linux", "files"))
    # Debian требует ещё changelog и copyright в /usr/share/doc - их добавляет
    # сам сборщик, в общем дереве их нет.
    want["usr/share/doc/cowboy-banner/changelog.Debian.gz"] = ("", 0o644)
    want["usr/share/doc/cowboy-banner/copyright"] = ("", 0o644)
    compare("deb", got, want)

    with tarfile.open(fileobj=io.BytesIO(members["control.tar.gz"])) as tf:
        names = sorted(m.name.lstrip("./") for m in tf.getmembers() if m.isfile())
    for want_name in ("control", "md5sums", "postinst", "prerm"):
        if want_name in names:
            ok(f"control.tar.gz: есть {want_name}")
        else:
            bad(f"control.tar.gz: нет {want_name}")


def check_rpm(path):
    print("\n.rpm (Fedora, RHEL, openSUSE)")
    with rpmfile.open(path) as rpm:
        members = rpm.getmembers()
        got = {}
        for m in members:
            f = rpm.extractfile(m.name)
            if f is None:
                continue
            got[m.name.lstrip("./")] = (sha(f.read()), m.mode & 0o777)
    want = tree(os.path.join(REPO, "linux", "files"))
    # rpmbuild сжимает man-страницу, nfpm - нет.
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
    # В zip лежат файлы Windows-части, раскладка другая.
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
    print("\nМанифесты (Scoop, winget)")
    zip_path = os.path.join(DIST, "cowboy-banner-1.0.0-windows.zip")
    if not os.path.exists(zip_path):
        bad("нет собранного zip - манифесты не сверяем")
        return
    with open(zip_path, "rb") as f:
        digest = sha(f.read())

    targets = [
        os.path.join(REPO, "packaging", "scoop", "cowboy-banner.json"),
        os.path.join(REPO, "packaging", "winget", "manifests", "e", "egot51", "cowboy-banner", "1.0.0",
                     "egot51.cowboy-banner.installer.yaml"),
    ]
    for t in targets:
        text = open(t, encoding="utf-8").read()
        if digest in text:
            ok(f"sha256 совпадает: {os.path.relpath(t, REPO)}")
        else:
            bad(f"sha256 в манифесте не совпадает: {os.path.relpath(t, REPO)}")

    # Ссылки в манифестах должны указывать на существующие файлы релиза.
    import json
    scoop = json.load(open(targets[0], encoding="utf-8"))
    url = scoop["url"]
    if "releases/download/v1.0.0/cowboy-banner-1.0.0-windows.zip" in url:
        ok("ссылка в манифесте Scoop указывает на релиз v1.0.0")
    else:
        bad(f"неожиданная ссылка в Scoop: {url}")


def main():
    print("Приёмка всех форматов пакетов")
    deb = os.path.join(DIST, "cowboy-banner_1.0.0_all.deb")
    rpm = os.path.join(DIST, "cowboy-banner-1.0.0-1.noarch.rpm")
    zf = os.path.join(DIST, "cowboy-banner-1.0.0-windows.zip")

    for p in (deb, rpm, zf):
        if not os.path.exists(p):
            bad(f"нет артефакта: {os.path.basename(p)}")
    if FAIL:
        print("\nсначала соберите артефакты: .\\packaging\\build-all.ps1")
        return 1

    check_deb(deb)
    check_rpm(rpm)
    check_zip(zf)
    check_manifests()

    print("")
    print(f"итого: {PASS} OK, {FAIL} FAIL")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
