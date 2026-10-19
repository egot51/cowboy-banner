#!/usr/bin/env python3
"""Проверка собранного .rpm независимым парсером (rpmfile).

    python tests/test-rpm.py [файл.rpm]

Распаковывает пакет во временный каталог и сверяет с исходным деревом
linux/files: состав файлов, права и содержимое.
"""
import hashlib
import gzip
import lzma
import os
import shutil
import sys
import tempfile

import rpmfile


def extract_cpio(data, dest):
    """Распаковка cpio (формат newc) из полезной нагрузки RPM."""
    off = 0
    while off + 110 <= len(data):
        magic = data[off:off + 6]
        if magic not in (b"070701", b"070702"):
            break

        def num(pos):
            return int(data[pos:pos + 8], 16)

        mode = num(off + 14)
        filesize = num(off + 54)
        namesize = num(off + 94)
        name = data[off + 110:off + 110 + namesize - 1].decode("utf-8", "replace")
        off += 110 + namesize
        off += (4 - off % 4) % 4
        if name == "TRAILER!!!":
            break
        body = data[off:off + filesize]
        off += filesize
        off += (4 - off % 4) % 4
        if name == ".":
            continue
        rel = name.lstrip("./")
        target = os.path.join(dest, rel)
        if name.endswith("/"):
            os.makedirs(target, exist_ok=True)
            continue
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as f:
            f.write(body)
        os.chmod(target, mode & 0o7777)

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
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


def check(msg, got, want):
    if str(got) == str(want):
        ok(msg)
    else:
        bad(f"{msg} (получено '{got}', ждели '{want}')")


def text(value):
    """Значения заголовка rpmfile приходят байтами."""
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return value


def main():
    rpm_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        REPO, "dist", "cowboy-banner-1.0.0-1.noarch.rpm"
    )
    if not os.path.exists(rpm_path):
        print(f"нет {rpm_path}")
        return 1
    print(f"проверяем {os.path.basename(rpm_path)}")

    tmp = tempfile.mkdtemp(prefix="cowboy-rpm-")
    try:
        with rpmfile.open(rpm_path) as rpm:
            h = rpm.headers
            check("имя пакета", text(h["name"]), "cowboy-banner")
            check("версия", text(h["version"]), "1.0.0")
            check("релиз", text(h["release"]), "1")
            check("архитектура", text(h["arch"]), "noarch")
            check("лицензия", text(h["copyright"]), "MIT")
            check("адрес", text(h["url"]), "https://github.com/egot51/cowboy-banner")
            check("формат полезной нагрузки", text(h["archive_format"]), "cpio")
            check("сжатие", text(h["archive_compression"]), "xz")
            check("группа", text(h["group"]), "Applications/System")
            ok(f"описание: {text(h['summary'])[:50]}...")
            ok(f"подробное описание: {len(text(h['description']))} символов")

            requires = [text(r) for r in h.get("requirename", [])]
            ok(f"зависимости: {', '.join(requires) or 'нет'}")
            check("требует bash", "bash" in requires, True)
            check("требует coreutils", "coreutils" in requires, True)

            # Скриплеты установки и удаления.
            postin = text(h.get("postin", b""))
            preun = text(h.get("preun", b""))
            check("скрипт postinstall на месте", "install.sh" in postin or "MARK_BEGIN" in postin, True)
            check("скрипт preremove на месте", "remove.sh" in preun or "MARK_BEGIN" in preun, True)
            check("скриплеты выполняются через sh", text(h.get("postinprog", b"")), "/bin/sh")

            # Состав пакета: список файлов с правами из заголовка.
            src = os.path.join(REPO, "linux", "files")
            src_files = []
            for dirpath, _dirs, names in os.walk(src):
                for n in names:
                    rel = os.path.relpath(os.path.join(dirpath, n), src).replace("\\", "/")
                    src_files.append(rel)
            src_files.sort()

            members = rpm.getmembers()
            names = [m.name.lstrip("./") for m in members]
            check("файлов в пакете", len(names), len(src_files))
            missing = [f for f in src_files if f not in names]
            extra = [f for f in names if f not in src_files]
            if missing:
                bad(f"нет в пакете: {missing[:5]}")
            if extra:
                bad(f"лишние в пакете: {extra[:5]}")
            if not missing and not extra:
                ok("состав файлов совпадает с исходным деревом")

            # Права: скрипты и хуки должны быть исполняемыми.
            modes = {m.name.lstrip("./"): m.mode for m in members}
            for rel in ("usr/bin/cowboy-banner",
                        "usr/lib/cowboy-banner/install.sh",
                        "usr/lib/cowboy-banner/remove.sh"):
                if rel not in modes:
                    bad(f"нет {rel}")
                    continue
                check(f"{rel} исполняемый", bool(modes[rel] & 0o111), True)

            # Содержимое главного скрипта - побайтово.
            a = os.path.join(src, "usr", "bin", "cowboy-banner")
            b = rpm.extractfile("./usr/bin/cowboy-banner")
            if b is not None:
                got = b.read()
                want = open(a, "rb").read()
                check("размер скрипта совпадает", len(got), len(want))
                check("sha256 скрипта совпадает",
                      hashlib.sha256(got).hexdigest(),
                      hashlib.sha256(want).hexdigest())
                check("в скрипте нет CR", b"\r" in got, False)
            else:
                bad("скрипт не извлекается")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("")
    print(f"итого: {PASS} OK, {FAIL} FAIL")
    return 1 if FAIL else 0


if __name__ == "__main__":
    sys.exit(main())
