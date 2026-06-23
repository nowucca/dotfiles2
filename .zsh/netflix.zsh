#!/usr/bin/env zsh
#
# Netflix-specific configuration
# Note: This file contains work-specific aliases and config
#

# Only load on macOS (not in Coder workspaces typically)
is_mac || return 0

# Git credentials for Netflix (optimized to only run when needed)
if [[ "$(git config --global user.email 2>/dev/null)" != "satkinson@netflix.com" ]]; then
    git config --global user.email 'satkinson@netflix.com'
    git config --global user.name  'Steven Atkinson'
    git config --global push.autoSetupRemote true
fi

# Merge .gitconfig-netflix if needed
if [ -r ${HOME}/.gitconfig-netflix ]; then
    grep metatron ${HOME}/.gitconfig >/dev/null 2>&1
    if [ "$?" != 0 ]; then
        cat ${HOME}/.gitconfig-netflix >> ${HOME}/.gitconfig
        cat ${HOME}/.gitconfig-netflix-ghes >> ${HOME}/.gitconfig
    fi
fi

# Environment
export NETFLIX_DEV=true
export DOCKER_DEFAULT_PLATFORM=linux/amd64  # For subscriberservice2

# Spinnaker
[ -r ${HOME}/.spinnaker-env.sh ] && source ${HOME}/.spinnaker-env.sh

# AWS/Weep configuration (for running weep serve)
export AWS_CONTAINER_CREDENTIALS_FULL_URI='http://localhost:9091/ecs/arn:aws:iam::567395257996:role/awsmanagement_dynamic_config_mgt'

# Netflix Work aliases
alias todo="gvim ~/drive/todo"
alias nf="gvim ~/drive/todo-netflix.md"

# Netflix workspaces (Coder)
alias worklist='work list --column "workspace,status,starts at,stops after"'
alias workssh='work ssh'
alias workcreate='work create'

# Create a Change Confidence workspace off main with 32 CPU / 128 GB
# Usage: work-create-cc [workspace-name]
#   workspace-name defaults to "change-confidence-main"
function work-create-cc() {
  local name="${1:-change-confidence-main}"
  work create \
    --template workspace-v1 \
    --parameter "git_repo=https://git.netflix.net/corp/change-confidence-dev-workspace.git" \
    --parameter "git_branch=main" \
    --parameter "instance_size=m7a.8xlarge" \
    --use-parameter-defaults \
    --yes \
    "$name"
}

# AWS/Weep aliases
alias awsdbtest_asapp="weep file --force arn:aws:iam::179727101194:role/platformserviceInstanceProfile -A arn:aws:iam::521597827845:role/PlatformserviceDynamodbRole"
alias awsdbprod_asapp="weep file --force arn:aws:iam::149510111645:role/platformserviceInstanceProfile -A arn:aws:iam::567395257996:role/PlatformserviceDynamodbRole"
alias awsdbtest="weep file arn:aws:iam::179727101194:role/platformserviceInstanceProfile -A arn:aws:iam::521597827845:role/PlatformserviceDynamodbRole"
alias awsdbprod="weep file arn:aws:iam::149510111645:role/platformserviceInstanceProfile -A arn:aws:iam::567395257996:role/PlatformserviceDynamodbRole"
alias awsdbtestdirect="weep file --force arn:aws:iam::521597827845:role/awsmanagementtest_dynamic_config_mgt"
alias awsdbproddirect="weep file --force arn:aws:iam::567395257996:role/awsmanagement_dynamic_config_mgt"
alias awstest="weep --force file arn:aws:iam::179727101194:role/nsacRole"
alias weepls="alias awsdbtest awsdbprod awstest awsdeleng"

# LLM/AI aliases
alias llm='/Users/satkinson/.llm-netflix/env/bin/llm'
alias bot='/Users/satkinson/.llm-netflix/env/bin/llm netflix'
alias alacritty='/Applications/Alacritty.app/Contents/MacOS/alacritty &'

# AI Proxy configuration
configure_aiproxy() {
    cat << EOF > /tmp/proxy-config.yaml
apiVersion: "v1"
spec:
  meshServers:
    - name: foo
      config:
        localTargets:
          - name: lo_egress
            httpWorkload:
              port: 2002
              requestTimeoutMs: 0
        listeners:
        - name: strip_auth
          port: 7002
          handlers:
            - http:
                security:
                  plaintext: {}
                headers:
                  requestHeadersToRemove:
                    - "Authorization"
                defaultRoute:
                  localTargetName: lo_egress
EOF
}

alias start-aiproxy='configure_aiproxy && newt --app-type mesh start -e prod -s /tmp/proxy-config.yaml'

# Cline setup function
function setup_cline() {
    echo "Please ensure your VPN is connected and Docker is running."

    if [ -z "$1" ]; then
        echo "Model Gateway project ID is required."
        echo "Please visit https://go.netflix.com/modelgateway to create a project ID."
        return 1
    fi

    local MODEL_GATEWAY_PROJECT_ID="$1"

    configure_aiproxy

    echo "Starting the proxy..."
    newt --app-type mesh start -e prod -s /tmp/proxy-config.yaml

    echo "Testing the connection..."
    curl -vvv http://copilotdppython-secure.us-east-1.prod.svip.mesh.netflix.net:7002/proxy/$MODEL_GATEWAY_PROJECT_ID/v1/chat/completions \
        -H "content-type: application/json" \
        -d '{"model": "gpt-4o", "messages": [{"content": "foo", "role": "user"}]}'

    echo "\n\nSetup complete. Please configure the Cline extension in your IDE as per the instructions at https://go.netflix.com/cline"
}

# Model listing
alias listmodels='metatron curl -a copilotcp ''https://copilotcp.cluster.us-east-1.prod.cloud.netflix.net:8443/models/list_models?includeHidden=false'' | jq ''.models[].id'''

function models() {
    metatron curl -a copilotcp 'https://copilotcp.vip.us-east-1.prod.cloud.netflix.net:8443/models/list_models' \
        -H 'accept: application/json' | \
        jq -r '.models[] | .id + " (context size: " + (.contextSize | tostring) + ")"'
}

# AWS role helper
function aws_role() {
    local roleName="$1"
    local accountId="$2"
    weep file --force arn:aws:iam::${accountId}:role/${roleName}
}
