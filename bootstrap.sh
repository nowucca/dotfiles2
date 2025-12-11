#!/usr/bin/env zsh

cd "$(dirname "${(%):-%x}")";

function ensureGitRepo() {
  repo_url=$1
  repo_folder=$2
  [ -r ~/init/$repo_folder ] || (mkdir -p ~/init/$repo_folder && cd ~/init/ && git clone $repo_url)
  (cd ~/init/$repo_folder && git pull -q)
}

function doIt() {
	rsync --exclude ".git/" \
		--exclude ".DS_Store" \
		--exclude ".osx" \
		--exclude "bootstrap.sh" \
		--exclude "README.md" \
		--exclude "LICENSE-MIT.txt" \
		-avhq --no-perms . ~;
        ensureGitRepo https://github.com/altercation/solarized.git solarized
        ensureGitRepo https://github.com/rupa/z.git z
	source ~/.zshrc;
}
if [[ "$1" == "--force" || "$1" == "-f" ]]; then
	doIt;
else
	read -r "REPLY?This may overwrite existing files in your home directory. Are you sure? (y/n) ";
	echo "";
	if [[ $REPLY =~ ^[Yy]$ ]]; then
		doIt;
	fi;
fi;
unset doIt;
