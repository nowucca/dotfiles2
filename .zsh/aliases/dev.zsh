#!/usr/bin/env zsh
#
# Development aliases - Java, Maven, Gradle, Docker, etc.
#

# Java version switching (requires java_home)
if is_mac && [[ -x /usr/libexec/java_home ]]; then
    alias java8='export JAVA_HOME=$(/usr/libexec/java_home -v 1.8) && PATH=$JAVA_HOME/bin:$PATH'
    alias java11='export JAVA_HOME=$(/usr/libexec/java_home -v 11) && PATH=$JAVA_HOME/bin:$PATH'
    alias java17='export JAVA_HOME=$(/usr/libexec/java_home -v 17) && PATH=$JAVA_HOME/bin:$PATH'
    alias java21='export JAVA_HOME=$(/usr/libexec/java_home -v 21) && PATH=$JAVA_HOME/bin:$PATH'
fi

# Maven
alias mvnci='mvn clean install | tee mvnci.txt'
alias mvncist='mvn clean install -DskipTests=true | tee mvnci.txt'
alias mvndt='mvn dependency:tree'
alias pmvn='mvn -s $HOME/.m2/personal-settings.xml'
alias pmvnci='pmvn clean install | tee mvnci.txt'
alias pmvncist='pmvn clean install -DskipTests=true | tee mvnci.txt'
alias pmvndt='pmvn dependency:tree'

# Gradle
alias gw="./gradlew"

# TypeScript
alias tsc='npx tsc --noEmit --project packages/app/tsconfig.json'

# Mermaid
alias mmd2png='mmdc --input - -outputFormat png --backgroundColor transparent'

# URL encoding
alias urlencode='python3 -c "import sys, urllib.parse; print(urllib.parse.quote_plus(sys.argv[1]));"'

# PDF merging
alias mergepdf='gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile=_merged.pdf'

# String utilities
alias trim="sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*\$//g'"

# HTTP methods (requires lwp-request)
for method in GET HEAD POST PUT DELETE TRACE OPTIONS; do
    alias "${method}"="lwp-request -m '${method}'"
done

# Make Grunt print stack traces by default
command -v grunt > /dev/null && alias grunt="grunt --stack"

# Print PATH entries on separate lines
alias path='echo -e ${PATH//:/\\n}'

# Intuitive map function
# Example: find . -name .gitattributes | map dirname
alias map="xargs -n1"
