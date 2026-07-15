#!/usr/bin/env bash
#
# bootstrap.sh — new-engineer machine setup for the team (macOS / Apple Silicon).
#
# Goals: safe, repeatable, low-effort. Idempotent and resumable — if it fails
# partway, just re-run it. No manual cleanup, no duplicate config, no double-installs.
#
# Two-stage onboarding (see SETUP.md):
#   Stage 1 (prereqs, done BEFORE this script — it's how you cloned the repo holding it):
#     install Homebrew, then `brew install git gh`, then `gh auth login`.
#   Stage 2 (this script): everything else — mise + runtimes, Colima + docker, etc.
#
# This script re-checks the Stage 1 prereqs too, so it's safe regardless of order.
#
# Usage:
#   ./bootstrap.sh              # team baseline only (for junior engineers)
#   ./bootstrap.sh --personal   # also install Dustin's personal tools (rg, zoxide, neovim)
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
NODE_VERSION="22"          # >=22.12 required by impeccable; mise resolves latest 22.x
INSTALL_PERSONAL="false"
[[ "${1:-}" == "--personal" ]] && INSTALL_PERSONAL="true"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; RESET=$'\033[0m'
else
  BOLD=""; GREEN=""; YELLOW=""; RED=""; DIM=""; RESET=""
fi
info()  { printf "%s==>%s %s\n" "$BOLD" "$RESET" "$*"; }
ok()    { printf "%s  ok%s  %s\n" "$GREEN" "$RESET" "$*"; }
skip()  { printf "%sskip%s  %s\n" "$DIM" "$RESET" "$*"; }
warn()  { printf "%swarn%s  %s\n" "$YELLOW" "$RESET" "$*"; }
err()   { printf "%s fail%s %s\n" "$RED" "$RESET" "$*" >&2; }

have()  { command -v "$1" >/dev/null 2>&1; }
is_tty() { [[ -t 0 ]]; }

# ---------------------------------------------------------------------------
# Homebrew (privileged/interactive — cannot run unattended)
# ---------------------------------------------------------------------------
ensure_homebrew() {
  info "Homebrew"
  local brew_bin=""
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$p" ]] && brew_bin="$p" && break
  done
  if [[ -z "$brew_bin" ]]; then
    err "Homebrew is not installed. It needs your macOS password (sudo) + a RETURN keypress,"
    err "so it can't be automated here. Run this yourself, then re-run bootstrap.sh:"
    printf '\n    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"\n\n'
    exit 1
  fi
  eval "$("$brew_bin" shellenv)"
  BREW_PREFIX="$(brew --prefix)"
  ok "Homebrew present ($brew_bin)"
}

# brew_install <formula...> — install only what's missing (idempotent, fast)
brew_install() {
  local f
  for f in "$@"; do
    if brew list --formula "$f" >/dev/null 2>&1; then
      skip "$f already installed"
    else
      info "installing $f"
      brew install "$f"
      ok "$f installed"
    fi
  done
}

# ---------------------------------------------------------------------------
# Shell config — append a line to ~/.zshrc only if not already present
# ---------------------------------------------------------------------------
ZSHRC="$HOME/.zshrc"
add_zshrc_line() {
  local line="$1" comment="${2:-}"
  touch "$ZSHRC"
  if grep -qF -- "$line" "$ZSHRC"; then
    skip "~/.zshrc already has: $line"
  else
    { [[ -n "$comment" ]] && printf '\n# %s\n' "$comment"; printf '%s\n' "$line"; } >> "$ZSHRC"
    ok "added to ~/.zshrc: $line"
  fi
}

# ---------------------------------------------------------------------------
# Steps
# ---------------------------------------------------------------------------
setup_baseline_tools() {
  info "Team baseline tools (git, gh, mise)"
  brew_install git gh mise
}

setup_personal_tools() {
  if [[ "$INSTALL_PERSONAL" != "true" ]]; then
    skip "personal tools (rg/zoxide/neovim) — run with --personal to include"
    return
  fi
  info "Personal tools (ripgrep, zoxide, neovim)"
  brew_install ripgrep zoxide neovim
}

setup_shell() {
  info "Shell config (~/.zshrc)"
  add_zshrc_line 'eval "$(mise activate zsh)"' "mise — runtime/version manager"
  if have zoxide; then
    add_zshrc_line 'eval "$(zoxide init zsh)"' "zoxide — smarter cd (z)"
  fi
}

setup_runtimes() {
  info "Runtimes via mise (node@${NODE_VERSION}, pnpm)"
  # Use mise shims so node/pnpm are reachable in this non-interactive script.
  export PATH="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$PATH"
  mise use -g "node@${NODE_VERSION}"   # idempotent; no-op if already at latest 22.x
  mise use -g pnpm@latest
  hash -r 2>/dev/null || true
  ok "node $(mise exec -- node --version 2>/dev/null || echo '?'), pnpm $(mise exec -- pnpm --version 2>/dev/null || echo '?')"
}

setup_container_runtime() {
  info "Container runtime (Colima + docker + compose)"
  brew_install colima docker docker-compose

  # Wire the compose plugin so `docker compose` resolves. Don't clobber an existing config.
  local dcfg="$HOME/.docker/config.json"
  local plugin_dir="$BREW_PREFIX/lib/docker/cli-plugins"
  mkdir -p "$HOME/.docker"
  if [[ ! -f "$dcfg" ]]; then
    printf '{\n  "cliPluginsExtraDirs": [\n    "%s"\n  ]\n}\n' "$plugin_dir" > "$dcfg"
    ok "created ~/.docker/config.json with compose plugin path"
  elif grep -qF "$plugin_dir" "$dcfg"; then
    skip "~/.docker/config.json already references the compose plugin"
  else
    warn "~/.docker/config.json exists but lacks the compose plugin dir."
    warn "Add this to its \"cliPluginsExtraDirs\" array: $plugin_dir"
  fi

  # Start Colima if not already running.
  if colima status >/dev/null 2>&1; then
    skip "Colima already running"
  else
    info "starting Colima (first run provisions a small Linux VM)"
    colima start
    ok "Colima started"
  fi
}

ensure_gh_auth() {
  info "GitHub authentication"
  if ! have gh; then
    warn "gh not installed yet — baseline step should have handled this."
    return
  fi
  if gh auth status >/dev/null 2>&1; then
    ok "already authenticated with GitHub"
  elif is_tty; then
    warn "not authenticated — launching interactive login"
    gh auth login
  else
    warn "not authenticated and no terminal available. Run this yourself:"
    warn "    gh auth login"
    warn "(required to clone private repos)"
  fi
}

# ---------------------------------------------------------------------------
# Integration test — prove the whole stack is wired, not just that binaries exist.
# ---------------------------------------------------------------------------
integration_test() {
  info "Integration test (verifying the full stack)"
  local failures=0
  export PATH="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$PATH"

  check() { # check <label> <command...>
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$label"; else err "$label"; failures=$((failures+1)); fi
  }

  check "docker daemon reachable (hello-world)" docker run --rm hello-world
  check "docker compose plugin resolves"        docker compose version
  check "node on PATH (mise)"                   node --version
  check "pnpm on PATH (mise)"                   pnpm --version
  check "git available"                         git --version
  check "GitHub authenticated"                  gh auth status

  echo
  if [[ "$failures" -eq 0 ]]; then
    printf "%s✓ All checks passed — machine is ready.%s\n" "$GREEN$BOLD" "$RESET"
  else
    printf "%s✗ %d check(s) failed — see above. Fix and re-run bootstrap.sh.%s\n" "$RED$BOLD" "$failures" "$RESET"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  printf "%sTeam machine bootstrap%s  (personal tools: %s)\n\n" "$BOLD" "$RESET" "$INSTALL_PERSONAL"
  ensure_homebrew
  setup_baseline_tools
  setup_personal_tools
  setup_shell
  setup_runtimes
  setup_container_runtime
  ensure_gh_auth
  echo
  integration_test
}

main "$@"
