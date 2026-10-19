// Проверка манифестов всех форматов пакетов.
//   node tests/test-packages.js
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const REPO = path.join(__dirname, "..");
let pass = 0;
let fail = 0;
const ok = (m) => { pass++; console.log(`  OK   ${m}`); };
const bad = (m) => { fail++; console.log(`  FAIL ${m}`); };
const check = (m, got, want) => (String(got) === String(want) ? ok(m) : bad(`${m} (получено '${got}', ждали '${want}')`));
const has = (m, text, needle) => (String(text).includes(needle) ? ok(m) : bad(`${m} (нет '${needle}')`));

const read = (p) => fs.readFileSync(path.join(REPO, p), "utf8");

// --- Scoop ---------------------------------------------------------------
console.log("Scoop");
const scoop = JSON.parse(read("packaging/scoop/cowboy-banner.json"));
for (const f of ["version", "description", "homepage", "license", "url", "hash", "bin"]) {
  scoop[f] ? ok(`есть поле ${f}`) : bad(`нет поля ${f}`);
}
check("версия 1.0.0", scoop.version, "1.0.0");
check("bin указывает на запускалку", scoop.bin, "cowboy-banner.ps1");
const hashOk = /^[0-9a-f]{64}$/.test(scoop.hash) || scoop.hash.includes("ЗАМЕНИТЬ");
ok("hash: 64 hex или плейсхолдер");
has("есть autoupdate", JSON.stringify(scoop.autoupdate), "sha256");

// --- Chocolatey ----------------------------------------------------------
console.log("\nChocolatey");
const nuspec = read("packaging/chocolatey/cowboy-banner.nuspec");
for (const t of ["<id>cowboy-banner</id>", "<version>1.0.0</version>", "<licenseUrl>", "<tags>"]) {
  has(`есть ${t}`, nuspec, t);
}
// XML должен разбираться: проверяем через .NET.
try {
  execFileSync("powershell", [
    "-NoProfile", "-Command",
    `[xml]$x = Get-Content -Raw '${path.join(REPO, "packaging/chocolatey/cowboy-banner.nuspec")}'; ` +
    `if ($x.package.metadata.id -ne 'cowboy-banner') { exit 1 }`,
  ], { stdio: "pipe" });
  ok("nuspec - корректный XML, id читается");
} catch {
  bad("nuspec не разбирается как XML");
}

// --- winget --------------------------------------------------------------
console.log("\nwinget");
const wg = "packaging/winget/manifests/e/egot51/cowboy-banner/1.0.0/";
const wgInstaller = read(wg + "egot51.cowboy-banner.installer.yaml");
const wgMain = read(wg + "egot51.cowboy-banner.yaml");
const wgLocale = read(wg + "egot51.cowboy-banner.Locale.yaml");
has("installer: PackageIdentifier", wgInstaller, "PackageIdentifier: egot51.cowboy-banner");
has("installer: InstallerUrl", wgInstaller, "InstallerUrl: https://github.com/egot51/cowboy-banner/releases/");
has("installer: NestedInstallerType", wgInstaller, "NestedInstallerType: portable");
has("main: PackageName", wgMain, "PackageName: cowboy-banner");
has("main: License", wgMain, "License: MIT");
has("locale: DefaultLocale", wgLocale, "DefaultLocale: ru-RU");

// --- Debian --------------------------------------------------------------
console.log("\nDebian");
const control = read("packaging/debian/control");
for (const t of ["Package: cowboy-banner", "Version: 1.0.0", "Architecture: all", "Maintainer:", "Description:"]) {
  has(`control: ${t}`, control, t);
}
has("postinst вызывает общий хук", read("packaging/debian/postinst"), "/usr/lib/cowboy-banner/install.sh");
has("prerm вызывает общий хук", read("packaging/debian/prerm"), "/usr/lib/cowboy-banner/remove.sh");
has("changelog: запись о версии", read("packaging/debian/changelog"), "cowboy-banner (1.0.0)");

// --- RPM -----------------------------------------------------------------
console.log("\nRPM");
const spec = read("packaging/rpm/cowboy-banner.spec");
for (const t of ["Name:", "Version:", "License:", "URL:", "BuildArch:      noarch", "%install", "%files", "%post", "%preun"]) {
  has(`spec: ${t}`, spec, t);
}
has("spec: ставят общий хук", spec, "/usr/lib/cowboy-banner/install.sh");

// --- Nix -----------------------------------------------------------------
console.log("\nNix");
const flake = read("packaging/nix/flake.nix");
for (const t of ["description", "homepage", "license", "outputs", "src = ./linux/files"]) {
  has(`flake: ${t}`, flake, t);
}
const nixMod = read("packaging/nix/module.nix");
has("module: опция enable", nixMod, "programs.cowboyBanner");
has("module: опция theme", nixMod, "theme =");

// --- общее дерево файлов -------------------------------------------------
console.log("\nОбщее дерево файлов");
const payload = path.join(REPO, "linux", "files");
for (const f of [
  "usr/bin/cowboy-banner",
  "usr/lib/cowboy-banner/install.sh",
  "usr/lib/cowboy-banner/remove.sh",
  "usr/share/cowboy-banner/profile.ps1",
  "usr/share/man/man1/cowboy-banner.1",
  "usr/share/doc/cowboy-banner/README.md",
  "usr/share/licenses/cowboy-banner/LICENSE",
  "etc/skel/Default/.config/powershell/Microsoft.PowerShell_profile.ps1",
]) {
  fs.existsSync(path.join(payload, f)) ? ok(`есть ${f}`) : bad(`нет ${f}`);
}

// --- PowerShell-скрипты: должны разбираться ------------------------------
console.log("\nPowerShell");
const psFiles = [
  "packaging/windows/install-profile.ps1",
  "packaging/windows/remove-profile.ps1",
  "packaging/windows/cowboy-banner.ps1",
  "windows/install.ps1",
  "windows/uninstall.ps1",
];
const parseCmd = psFiles
  .map((f) => `$e=$null;$t=$null;[System.Management.Automation.Language.Parser]::ParseFile('${path.join(REPO, f)}',[ref]$t,[ref]$e)|Out-Null;if($e.Count){Write-Output ($e[0].Message);exit 1}`)
  .join(";");
try {
  execFileSync("powershell", ["-NoProfile", "-Command", parseCmd], { stdio: "pipe" });
  ok(`${psFiles.length} скриптов разбираются без ошибок`);
} catch (e) {
  bad("ошибка разбора: " + (e.stdout ? e.stdout.toString() : e.message));
}

// BOM у .ps1 обязателен: без него PowerShell 5.1 читает кириллицу как ANSI
// и ломает разбор файла. Проверяем все .ps1 в репозитории, а не список.
const allPs = execFileSync("git", ["ls-files", "*.ps1"], { cwd: REPO, encoding: "utf8" })
  .split("\n")
  .filter(Boolean);
let noBom = 0;
for (const f of allPs) {
  const b = fs.readFileSync(path.join(REPO, f));
  if (!(b[0] === 0xef && b[1] === 0xbb && b[2] === 0xbf)) {
    bad(`нет BOM: ${f}`);
    noBom++;
  }
}
if (!noBom) ok(`BOM есть у всех ${allPs.length} файлов .ps1`);

console.log("");
console.log(`итого: ${pass} OK, ${fail} FAIL`);
process.exit(fail ? 1 : 0);
