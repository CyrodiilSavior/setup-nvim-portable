#!/usr/bin/env bash
# Portable Neovim bootstrap: macOS and common Linux distributions.
# Installs this NvChad-based setup, Tree-sitter folding parsers, and (when
# VS Code is available) the C# extension used as Neovim's Roslyn server.
set -euo pipefail

readonly STARTER_REPO='https://github.com/NvChad/starter.git'
readonly STARTER_REV='e3572e1'
readonly BACKUP_TAG="$(date +%Y%m%d-%H%M%S)"

say() { printf '\n==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

install_dependencies() {
  local packages
  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null || die 'Install Homebrew first: https://brew.sh'
      brew install neovim git curl gcc make
      ;;
    Linux)
      if command -v dnf >/dev/null; then
        packages=(neovim git curl tar gcc make)
        sudo dnf install -y "${packages[@]}"
      elif command -v apt-get >/dev/null; then
        packages=(neovim git curl tar build-essential)
        sudo apt-get update && sudo apt-get install -y "${packages[@]}"
      elif command -v pacman >/dev/null; then
        packages=(neovim git curl tar base-devel)
        sudo pacman -S --needed "${packages[@]}"
      else
        die 'Unsupported Linux package manager. Install nvim (>=0.11), git, curl, tar, make, and a C compiler, then rerun.'
      fi
      ;;
    *) die "Unsupported operating system: $(uname -s)" ;;
  esac
}

for command in nvim git curl tar cc make base64; do
  if ! command -v "$command" >/dev/null 2>&1; then
    say "Installing prerequisites"
    install_dependencies
    break
  fi
done

command -v nvim >/dev/null || die 'Neovim was not installed.'
NVIM_VERSION="$(nvim --version | sed -n '1s/^NVIM v//p')"
NVIM_MAJOR="${NVIM_VERSION%%.*}"
NVIM_MINOR_REST="${NVIM_VERSION#*.}"
NVIM_MINOR="${NVIM_MINOR_REST%%.*}"
(( NVIM_MAJOR > 0 || NVIM_MINOR >= 11 )) || die "Neovim 0.11 or newer is required (found ${NVIM_VERSION})."

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CONFIG_DIR="$CONFIG_HOME/nvim"
DATA_DIR="$(nvim --clean --headless '+lua io.write(vim.fn.stdpath("data"))' '+qa!')"
BACKUP_DIR="$HOME/.nvim-portable-backup-$BACKUP_TAG"

if [[ -e "$CONFIG_DIR" ]]; then
  say "Backing up existing configuration to $BACKUP_DIR"
  mkdir -p "$BACKUP_DIR"
  mv "$CONFIG_DIR" "$BACKUP_DIR/config"
fi

if [[ -d "$DATA_DIR/lazy" ]]; then
  mkdir -p "$BACKUP_DIR"
  mv "$DATA_DIR/lazy" "$BACKUP_DIR/lazy"
fi

say 'Installing the NvChad starter base'
mkdir -p "$CONFIG_HOME"
git clone --quiet "$STARTER_REPO" "$CONFIG_DIR"
git -C "$CONFIG_DIR" checkout --quiet "$STARTER_REV"
rm -rf "$CONFIG_DIR/.git"

say 'Applying the portable configuration overlay'
payload_file="$(mktemp)"
work_dir=""
trap 'rm -f "$payload_file"; [[ -z "${work_dir:-}" ]] || rm -rf "$work_dir"' EXIT
base64_payload() {
  cat <<'NVIM_CONFIG_PAYLOAD'
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

NVIM_CONFIG_PAYLOAD
}
base64_payload >"$payload_file"
if [[ "$(uname -s)" == Darwin ]]; then
  base64 -D <"$payload_file" | tar -xzf - -C "$CONFIG_DIR"
else
  base64 --decode <"$payload_file" | tar -xzf - -C "$CONFIG_DIR"
fi

say 'Installing Neovim plugins'
nvim --headless '+Lazy! sync' '+qa!' || warn 'Lazy sync reported an error; reopen Neovim and run :Lazy sync once.'

work_dir="$(mktemp -d)"
mkdir -p "$DATA_DIR/site/parser"
clone_at() {
  local repo="$1" revision="$2" destination="$3"
  git clone --quiet "$repo" "$destination"
  git -C "$destination" checkout --quiet "$revision"
}

say 'Building Tree-sitter parsers for C#, Go, TypeScript, and TSX'
clone_at https://github.com/tree-sitter/tree-sitter-c-sharp 88366631d598ce6595ec655ce1591b315cffb14c "$work_dir/csharp"
cc -fPIC -shared -I"$work_dir/csharp/src" -o "$DATA_DIR/site/parser/c_sharp.so" "$work_dir/csharp/src/parser.c" "$work_dir/csharp/src/scanner.c"
clone_at https://github.com/tree-sitter/tree-sitter-go 2346a3ab1bb3857b48b29d779a1ef9799a248cd7 "$work_dir/go"
cc -fPIC -shared -I"$work_dir/go/src" -o "$DATA_DIR/site/parser/go.so" "$work_dir/go/src/parser.c"
clone_at https://github.com/tree-sitter/tree-sitter-typescript 75b3874edb2dc714fb1fd77a32013d0f8699989f "$work_dir/typescript"
cc -fPIC -shared -I"$work_dir/typescript/typescript/src" -o "$DATA_DIR/site/parser/typescript.so" "$work_dir/typescript/typescript/src/parser.c" "$work_dir/typescript/typescript/src/scanner.c"
cc -fPIC -shared -I"$work_dir/typescript/tsx/src" -o "$DATA_DIR/site/parser/tsx.so" "$work_dir/typescript/tsx/src/parser.c" "$work_dir/typescript/tsx/src/scanner.c"

if command -v code >/dev/null 2>&1; then
  say 'Installing the VS Code C# extension for Roslyn IntelliSense'
  code --install-extension ms-dotnettools.csharp --force || warn 'Could not install the C# extension; install ms-dotnettools.csharp in VS Code later.'
else
  warn 'VS Code CLI was not found. Install ms-dotnettools.csharp later to enable C# Roslyn IntelliSense.'
fi

say 'Complete. Start Neovim normally.'
printf 'Existing files, if any, were backed up under: %s\n' "$BACKUP_DIR"
