// Сборка zip-артефакта для Windows-пакетов (Scoop, Chocolatey, winget).
// Формат zip пишется вручную: zip-архив с deflate через zlib.
//
//   node packaging/build-zip.js [опции]
//     --out <file>      куда положить zip (по умолчанию dist/)
//     --version <ver>   версия (по умолчанию 1.0.0)
//
// В архив кладутся файлы Windows-части проекта: баннер для cmd, профиль
// PowerShell, установщик и документация.
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const REPO = path.join(__dirname, "..");
const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
};
const version = opt("--version", "1.0.0");
const outDir = path.resolve(opt("--out", path.join(REPO, "dist")));

// --- zip -----------------------------------------------------------------
// Локальный заголовок, центральный каталог и запись в конце архива.
const dosTime = (date) => {
  const time = ((date.getHours() << 11) | (date.getMinutes() << 5) | (date.getSeconds() >> 1)) & 0xffff;
  const day = (((date.getFullYear() - 1980) << 9) | ((date.getMonth() + 1) << 5) | date.getDate()) & 0xffff;
  return { time, day };
};

const makeZip = (files, date = new Date()) => {
  const { time, day } = dosTime(date);
  const locals = [];
  const centrals = [];
  let offset = 0;

  for (const f of files) {
    const nameBuf = Buffer.from(f.name, "utf8");
    const raw = f.data;
    const deflated = zlib.deflateRawSync(raw, { level: 9 });
    // Если сжатие не помогло, кладём как есть - так быстрее для мелких файлов.
    const useDeflate = deflated.length < raw.length;
    const body = useDeflate ? deflated : raw;
    const method = useDeflate ? 8 : 0;
    const crc = zlib.crc32(raw);

    const local = Buffer.alloc(30);
    local.writeUInt32LE(0x04034b50, 0);
    local.writeUInt16LE(20, 4);          // версия
    local.writeUInt16LE(0, 6);           // флаги
    local.writeUInt16LE(method, 8);
    local.writeUInt16LE(time, 10);
    local.writeUInt16LE(day, 12);
    local.writeUInt32LE(crc, 14);
    local.writeUInt32LE(body.length, 18);
    local.writeUInt32LE(raw.length, 22);
    local.writeUInt16LE(nameBuf.length, 26);
    local.writeUInt16LE(0, 28);
    locals.push(local, nameBuf, body);

    const central = Buffer.alloc(46);
    central.writeUInt32LE(0x02014b50, 0);
    central.writeUInt16LE(20, 4);        // версия
    central.writeUInt16LE(20, 6);        // версия нужна
    central.writeUInt16LE(0, 8);
    central.writeUInt16LE(method, 10);
    central.writeUInt16LE(time, 12);
    central.writeUInt16LE(day, 14);
    central.writeUInt32LE(crc, 16);
    central.writeUInt32LE(body.length, 20);
    central.writeUInt32LE(raw.length, 24);
    central.writeUInt16LE(nameBuf.length, 28);
    central.writeUInt16LE(0, 30);
    central.writeUInt16LE(0, 32);
    central.writeUInt16LE(0, 34);
    central.writeUInt16LE(0, 36);
    central.writeUInt32LE(f.exec ? 0o755 << 16 : 0o644 << 16, 38);
    central.writeUInt32LE(offset, 42);
    centrals.push(central, nameBuf);

    offset += local.length + nameBuf.length + body.length;
  }

  const centralBuf = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(0, 4);
  end.writeUInt16LE(0, 6);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(centralBuf.length, 12);
  end.writeUInt32LE(offset, 16);
  end.writeUInt16LE(0, 20);
  return Buffer.concat([...locals, centralBuf, end]);
};

// --- состав --------------------------------------------------------------
const read = (p) => fs.readFileSync(p);
const files = [
  { name: "cowboy.cmd", data: read(path.join(REPO, "windows", "cowboy.cmd")), exec: false },
  { name: "profile.ps1", data: read(path.join(REPO, "windows", "profile.ps1")), exec: false },
  { name: "cowboy-banner.ps1", data: read(path.join(__dirname, "windows", "cowboy-banner.ps1")), exec: false },
  { name: "install.ps1", data: read(path.join(__dirname, "windows", "install-profile.ps1")), exec: false },
  { name: "uninstall.ps1", data: read(path.join(__dirname, "windows", "remove-profile.ps1")), exec: false },
  { name: "README.md", data: read(path.join(REPO, "linux", "files", "usr/share/doc/cowboy-banner/README.md")), exec: false },
  { name: "LICENSE", data: read(path.join(REPO, "linux", "files", "usr/share/licenses/cowboy-banner/LICENSE")), exec: false },
];

const outFile = path.join(outDir, `cowboy-banner-${version}-windows.zip`);
fs.mkdirSync(outDir, { recursive: true });
const zip = makeZip(files);
fs.writeFileSync(outFile, zip);

// sha256 - он пойдёт в манифесты Scoop, Chocolatey и winget.
const crypto = require("crypto");
const sha256 = crypto.createHash("sha256").update(zip).digest("hex");
fs.writeFileSync(path.join(outDir, `cowboy-banner-${version}-windows.zip.sha256`), `${sha256}  ${path.basename(outFile)}\n`);

console.log(`  ${path.relative(REPO, outFile)} - ${(zip.length / 1024).toFixed(1)} КБ, ${files.length} файлов`);
console.log(`  sha256: ${sha256}`);
