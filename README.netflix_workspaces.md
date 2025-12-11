# Dotfiles

Any files in this repo will be symlinked directly into the user HOME directory for workspaces.
The install location will be relative to the git repo root, so if you create `./bin/my-script` in this repo then it will be installed to `$HOME/bin/my-script`.

## Installers

Sometimes you might want to install tooling that you find useful which may not be included in the workspace by default.
The dotfiles installer will automatically run any scripts in the `./installers` directory, they are expected to be written in bash and will be sourced into the primary install script.

For example I prefer to use the `diff-highlight` tool for `git diff` operations.
To have this tool automatically installed in my workspaces I have created `./installers/highlight.sh` like:

```bash
# ensure pip is installed
if ! command -v "pip" >/dev/null; then
    sudo apt update
    sudo apt install -y python3-pip
fi
# ensure diff-highlight is installed
if ! command -v "diff-highlight" >/dev/null; then
    sudo pip install diff-highlight
fi
```