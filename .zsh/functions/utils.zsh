#!/usr/bin/env zsh
#
# Utility functions
#

# Create a new directory and enter it
function mkd() {
    mkdir -p "$@" && cd "$_"
}

# Change working directory to the top-most Finder window location
function cdf() {
    cd "$(osascript -e 'tell app "Finder" to POSIX path of (insertion location as alias)')"
}

# Determine size of a file or total size of a directory
function fs() {
    if du -b /dev/null > /dev/null 2>&1; then
        local arg=-sbh
    else
        local arg=-sh
    fi
    if [[ -n "$@" ]]; then
        du $arg -- "$@"
    else
        du $arg .[^.]* ./*
    fi
}

# Disk usage to N levels (default 2)
function diskusage() {
    local depth="${1:-2}"
    du -kd $depth | sort -nr
}

# Create a .tar.gz archive, using best available compression
function targz() {
    local tmpFile="${@%/}.tar"
    tar -cvf "${tmpFile}" --exclude=".DS_Store" "${@}" || return 1

    size=$(stat -f"%z" "${tmpFile}" 2> /dev/null || stat -c"%s" "${tmpFile}" 2> /dev/null)

    local cmd=""
    if (( size < 52428800 )) && hash zopfli 2> /dev/null; then
        cmd="zopfli"
    elif hash pigz 2> /dev/null; then
        cmd="pigz"
    else
        cmd="gzip"
    fi

    echo "Compressing .tar ($((size / 1000)) kB) using \`${cmd}\`…"
    "${cmd}" -v "${tmpFile}" || return 1
    [ -f "${tmpFile}" ] && rm "${tmpFile}"

    zippedSize=$(stat -f"%z" "${tmpFile}.gz" 2> /dev/null || stat -c"%s" "${tmpFile}.gz" 2> /dev/null)
    echo "${tmpFile}.gz ($((zippedSize / 1000)) kB) created successfully."
}

# Compare original and gzipped file size
function gz() {
    local origsize=$(wc -c < "$1")
    local gzipsize=$(gzip -c "$1" | wc -c)
    local ratio=$(echo "$gzipsize * 100 / $origsize" | bc -l)
    printf "orig: %d bytes\n" "$origsize"
    printf "gzip: %d bytes (%2.2f%%)\n" "$gzipsize" "$ratio"
}

# Create a data URL from a file
function dataurl() {
    local mimeType=$(file -b --mime-type "$1")
    if [[ $mimeType == text/* ]]; then
        mimeType="${mimeType};charset=utf-8"
    fi
    echo "data:${mimeType};base64,$(openssl base64 -in "$1" | tr -d '\n')"
}

# `tre` - tree with sensible defaults
function tre() {
    tree -aC -I '.git|node_modules|bower_components' --dirsfirst "$@" | less -FRNX
}

# `o` with no arguments opens the current directory, otherwise opens the given location
function o() {
    if [ $# -eq 0 ]; then
        open .
    else
        open "$@"
    fi
}

# Use Git's colored diff when available
if hash git &>/dev/null; then
    function diff() {
        git diff --no-index --color-words "$@"
    }
fi

# Normalize `open` across Linux, macOS, and Windows
if [ ! $(uname -s) = 'Darwin' ]; then
    if grep -q Microsoft /proc/version 2>/dev/null; then
        alias open='explorer.exe'
    else
        alias open='xdg-open'
    fi
fi

# URI encode a string
function uriencode() {
    jq -nr --arg v "$1" '$v|@uri'
}

# Gradle nuclear option - clean everything and rebuild
function gradle_nuke_build() {
    echo "Removing ~/.gradle ..."
    rm -rf ~/.gradle
    echo "Removing project .gradle ..."
    rm -rf .gradle
    echo "Starting clean build with dependency refresh ..."
    ./gradlew clean build --refresh-dependencies
}

# Dock hiding/showing
function hidedock() {
    defaults write com.apple.dock autohide -bool true && killall Dock
    defaults write com.apple.dock autohide-delay -float 1000 && killall Dock
    defaults write com.apple.dock no-bouncing -bool TRUE && killall Dock
}

function restoredock() {
    defaults write com.apple.dock autohide -bool false && killall Dock
    defaults delete com.apple.dock autohide-delay && killall Dock
    defaults write com.apple.dock no-bouncing -bool FALSE && killall Dock
}

# SSH with screen
function ssh_screen() {
    ssh -t $1 screen -AadR
}
