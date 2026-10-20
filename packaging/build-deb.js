// Сборка .deb без dpkg-deb: формат .deb - это ar-архив с тремя членами
// (debian-binary, control.tar.gz, data.tar.gz), поэтому он собирается
// вручную. Ни tar, ни gzip не нужны: tar пишется здесь, сжатие - zlib.
//
//   node packaging/build-deb.js [опции]
//     --payload <dir>    дерево файлов пакета (по умолчанию linux/files)
//     --out <file>       куда положить .deb (по умолчанию dist/)
//     --version <ver>    версия пакета (по умолчанию из debian/control)
//     --maintainer "Имя <email>"   заменить Maintainer в control
//     --source-date <unix>  дата файлов (для воспроизводимой сборки)
const fs = require("fs");
const os = require("os");
const path = require("path");
const zlib = require("zlib");
const crypto = require("crypto");

const REPO = path.join(__dirname, "..");
const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
};

const payloadDir = path.resolve(opt("--payload", path.join(REPO, "linux", "files")));
const outDir = path.resolve(opt("--out", path.join(REPO, "dist")));
const debianDir = path.join(__dirname, "debian");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "cowboy-deb-"));
// Воспроизводимая сборка: если задан SOURCE_DATE_EPOCH, используем его,
// иначе - текущее время. Одинаковый вход даёт одинаковый .deb побайтово.
const mtime = opt("--source-date", process.env.SOURCE_DATE_EPOCH || String(Math.floor(Date.now() / 1000)));

// --- control -------------------------------------------------------------
let control = fs.readFileSync(path.join(debianDir, "control"), "utf8");
const version = opt("--version", (control.match(/^Version:\s*(.+)$/m) || [, "1.0.0"])[1].trim());
const maintainer = opt("--maintainer", null);
if (maintainer) {
  control = control.replace(/^Maintainer:.*$/m, `Maintainer: ${maintainer}`);
}
control = control.replace(/^Version:.*$/m, `Version: ${version}`);

// --- раскладка данных ----------------------------------------------------
const stage = path.join(tmp, "root");
const copy = (rel) => {
  const from = path.join(payloadDir, rel);
  const to = path.join(stage, rel);
  fs.mkdirSync(path.dirname(to), { recursive: true });
  fs.copyFileSync(from, to);
  fs.chmodSync(to, rel === "usr/bin/cowboy-banner" ? 0o755 : 0o644);
};
const walk = (dir, base = "") => {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? `${base}/${e.name}` : e.name;
    if (e.isDirectory()) walk(path.join(dir, e.name), rel);
    else copy(rel);
  }
};
if (!fs.existsSync(payloadDir)) {
  console.error(`нет дерева файлов: ${payloadDir}`);
  console.error("сначала соберите пакет: node tools/gen-linux.js");
  process.exit(1);
}
walk(payloadDir);

// Документация: control, changelog и copyright по правилам Debian.
const docDir = path.join(stage, "usr/share/doc/cowboy-banner");
fs.mkdirSync(docDir, { recursive: true });
fs.writeFileSync(path.join(docDir, "copyright"), fs.readFileSync(path.join(debianDir, "copyright")));
fs.writeFileSync(
  path.join(docDir, "changelog.Debian.gz"),
  zlib.gzipSync(fs.readFileSync(path.join(debianDir, "changelog")), { level: 9 })
);

// --- control.tar.gz ------------------------------------------------------
const ctrlDir = path.join(tmp, "control");
fs.mkdirSync(ctrlDir, { recursive: true });
fs.writeFileSync(path.join(ctrlDir, "control"), control);
fs.copyFileSync(path.join(debianDir, "postinst"), path.join(ctrlDir, "postinst"));
fs.copyFileSync(path.join(debianDir, "prerm"), path.join(ctrlDir, "prerm"));
fs.chmodSync(path.join(ctrlDir, "postinst"), 0o755);
fs.chmodSync(path.join(ctrlDir, "prerm"), 0o755);

// md5sums - обязательный файл: суммы всех файлов данных.
const files = [];
const collect = (dir, base = "") => {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? `${base}/${e.name}` : e.name;
    if (e.isDirectory()) collect(path.join(dir, e.name), rel);
    else files.push(rel);
  }
};
collect(stage);
files.sort();
const md5sums = files
  .map((rel) => {
    const sum = crypto.createHash("md5").update(fs.readFileSync(path.join(stage, rel))).digest("hex");
    return `${sum}  ${rel}`;
  })
  .join("\n");
fs.writeFileSync(path.join(ctrlDir, "md5sums"), md5sums + "\n");

// --- tar -----------------------------------------------------------------
// Пишем tar (ustar) сами: 512-байтные заголовки, данные с выравниванием.
// typeflag: 5 - каталог, 0 - обычный файл. Если каталог пометить как файл,
// dpkg создаст вместо него пустой файл с именем каталога.
const octal = (value, width) => value.toString(8).padStart(width - 1, "0") + "\0";
const tarHeader = (name, size, mode, isDir = false) => {
  const h = Buffer.alloc(512);
  h.write(name, 0, "utf8");                       // имя (до 100 байт)
  h.write(octal(mode, 8), 100, "ascii");         // права
  h.write(octal(0, 8), 108, "ascii");            // uid
  h.write(octal(0, 8), 116, "ascii");            // gid
  h.write(size.toString(8).padStart(11, "0") + "\0", 124, "ascii");
  h.write(octal(Number(mtime), 12), 136, "ascii");
  h.write("        ", 148, "ascii");              // chksum - заполним ниже
  h.write(isDir ? "5" : "0", 156, "ascii");      // тип записи
  h.write("ustar\0" + "00", 257, "ascii");
  h.write("root", 265, "ascii");
  h.write("root", 297, "ascii");
  let sum = 0;
  for (const b of h) sum += b;
  h.write(sum.toString(8).padStart(6, "0") + "\0 ", 148, "ascii");
  return h;
};

// Собирает tar.gz из каталога: сначала идут каталоги, потом файлы,
// пути начинаются с "./" - так делает dpkg-deb.
const tarGz = (dir, execNames = new Set()) => {
  const parts = [];
  const walk = (current, prefix) => {
    const entries = fs.readdirSync(current, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name));
    for (const e of entries) {
      const full = path.join(current, e.name);
      const rel = `${prefix}${e.name}`;
      if (e.isDirectory()) {
        parts.push(tarHeader(`${rel}/`, 0, 0o755, true));
        walk(full, `${rel}/`);
      } else {
        const data = fs.readFileSync(full);
        // Исполняемым делаем всё, что лежит в bin/ и lib/, все скрипты .sh
        // и перечисленные файлы (maintainer-скрипты в control.tar.gz):
        // иначе postinst не сможет запустить хуки установки.
        const exec = /\/(bin|sbin|lib)\//.test(rel) || rel.endsWith(".sh") || execNames.has(e.name);
        parts.push(tarHeader(rel, data.length, exec ? 0o755 : 0o644));
        parts.push(data);
        const pad = data.length % 512;
        if (pad) parts.push(Buffer.alloc(512 - pad));
      }
    }
  };
  walk(dir, "./");
  parts.push(Buffer.alloc(1024)); // два нулевых блока в конце
  return zlib.gzipSync(Buffer.concat(parts), { level: 9 });
};

const dataTgz = tarGz(stage);
const controlTgz = tarGz(ctrlDir, new Set(["postinst", "prerm"]));
// Формат ar: магия "!<arch>\n", затем для каждого члена 60-байтный
// заголовок и данные, дополненные до чётной длины.
const arMember = (name, data) => {
  const header = Buffer.alloc(60);
  header.write(name.padEnd(16), 0, "ascii");   // имя
  header.write("0".padEnd(12), 16, "ascii");   // mtime
  header.write("0".padEnd(6), 28, "ascii");    // uid
  header.write("0".padEnd(6), 34, "ascii");    // gid
  header.write("100644".padEnd(8), 40, "ascii"); // mode
  header.write(String(data.length).padEnd(10), 48, "ascii");
  header.write("`\n", 58, "ascii");
  const pad = data.length % 2 ? "\n" : "";
  return Buffer.concat([header, data, Buffer.from(pad, "ascii")]);
};

const outFile = path.join(outDir, `cowboy-banner_${version}_all.deb`);
fs.mkdirSync(outDir, { recursive: true });
const ar = Buffer.concat([
  Buffer.from("!<arch>\n", "ascii"),
  arMember("debian-binary", Buffer.from("2.0\n", "ascii")),
  arMember("control.tar.gz", controlTgz),
  arMember("data.tar.gz", dataTgz),
]);
fs.writeFileSync(outFile, ar);

fs.rmSync(tmp, { recursive: true, force: true });
console.log(`  ${path.relative(REPO, outFile)} - ${(ar.length / 1024).toFixed(1)} КБ, ${files.length} файлов, версия ${version}`);
if (maintainer) console.log(`  Maintainer: ${maintainer}`);
