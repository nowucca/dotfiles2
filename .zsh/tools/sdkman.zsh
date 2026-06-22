#!/usr/bin/env zsh
#
# SDKMAN - Software Development Kit Manager (Lazy loaded for ~400ms savings)
#

export SDKMAN_DIR="${HOME}/.sdkman"

# Install SDKMAN! if not present (silenced — errors still surface via stderr)
[[ -r ${SDKMAN_DIR} ]] || curl -fsSL "https://get.sdkman.io" | bash > /dev/null

# Lazy-load SDKMAN - only initializes when you use the sdk command
sdk() {
    unset -f sdk
    [[ -s "${SDKMAN_DIR}/bin/sdkman-init.sh" ]] && source "${SDKMAN_DIR}/bin/sdkman-init.sh"
    sdk "$@"
}
