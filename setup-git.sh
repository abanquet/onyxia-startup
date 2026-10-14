git config --global credential.https://gitlab.algobank.oecd.org.helper '!f() { echo "username=$GIT_USER_NAME"; echo "password=$GIT_PERSONAL_ACCESS_TOKEN"; }; f'

# 2. Make sure uv is available
export PATH="$HOME/.local/bin:$PATH"
command -v uv >/dev/null 2>&1 || pip install --user uv

# 3. Create the default venv once (in the work directory so it survives restarts if persistence is on)
VENV="$HOME/work/.venv"
[ -d "$VENV" ] || uv venv "$VENV"

# 4. Install the packages
uv pip install --python "$VENV/bin/python" \
  "git+https://gitlab.algobank.oecd.org/geospatial-unit/utilities/oecd-utils.git" \
  "git+https://gitlab.algobank.oecd.org/OECDMAPS/oecd-maps-package.git" \
  "git+https://gitlab.algobank.oecd.org/municipal/municipal-data-utils.git" \
  "git+https://gitlab.algobank.oecd.org/Alexandre.BANQUET/oecd-plots.git" \
  ipykernel