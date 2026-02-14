#!/usr/bin/env zsh
#
# Claude AI functions - agents, skills, and workflow automation
#

# ============================================
# QUICK TASK AGENTS
# ============================================

# Run a code review agent on staged changes
function claudereview() {
    local changes=$(git diff --staged)
    if [[ -z "$changes" ]]; then
        echo "No staged changes to review. Use 'git add' first."
        return 1
    fi
    echo "$changes" | claude --print "You are a senior code reviewer. Review this diff for:
1. Bugs and potential issues
2. Code quality and best practices
3. Security concerns
4. Performance implications

Be specific and actionable in your feedback."
}

# Run a commit message generator
function claudecommit() {
    local changes=$(git diff --staged)
    if [[ -z "$changes" ]]; then
        echo "No staged changes. Use 'git add' first."
        return 1
    fi
    echo "$changes" | claude --print "Generate a conventional commit message for this diff.
Use format: type(scope): description

Types: feat, fix, docs, style, refactor, test, chore
Keep the first line under 72 characters.
Add a body if the change is complex.

Output ONLY the commit message, nothing else."
}

# Quick documentation generator for a file
function claudedoc() {
    if [[ -z "$1" ]]; then
        echo "Usage: claudedoc <file>"
        return 1
    fi
    if [[ ! -f "$1" ]]; then
        echo "File not found: $1"
        return 1
    fi
    cat "$1" | claude --print "Generate comprehensive documentation for this code:
- Overview/purpose
- Key functions/classes with descriptions
- Usage examples
- Parameters and return values where applicable

Format as Markdown."
}

# ============================================
# PROJECT CONTEXT FUNCTIONS
# ============================================

# Start Claude with project context (README + file tree)
function claudectx() {
    local context=""
    context+="=== Project: $(basename $PWD) ===\n\n"
    
    if [[ -f "README.md" ]]; then
        context+="=== README ===\n$(cat README.md)\n\n"
    fi
    
    if [[ -f "package.json" ]]; then
        context+="=== package.json ===\n$(cat package.json)\n\n"
    fi
    
    context+="=== File Structure ===\n$(tree -L 2 --noreport -I 'node_modules|.git|dist|build' 2>/dev/null || find . -maxdepth 2 -type f | head -50)\n"
    
    if [[ -n "$*" ]]; then
        echo "$context" | claude --print "Project context above. Task: $*"
    else
        echo "$context" | claude --print "I'm sharing project context. What would you like to know or do?"
    fi
}

# Start Claude focused on a specific directory
function claudein() {
    if [[ -z "$1" ]]; then
        echo "Usage: claudein <directory> [prompt]"
        return 1
    fi
    (cd "$1" && shift && claude "$@")
}

# ============================================
# AGENT SKILL LAUNCHERS
# ============================================

# Code debugging agent - pass error message and optionally a file
function claudedebug() {
    if [[ -z "$1" ]]; then
        echo "Usage: claudedebug <error_message> [file]"
        echo "   or: some_command 2>&1 | claudedebug"
        return 1
    fi
    
    local error_msg="$1"
    local file_content=""
    
    if [[ -n "$2" ]] && [[ -f "$2" ]]; then
        file_content="\n\n=== Relevant File: $2 ===\n$(cat $2)"
    fi
    
    echo "Error: $error_msg$file_content" | claude --print "You are a debugging expert. Analyze this error and:
1. Explain what's causing it
2. Suggest specific fixes
3. Show corrected code if applicable
4. Explain how to prevent similar issues"
}

# Pipe errors directly to debug
function claudeerror() {
    # Read from stdin if piped, otherwise use args
    if [[ -p /dev/stdin ]]; then
        cat | claude --print "Analyze this error output and explain the problem with solutions:"
    else
        echo "$*" | claude --print "Analyze this error and explain the problem with solutions:"
    fi
}

# Refactoring agent - takes a file and instruction
function clauderefactor() {
    if [[ -z "$1" ]]; then
        echo "Usage: clauderefactor <file> [instruction]"
        return 1
    fi
    if [[ ! -f "$1" ]]; then
        echo "File not found: $1"
        return 1
    fi
    
    local instruction="${2:-Improve code quality, readability, and maintainability}"
    
    cat "$1" | claude --print "Refactor this code with the following goal: $instruction

Show the refactored code and explain the key improvements."
}

# Test writer agent
function claudetest() {
    if [[ -z "$1" ]]; then
        echo "Usage: claudetest <file> [test_framework]"
        return 1
    fi
    if [[ ! -f "$1" ]]; then
        echo "File not found: $1"
        return 1
    fi
    
    local framework="${2:-appropriate for the language}"
    
    cat "$1" | claude --print "Write comprehensive unit tests for this code using $framework.
Include:
- Happy path tests
- Edge cases
- Error handling tests
- Mocking where appropriate

Format as ready-to-run test code."
}

# Explain code
function claudeexplain() {
    if [[ -z "$1" ]]; then
        echo "Usage: claudeexplain <file> [specific_question]"
        return 1
    fi
    if [[ ! -f "$1" ]]; then
        echo "File not found: $1"
        return 1
    fi
    
    local question="${2:-Explain how this code works}"
    
    cat "$1" | claude --print "$question

Explain:
- Overall purpose and architecture
- Key functions and their roles
- Important patterns or techniques used
- Any notable complexity or gotchas"
}

# ============================================
# WORKFLOW AUTOMATION
# ============================================

# Quick question mode (no conversation, just answer and exit)
function ask() {
    if [[ -z "$*" ]]; then
        echo "Usage: ask <question>"
        return 1
    fi
    claude --print "$*"
}

# Sprint/task agent - create task breakdown
function claudesprint() {
    if [[ -z "$*" ]]; then
        echo "Usage: claudesprint <task_description>"
        return 1
    fi
    claude --print "Break this task into actionable subtasks with time estimates:

Task: $*

For each subtask provide:
1. Clear description
2. Time estimate (in hours)
3. Dependencies on other subtasks
4. Definition of done

Format as a Markdown checklist."
}

# PR description generator
function claudepr() {
    local base="${1:-main}"
    local changes=$(git log --oneline $base..HEAD)
    local diff=$(git diff $base...HEAD --stat)
    
    if [[ -z "$changes" ]]; then
        echo "No changes compared to $base"
        return 1
    fi
    
    echo "Commits:\n$changes\n\nFiles changed:\n$diff" | claude --print "Generate a PR description with:
1. Title (imperative mood, under 72 chars)
2. Summary of changes
3. Type of change (feature/bugfix/refactor/etc)
4. Testing notes
5. Any breaking changes

Format as Markdown."
}

# ============================================
# PIPE-FRIENDLY HELPERS
# ============================================

# Pipe anything to Claude for analysis
function claudepipe() {
    local prompt="${1:-Analyze this input and provide insights:}"
    cat | claude --print "$prompt"
}

# Explain the last command's output (run it again and pipe to claude)
function explainlast() {
    local last_cmd=$(fc -ln -1)
    echo "Running: $last_cmd"
    eval "$last_cmd" 2>&1 | claude --print "Explain this command output. Command was: $last_cmd"
}

# Transform/convert input
function claudetransform() {
    if [[ -z "$1" ]]; then
        echo "Usage: echo 'data' | claudetransform 'convert to JSON'"
        return 1
    fi
    cat | claude --print "Transform this input: $1

Output ONLY the transformed result, no explanation."
}

# ============================================
# PROJECT BOOTSTRAP & MEMORY BANK
# ============================================

# Initialize Memory Bank for a project
function claudeinit() {
    if [[ -d "memory_bank" ]]; then
        echo "memory_bank/ already exists"
        return 1
    fi
    
    mkdir -p memory_bank
    local project_name=$(basename $PWD)
    
    claude --print "I'm starting a new project called '$project_name'. 
Help me create a projectbrief.md by asking me 5-7 key questions about:
- The project's purpose and goals
- Target users
- Technical requirements
- Success criteria
- Constraints or limitations

Then create the memory_bank/projectbrief.md file."
}

# Update memory bank (signals Claude to refresh docs)
function claudeupdate() {
    if [[ ! -d "memory_bank" ]]; then
        echo "No memory_bank/ directory found. Run 'claudeinit' first."
        return 1
    fi
    
    claude --print "update memory bank - Please review the current state of the project and update the memory_bank files, especially activeContext.md and progress.md"
}

# ============================================
# GIT INTEGRATION
# ============================================

# Explain what changed in a commit
function claudeshow() {
    local ref="${1:-HEAD}"
    git show "$ref" --stat --patch | claude --print "Explain what this commit does, why these changes were made, and any potential impacts."
}

# Suggest branch name from description
function claudebranch() {
    if [[ -z "$*" ]]; then
        echo "Usage: claudebranch <feature description>"
        return 1
    fi
    claude --print "Suggest a git branch name for: $*

Use format: type/short-description
Types: feature, fix, refactor, docs, test, chore

Output ONLY the branch name, nothing else."
}

# Interactive conflict resolver helper
function claudeconflict() {
    local conflicts=$(git diff --name-only --diff-filter=U)
    if [[ -z "$conflicts" ]]; then
        echo "No merge conflicts found"
        return 1
    fi
    
    echo "Files with conflicts:\n$conflicts\n\n$(git diff)" | claude --print "Help me resolve these merge conflicts. For each conflict:
1. Explain what both sides are trying to do
2. Suggest the best resolution
3. Show the resolved code"
}
