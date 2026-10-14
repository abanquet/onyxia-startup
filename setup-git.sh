#!/bin/sh
# Onyxia init script: git credentials for the internal GitLab + default venv.
# Everything is logged to /tmp/setup-git.log (read it with: cat /tmp/setup-git.log).
# No secret in this file: the token is read from the Onyxia environment at run time.

LOG=/tmp/setup-git.log
exec >> "$LOG" 2>&1
echo "=== setup-git.sh started $(date) as $(whoami), HOME=$HOME ==="

# 1. Git credentials for the internal GitLab
git config --global credential.https://gitlab.algobank.oecd.org.helper '!f() { echo "username=$GIT_USER_NAME"; echo "password=$GIT_PERSONAL_ACCESS_TOKEN"; }; f'
echo "git credential helper configured"

if [ -n "$GIT_USER_NAME" ] && [ -n "$GIT_PERSONAL_ACCESS_TOKEN" ]; then
  echo "git variables: present"
else
  echo "WARNING: GIT_USER_NAME or GIT_PERSONAL_ACCESS_TOKEN is empty, installs will fail"
fi

# 2-4. Venv and packages, run in the background so the service start is not blocked
(
  export PATH="$HOME/.local/bin:$PATH"

  # Wait (up to 1 minute) for the work directory to be ready and writable
  i=0
  until [ -w "$HOME/work" ] || [ "$i" -ge 30 ]; do
    sleep 2
    i=$((i + 1))
  done
  if [ ! -w "$HOME/work" ]; then
    echo "ERROR: $HOME/work is not writable, aborting"
    exit 1
  fi

  # Make sure uv is available
  if ! command -v uv >/dev/null 2>&1; then
    pip install --user uv || python3 -m pip install --user --break-system-packages uv
  fi
  command -v uv >/dev/null 2>&1 || { echo "ERROR: uv not available, aborting"; exit 1; }

  # Create the default venv (recreated if a previous run left it broken)
  VENV="$HOME/work/.venv"
  [ -x "$VENV/bin/python" ] || uv venv "$VENV" || { echo "ERROR: venv creation failed"; exit 1; }

  # Install the packages
  uv pip install --python "$VENV/bin/python" \
    "git+https://gitlab.algobank.oecd.org/geospatial-unit/utilities/oecd-utils.git" \
    "git+https://gitlab.algobank.oecd.org/OECDMAPS/oecd-maps-package.git" \
    "git+https://gitlab.algobank.oecd.org/municipal/municipal-data-utils.git" \
    "git+https://gitlab.algobank.oecd.org/Alexandre.BANQUET/oecd-plots.git" \
    ipykernel \
    && echo "=== install finished OK $(date) ===" \
    || echo "ERROR: package install failed"
) &

# 5. Claude Code, in the background and independent of the venv.
#    Needs ANTHROPIC_API_KEY in the environment to be usable (set it in the Onyxia launcher).
(
  export PATH="$HOME/.local/bin:$PATH"

  if command -v claude >/dev/null 2>&1; then
    echo "Claude Code already installed: $(claude --version)"
  else
    echo "installing Claude Code (native installer)"
    if curl -fsSL https://claude.ai/install.sh -o /tmp/claude-install.sh && bash /tmp/claude-install.sh; then
      echo "=== Claude Code installed OK $(date) ==="
    else
      echo "native installer failed, trying npm"
      if npm install -g --prefix "$HOME/.local" @anthropic-ai/claude-code; then
        echo "=== Claude Code installed OK via npm $(date) ==="
      else
        echo "ERROR: Claude Code install failed"
      fi
    fi
  fi

  # Make sure terminals find ~/.local/bin
  grep -q '\.local/bin' "$HOME/.bashrc" 2>/dev/null \
    || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"

  if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "WARNING: ANTHROPIC_API_KEY is set, Claude Code will bill the API per token instead of your subscription"
  else
    echo "no ANTHROPIC_API_KEY: log in with your Claude account (run claude, then /login)"
  fi
) &

# 6. Claude Code VS Code extension (code-server installs from the Open VSX registry)
(
  if command -v code-server >/dev/null 2>&1; then
    if code-server --list-extensions 2>/dev/null | grep -qi '^anthropic.claude-code$'; then
      echo "Claude Code extension already installed"
    elif code-server --install-extension anthropic.claude-code; then
      echo "=== Claude Code extension installed OK $(date) ==="
    else
      echo "ERROR: Claude Code extension install failed"
    fi
  else
    echo "code-server not found, skipping the extension install"
  fi
) &

echo "main script done, venv, Claude Code and extension setup running in background"