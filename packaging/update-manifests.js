// Вписывает реальные sha256 в манифесты Scoop и winget.
//
//   node packaging/update-manifests.js
//
// Хеш берётся из dist/cowboy-banner-<версия>-windows.zip. Смысл такой:
// сначала собираем артефакт, потом публикуем его в Releases, и только после
// этого манифесты получают настоящий хеш.
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const REPO = path.join(__dirname, "..");
const dist = path.join(REPO, "dist");
const version = process.argv[2] || "1.0.0";
const zipPath = path.join(dist, `cowboy-banner-${version}-windows.zip`);

if (!fs.existsSync(zipPath)) {
  console.error(`нет ${path.relative(REPO, zipPath)} - сначала: node packaging/build-zip.js`);
  process.exit(1);
}
const sha256 = crypto.createHash("sha256").update(fs.readFileSync(zipPath)).digest("hex");
const PLACEHOLDER = "ЗАМЕНИТЬ_НА_SHA256";

// В манифестах хеш может быть уже проставлен - тогда надо не искать
// заглушку, а заменить прежнее значение: иначе манифест молча расходится
// с собранным архивом.
const targets = [
  {
    path: path.join(REPO, "packaging", "scoop", "cowboy-banner.json"),
    replace: (text) => text.replace(/("hash"\s*:\s*")[^"]*(")/, `$1${sha256}$2`),
  },
  {
    path: path.join(REPO, "packaging", "winget", "manifests", "e", "egot51", "cowboy-banner", version, "egot51.cowboy-banner.installer.yaml"),
    replace: (text) => text.replace(/(InstallerSha256:\s*)\S+/, `$1${sha256}`),
  },
];

let changed = 0;
for (const t of targets) {
  const before = fs.readFileSync(t.path, "utf8");
  const after = t.replace(before);
  if (before !== after) {
    fs.writeFileSync(t.path, after, "utf8");
    changed++;
    console.log(`  обновлён ${path.relative(REPO, t.path)}`);
  } else {
    console.log(`  без изменений ${path.relative(REPO, t.path)}`);
  }
}
console.log(`  sha256: ${sha256}`);
if (!changed) console.log("  (хеш уже совпадал)");
