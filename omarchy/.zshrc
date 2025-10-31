
. "$HOME/.local/share/../bin/env"

if command -v mise &> /dev/null; then
  eval "$(mise activate zsh)"
fi

# Path to your oh-my-zsh installation.
  export ZSH=/home/daiego/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="cloud"


# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

# User configuration

export PATH="$HOME/.local/share/omarchy/bin:/usr/local/heroku/bin:/usr/lib/jvm/java-7-oracle/bin:/usr/lib/jvm/java-7-oracle/db/bin:/usr/lib/jvm/java-7-oracle/jre/bin:/home/daiego/Downloads/android-studio/sdk/tools:/Users/daiego/Downloads/android-studio/sdk/platform-tools:/Users/daiego/.rvm/gems/ruby-2.2.1/bin:/Users/daiego/.rvm/gems/ruby-2.2.1@global/bin:/Users/daiego/.rvm/rubies/ruby-2.2.1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/Users/daiego/.rvm/bin:/Users/daiego/.rvm/bin:/Users/daiego/Downloads/android-studio/sdk/platform-tools:/Users/daiego/Downloads/android-studio/sdk/tools:/Users/daiego/.rvm/bin:/Users/daiego/.rvm/bin:/Users/daiego/.rvm/bin:/Users/daiego/.rvm/bin:/Users/daiego/Downloads/android-studio/sdk/platform-tools:/Users/daiego/Downloads/android-studio/sdk/tools:/Users/daiego/.rvm/bin"
# export MANPATH="/usr/local/man:$MANPATH"

source $ZSH/oh-my-zsh.sh

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/dsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

#Personal Stuff

#Directory aliases
 alias cstuff='/home/daiego/Documents/code-stuff'
 alias podcast-central='/home/daiego/Documents/code-stuff/rails/workspace/podcast-central'
 alias codecast='/home/daiego/Documents/code-stuff/rails/workspace/codecast'
 alias dotfiles='/home/daiego/Documents/code-stuff/dotfiles'
 # alias tmux="tmux -2"
 alias tmux="env TERM=xterm-256color tmux"
 alias vim="nvim"

prompt_context () { }

alias terraform=/usr/local/bin/terraform
# alias ngrok=/home/daiego/Documents/ngrok
alias aws-sso="python3 /home/daiego/.local/lib/python3.8/site-packages/awsssocredrestore/__init__.py"

alias dlv=/home/daiego/go/bin/dlv

# Set loop to mic volume auto-adjust
#

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
[[ -r $NVM_DIR/bash_completion ]] && \. $NVM_DIR/bash_completion


alias credstash=~/.local/bin/credstash
alias stripe=~/.local/bin/stripe
alias clojure-lsp=~/.local/bin/clojure-lsp
#. "$HOME/.cargo/env"
# export VOLTA_HOME="$HOME/.volta"
# export PATH="$VOLTA_HOME/bin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# export MATCH_SERVER=ubuntu@3.87.33.32
# export IOS_SETTINGS_SECRET=adalovelace
# export PROJECT_PATH=~/Adalo/TestApp2
# export BACKEND_SERVICE=hplovecraft
# export BACKEND_URL=https://backend.adalo.com
# export DATABASE_URL=https://database-red.adalo.com
# export DATABASE_API_URL=https://database-api.adalo.com

export ANDROID_HOME=$HOME/Library/Android/sdk # Should be Library/Android/sdk
export ANDROID_ROOT_SDK=$HOME/Library/Android/sdk # Should be Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools


export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk-11.0.17.jdk/Contents/Home
# export JAVA_HOME=/Library/Java/JavaVirtualMachines/jdk1.8.0_341.jdk/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH

# alias cargo=/home/daiego/.cargo/bin

export LLVM_ROOT=/home/daiego/llvm
