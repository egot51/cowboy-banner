// Проверка собранного .deb: разбирает ar-архив, сверяет состав файлов,
// суммы md5 и права. Это то, что делает dpkg при установке.
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const crypto = require("crypto");

const REPO = path.join(__dirname, "..");
let pass = 0;
let fail = 0;
const ok = (m) => { pass++; console.log(`  OK   ${m}`); };
const bad = (m) => { fail++; console.log(`  FAIL ${m}`); };
const check = (m, got, want) => (String(got) === String(want) ? ok(m) : bad(`${m} (получено '${got}', ждали '${want}')`));

// --- разбор ar -----------------------------------------------------------
const parseAr = (buf) => {
  if (buf.slice(0, 8).toString("ascii") !== "!<arch>\n") throw new Error("не ar-архив");
  const members = {};
  let off = 8;
  while (off + 60 <= buf.length) {
    const name = buf.slice(off, off + 16).toString("ascii").trim();
    const size = parseInt(buf.slice(off + 48, off + 58).toString("ascii").trim(), 10);
    const data = buf.slice(off + 60, off + 60 + size);
    members[name] = data;
    off += 60 + size + (size % 2);
  }
  return members;
};

// --- разбор tar ----------------------------------------------------------
const parseTar = (buf) => {
  const files = {};
  let off = 0;
  while (off + 512 <= buf.length) {
    const header = buf.slice(off, off + 512);
    if (header.every((b) => b === 0)) break;
    const name = header.slice(0, 100).toString("utf8").replace(/\0.*$/, "");
    const size = parseInt(header.slice(124, 136).toString("ascii").replace(/\0.*$/, "").trim(), 8);
    const mode = parseInt(header.slice(100, 108).toString("ascii").replace(/\0.*$/, "").trim(), 8);
    const data = buf.slice(off + 512, off + 512 + size);
    files[name.replace(/^\.\//, "")] = { data, mode };
    off += 512 + Math.ceil(size / 512) * 512;
  }
  return files;
};

const debPath = process.argv[2] || path.join(REPO, "dist", "cowboy-banner_1.0.0_all.deb");
if (!fs.existsSync(debPath)) {
  console.error(`нет файла ${debPath} - сначала: node packaging/build-deb.js`);
  process.exit(1);
}
console.log(`проверяем ${path.basename(debPath)}`);

const members = parseAr(fs.readFileSync(debPath));
check("три члена ar", Object.keys(members).sort().join(","), "control.tar.gz,data.tar.gz,debian-binary");
check("debian-binary = 2.0", members["debian-binary"].toString("ascii"), "2.0\n");

// --- control -------------------------------------------------------------
const ctrl = parseTar(zlib.gunzipSync(members["control.tar.gz"]));
for (const f of ["control", "md5sums", "postinst", "prerm"]) {
  ctrl[f] ? ok(`control.tar.gz: ${f}`) : bad(`control.tar.gz: нет ${f}`);
}
const controlText = ctrl["control"].data.toString("utf8");
for (const field of ["Package:", "Version:", "Architecture:", "Maintainer:", "Description:"]) {
  controlText.includes(field) ? ok(`control: есть ${field}`) : bad(`control: нет ${field}`);
}
check("Architecture: all", /Architecture:\s*(\S+)/.exec(controlText)[1], "all");
check("postinst исполняемый", ctrl["postinst"].mode & 0o111 ? "да" : "нет", "да");
check("prerm исполняемый", ctrl["prerm"].mode & 0o111 ? "да" : "нет", "да");

// --- данные --------------------------------------------------------------
const data = parseTar(zlib.gunzipSync(members["data.tar.gz"]));
const expected = [
  "usr/bin/cowboy-banner",
  "usr/share/cowboy-banner/profile.ps1",
  "usr/share/man/man1/cowboy-banner.1",
  "usr/share/doc/cowboy-banner/README.md",
  "usr/share/doc/cowboy-banner/changelog.Debian.gz",
  "usr/share/doc/cowboy-banner/copyright",
  "usr/share/licenses/cowboy-banner/LICENSE",
  "etc/skel/Default/.config/powershell/Microsoft.PowerShell_profile.ps1",
];
for (const f of expected) {
  data[f] ? ok(`данные: ${f}`) : bad(`данных нет: ${f}`);
}
const art = Object.keys(data).filter((f) => f.startsWith("usr/share/cowboy-banner/art/") && !f.endsWith("/"));
const texts = Object.keys(data).filter((f) => f.startsWith("usr/share/cowboy-banner/data/") && !f.endsWith("/"));
check("10 картинок", art.length, 10);
check("21 файл данных", texts.length, 21);
check("скрипт исполняемый", data["usr/bin/cowboy-banner"].mode & 0o111 ? "да" : "нет", "да");

// В bash-скрипте не должно быть CRLF: bash такие файлы ломает.
const script = data["usr/bin/cowboy-banner"].data;
check("в скрипте нет CR", script.includes(13) ? "есть" : "нет", "нет");
check("shebang на месте", script.slice(0, 20).toString("utf8").startsWith("#!/usr/bin/env bash") ? "да" : "нет", "да");

// --- md5sums -------------------------------------------------------------
const sums = ctrl["md5sums"].data.toString("utf8").trim().split("\n");
let sumOk = 0;
let sumBad = 0;
for (const line of sums) {
  const [sum, rel] = line.split(/\s+/, 2);
  const f = data[rel];
  if (!f) { sumBad++; continue; }
  const real = crypto.createHash("md5").update(f.data).digest("hex");
  if (real === sum) sumOk++;
  else sumBad++;
}
check("все md5sums совпали", `${sumOk} верно, ${sumBad} неверно`, `${sums.length} верно, 0 неверно`);

console.log("");
console.log(`итого: ${pass} OK, ${fail} FAIL`);
process.exit(fail ? 1 : 0);
