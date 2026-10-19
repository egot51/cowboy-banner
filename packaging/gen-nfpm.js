// Собирает nfpm.yaml из канонических данных: debian/control (метаданные)
// и дерева файлов linux/files (содержимое пакета). Так rpm и deb собираются
// из одного описания, а не каждый из своего.
//
//   node packaging/gen-nfpm.js [--maintainer "Имя <email>"]
const fs = require("fs");
const path = require("path");

const REPO = path.join(__dirname, "..");
const args = process.argv.slice(2);
const opt = (name, def) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? args[i + 1] : def;
};

const control = fs.readFileSync(path.join(__dirname, "debian", "control"), "utf8");
const field = (name) => {
  const m = new RegExp(`^${name}:\\s*(.*)$`, "m").exec(control);
  return m ? m[1].trim() : "";
};
const description = (() => {
  // Description в control - многострочное поле с отступом.
  const m = /^Description:\s*([\s\S]*?)(?=\n\S|\n*$)/m.exec(control);
  return m ? m[1].replace(/\n[ \t]+/g, "\n").trim() : "";
})();

const name = field("Package");
const version = field("Version");
const maintainer = opt("--maintainer", field("Maintainer"));
const homepage = field("Homepage");
const license = field("License") || "MIT";
const section = field("Section") || "misc";
const priority = field("Priority") || "optional";
const depends = field("Depends");
const recommends = field("Recommends");

const payload = path.join(REPO, "linux", "files");
if (!fs.existsSync(payload)) {
  console.error("нет дерева linux/files - сначала: node tools/gen-linux.js");
  process.exit(1);
}

const yaml = `# Сгенерировано: node packaging/gen-nfpm.js
# Правьте debian/control и перегенерируйте - руками не правим.
name: ${name}
arch: all
platform: linux
version: ${version}
release: 1
section: ${section}
priority: ${priority}
maintainer: ${maintainer}
vendor: egot51
homepage: ${homepage}
license: ${license}
depends:
${depends.split(",").map((d) => `  - ${d.trim()}`).join("\n")}
recommends:
${recommends ? recommends.split(",").map((d) => `  - ${d.trim()}`).join("\n") : "  []"}
description: |
${description
  .split("\n")
  .map((l) => `  ${l}`)
  .join("\n")}

contents:
  # Скрипт баннера и его данные.
  - src: ${path.join(payload, "usr/bin/cowboy-banner").replace(/\\/g, "/")}
    dst: /usr/bin/cowboy-banner
    file_info:
      mode: 0755
  - src: ${path.join(payload, "usr/share/cowboy-banner").replace(/\\/g, "/")}
    dst: /usr/share/cowboy-banner
    file_info:
      mode: 0644
  # Общие хуки установки и удаления - их зовут и postinstall, и preremove.
  - src: ${path.join(payload, "usr/lib/cowboy-banner").replace(/\\/g, "/")}
    dst: /usr/lib/cowboy-banner
    file_info:
      mode: 0755
  # Справка и лицензия.
  - src: ${path.join(payload, "usr/share/man").replace(/\\/g, "/")}
    dst: /usr/share/man
    file_info:
      mode: 0644
  - src: ${path.join(payload, "usr/share/doc").replace(/\\/g, "/")}
    dst: /usr/share/doc
    file_info:
      mode: 0644
  - src: ${path.join(payload, "usr/share/licenses").replace(/\\/g, "/")}
    dst: /usr/share/licenses
    file_info:
      mode: 0644
  # Профиль для новых пользователей PowerShell.
  - src: ${path.join(payload, "etc/skel").replace(/\\/g, "/")}
    dst: /etc/skel
    file_info:
      mode: 0644

scripts:
  # nfpm вставляет в скриптлет СОДЕРЖИМОЕ файла, поэтому тут указываем
  # локальные пути, а не те, что окажутся в пакете.
  postinstall: ./src/hooks/install.sh
  preremove: ./src/hooks/remove.sh

rpm:
  group: Applications/System
  compression: xz

deb:
  compression: xz
`;

const out = path.join(__dirname, "nfpm.yaml");
fs.writeFileSync(out, yaml, "utf8");
console.log(`  ${path.relative(REPO, out)} - имя ${name}, версия ${version}, maintainer: ${maintainer}`);
