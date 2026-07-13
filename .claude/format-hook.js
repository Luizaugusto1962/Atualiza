#!/usr/bin/env node
// PostToolUse hook (Write|Edit) — formata o arquivo recém-escrito.
// - .sh/.bash/.bats -> shfmt (indent 2, casos indentados preservados)
// - .md/.json/.jsonc -> prettier (bin local em node_modules/.bin)
// Lê o payload JSON do hook no stdin, extrai file_path e despacha.
// Robusto: falhas de formatação nunca quebram o turno do Claude.
// Silencioso por padrão (stderr só para diagnostico).

const fs = require("fs");
const { execSync } = require("child_process");
const path = require("path");

// shfmt instalado via winget (per-user). Path absoluto p/ independência de PATH.
const SHFMT_BIN =
  "C:/Users/Luiz Augusto/AppData/Local/Microsoft/WinGet/Packages/" +
  "mvdan.shfmt_Microsoft.Winget.Source_8wekyb3d8bbwe/shfmt.exe";

// raiz do projeto = diretorio que CONTEM este .claude/.
// Usa __dirname do script (robusto: independe de cwd/argv).
const PROJECT_DIR = path.resolve(__dirname, "..");
const PRETTIER_BIN = path.join(PROJECT_DIR, "node_modules", ".bin", "prettier");

// Converte caminho POSIX do Git Bash ("/c/Users/...") para Windows ("C:\Users\...")
// quando o node é Windows. Necessario pq path.resolve() no Windows trata "/c/x"
// como relativo ao drive atual.
function normalizePath(p) {
  if (process.platform === "win32") {
    const m = /^\/([a-zA-Z])\/(.*$)/.exec(p);
    if (m) return m[1] + ":/" + m[2];
  }
  return p;
}

const log = (m) => process.stderr.write("fmt-hook> " + m + "\n");

function main(payload) {
  let file =
    (payload.tool_input && (payload.tool_input.file_path || payload.tool_input.filePath)) ||
    (payload.tool_response && payload.tool_response.filePath);
  if (!file || typeof file !== "string") return;

  let abs;
  try {
    abs = path.resolve(normalizePath(file));
  } catch {
    return;
  }
  // só formatamos dentro do projeto (evita formatar node_modules, etc.)
  if (!abs.startsWith(PROJECT_DIR)) return;

  const ext = path.extname(abs).slice(1).toLowerCase();
  const isShell = ["sh", "bash", "bats"].includes(ext);
  const isPrettier = ["md", "json", "jsonc"].includes(ext);
  if (!isShell && !isPrettier) return;

  try {
    if (isShell) {
      // -i 2  = indentar com 2 espaços
      // -w    = escrever in-place
      // -ci   = preservar indentaçes de caso/esac
      // -ln   = linguagem explicita (.bats é tratado como bash)
      const ln = ext === "bats" ? "-ln bats" : ext === "bash" ? "-ln bash" : "-ln bash";
      execSync(`"${SHFMT_BIN}" -i 2 -ci -w ${ln} "${abs}"`, { cwd: PROJECT_DIR });
      log(`shfmt ${abs}`);
    } else {
      // prettier resolve .prettierrc a partir do PROJECT_DIR
      execSync(`"${PRETTIER_BIN}" --write "${abs}"`, { cwd: PROJECT_DIR });
      log(`prettier ${abs}`);
    }
  } catch (e) {
    log(`erro formatando ${abs}: ${(e.stderr || e.message || "").toString().split("\n")[0]}`);
  }
}

let raw = "";
process.stdin.on("data", (c) => (raw += c));
process.stdin.on("end", () => {
  try {
    main(JSON.parse(raw));
  } catch {
    // payload invalido -> nao fazer nada
  }
});
