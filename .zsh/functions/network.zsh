#!/usr/bin/env zsh
#
# Network-related functions
#

# Run `dig` and display the most useful info
function digga() {
    dig +nocmd "$1" any +multiline +noall +answer
}

# Show all the names (CNs and SANs) listed in the SSL certificate for a given domain
function getcertnames() {
    if [ -z "${1}" ]; then
        echo "ERROR: No domain specified."
        return 1
    fi

    if [ -z "${2}" ]; then
        echo "ERROR: No port specified."
        return 1
    fi

    local domain="${1}"
    local port="${2}"
    echo "Testing ${domain}…"
    echo ""

    local tmp=$(echo -e "GET / HTTP/1.0\nEOT" \
        | openssl s_client -connect "${domain}:${port}" -servername "${domain}" 2>&1)

    if [[ "${tmp}" = *"-----BEGIN CERTIFICATE-----"* ]]; then
        local certText=$(echo "${tmp}" \
            | openssl x509 -text -certopt "no_aux, no_header, no_issuer, no_pubkey, \
            no_serial, no_sigdump, no_signame, no_validity, no_version")
        echo "Common Name:"
        echo ""
        echo "${certText}" | grep "Subject:" | sed -e "s/^.*CN=//" | sed -e "s/\/emailAddress=.*//"
        echo ""
        echo "Subject Alternative Name(s):"
        echo ""
        echo "${certText}" | grep -A 1 "Subject Alternative Name:" \
            | sed -e "2s/DNS://g" -e "s/ //g" | tr "," "\n" | tail -n +2
        return 0
    else
        echo "ERROR: Certificate not found."
        return 1
    fi
}

# Start an HTTP server from a directory, optionally specifying the port
function server() {
    local port="${1:-8000}"
    sleep 1 && open "http://localhost:${port}/" &
    python3 -m http.server "$port"
}

# Start a PHP server from a directory, optionally specifying the port
function phpserver() {
    local port="${1:-4000}"
    local ip=$(ipconfig getifaddr en1)
    sleep 1 && open "http://${ip}:${port}/" &
    php -S "${ip}:${port}"
}
