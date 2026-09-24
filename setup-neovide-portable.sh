#!/usr/bin/env bash
# Installs this Neovide/NvChad setup on macOS (.app) or Linux Flatpak Neovide.
set -euo pipefail

say() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
warn() { printf 'warning: %s\n' "$*" >&2; }

install_prerequisites() {
  case "$(uname -s)" in
    Darwin)
      command -v brew >/dev/null || die 'Install Homebrew first: https://brew.sh'
      brew install neovim git curl gcc
      ;;
    Linux)
      if command -v dnf >/dev/null; then
        sudo dnf install -y neovim git curl tar gcc make
      elif command -v apt-get >/dev/null; then
        sudo apt-get update && sudo apt-get install -y neovim git curl tar build-essential
      elif command -v pacman >/dev/null; then
        sudo pacman -S --needed neovim git curl tar base-devel
      else
        die 'Install Neovim 0.11+, git, curl, tar, make, and a C compiler, then rerun.'
      fi
      ;;
    *) die "Unsupported operating system: $(uname -s)" ;;
  esac
}

for command in nvim git curl tar cc make base64; do
  if ! command -v "$command" >/dev/null 2>&1; then
    say 'Installing prerequisites'
    install_prerequisites
    break
  fi
done

command -v nvim >/dev/null || die 'Neovim is required.'
version="$(nvim --version | sed -n '1s/^NVIM v//p')"
major="${version%%.*}"; remainder="${version#*.}"; minor="${remainder%%.*}"
(( major > 0 || minor >= 11 )) || die "Neovim 0.11+ is required (found $version)."

app_id='dev.neovide.neovide'
if [[ "$(uname -s)" == Linux ]] && flatpak info "$app_id" >/dev/null 2>&1; then
  config_home="$HOME/.var/app/$app_id/config"
  data_home="$HOME/.var/app/$app_id/data"
  target='Neovide Flatpak'
else
  config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
  target='Neovide .app / native Neovim'
fi

config_dir="$config_home/nvim"
data_dir="$data_home/nvim"
stamp="$(date +%Y%m%d-%H%M%S)"
backup="$HOME/.neovide-config-backup-$stamp"

if [[ -e "$config_dir" ]]; then
  say "Backing up existing $target configuration"
  mkdir -p "$backup"
  mv "$config_dir" "$backup/nvim-config"
fi
if [[ -d "$data_dir/lazy" ]]; then
  mkdir -p "$backup"
  mv "$data_dir/lazy" "$backup/lazy"
fi

say "Installing configuration for $target"
mkdir -p "$config_home" "$data_dir"
payload="$(mktemp)"
workdir=""
trap 'rm -f "$payload"; [[ -z "${workdir:-}" ]] || rm -rf "$workdir"' EXIT
config_payload() {
  cat <<'NEOVIDE_CONFIG_PAYLOAD'
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

NEOVIDE_CONFIG_PAYLOAD
}
config_payload >"$payload"
if [[ "$(uname -s)" == Darwin ]]; then
  base64 -D <"$payload" | tar -xzf - -C "$config_home"
else
  base64 --decode <"$payload" | tar -xzf - -C "$config_home"
fi

say 'Installing pinned Neovim plugins'
XDG_CONFIG_HOME="$config_home" XDG_DATA_HOME="$data_home" nvim --headless '+Lazy! sync' '+qa!' || warn 'Run :Lazy sync once in Neovide if plugin installation was interrupted.'

workdir="$(mktemp -d)"
mkdir -p "$data_dir/site/parser"
clone_at() {
  git clone --quiet "$1" "$3"
  git -C "$3" checkout --quiet "$2"
}

say 'Building C#, Go, TypeScript, and TSX folding parsers'
clone_at https://github.com/tree-sitter/tree-sitter-c-sharp 88366631d598ce6595ec655ce1591b315cffb14c "$workdir/csharp"
cc -fPIC -shared -I"$workdir/csharp/src" -o "$data_dir/site/parser/c_sharp.so" "$workdir/csharp/src/parser.c" "$workdir/csharp/src/scanner.c"
clone_at https://github.com/tree-sitter/tree-sitter-go 2346a3ab1bb3857b48b29d779a1ef9799a248cd7 "$workdir/go"
cc -fPIC -shared -I"$workdir/go/src" -o "$data_dir/site/parser/go.so" "$workdir/go/src/parser.c"
clone_at https://github.com/tree-sitter/tree-sitter-typescript 75b3874edb2dc714fb1fd77a32013d0f8699989f "$workdir/typescript"
cc -fPIC -shared -I"$workdir/typescript/typescript/src" -o "$data_dir/site/parser/typescript.so" "$workdir/typescript/typescript/src/parser.c" "$workdir/typescript/typescript/src/scanner.c"
cc -fPIC -shared -I"$workdir/typescript/tsx/src" -o "$data_dir/site/parser/tsx.so" "$workdir/typescript/tsx/src/parser.c" "$workdir/typescript/tsx/src/scanner.c"

font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
[[ "$(uname -s)" == Darwin ]] && font_dir="$HOME/Library/Fonts/JetBrainsMonoNerdFont"
say 'Installing JetBrainsMono Nerd Font for Neovide icons'
mkdir -p "$font_dir"
curl -fL --retry 2 https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz -o "$workdir/JetBrainsMono.tar.xz"
tar -xJf "$workdir/JetBrainsMono.tar.xz" -C "$font_dir" --wildcards '*.ttf'
command -v fc-cache >/dev/null && fc-cache -f "$font_dir" || true

if command -v code >/dev/null 2>&1; then
  say 'Installing the VS Code C# extension used for Roslyn IntelliSense'
  code --install-extension ms-dotnettools.csharp --force || warn 'Install ms-dotnettools.csharp in VS Code later for C# IntelliSense.'
fi

XDG_CONFIG_HOME="$config_home" XDG_DATA_HOME="$data_home" nvim --headless '+lua require("base46").load_all_highlights()' '+qa!' || true
say 'Complete. Fully restart Neovide.'
[[ -d "$backup" ]] && printf 'Previous setup: %s\n' "$backup"
