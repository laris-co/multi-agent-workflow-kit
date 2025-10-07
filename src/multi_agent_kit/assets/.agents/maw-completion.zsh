#compdef maw
# Zsh completion for maw command

_maw() {
  local -a subcommands
  subcommands=(
    'install:Run setup.sh to provision or refresh agent worktrees'
    'setup:Alias for install'
    'start:Run start-agents.sh to launch the tmux session'
    'agents:Run agents.sh to manage worktrees manually'
    'kill:Run kill-all.sh to terminate tmux sessions by prefix'
    'send:Run send-commands.sh to broadcast commands to panes'
    'remove:Run remove.sh to delete agent worktrees'
    'uninstall:Run uninstall.sh to remove toolkit assets'
    'warp:Navigate to agent worktree or root'
    'help:Show help message'
  )

  local context state line
  typeset -A opt_args

  _arguments -C \
    '1: :->subcommand' \
    '*:: :->args'

  case $state in
    subcommand)
      _describe 'maw subcommand' subcommands
      ;;
    args)
      case $words[1] in
        warp)
          local -a targets
          targets=('root:Repository root directory')
          local agents_dir="${MAW_REPO_ROOT:-$PWD}/agents"
          if [[ -d "$agents_dir" ]]; then
            for agent in "$agents_dir"/*(/N:t); do
              [[ "$agent" == .* ]] && continue
              targets+=("$agent:Agent worktree")
            done
          fi
          _describe 'warp target' targets
          ;;
        start)
          local -a profiles flags
          profiles=(
            'profile0:Top pane + bottom left/right split (3 agents)'
            'profile1:Left column dominant'
            'profile2:Top row 2 agents + bottom full-width root (default)'
            'profile3:Top-full layout'
            'profile4:Three-pane layout'
            'profile5:Six-pane dashboard'
          )
          flags=(
            '--prefix:Session suffix'
            '--detach:Run in detached mode'
            '-d:Run in detached mode'
          )
          _arguments \
            '1: :_describe "profile" profiles' \
            '(--prefix)--prefix[Session suffix]:suffix:' \
            '(--detach -d)'{--detach,-d}'[Run in detached mode]'
          ;;
        remove|uninstall)
          _arguments \
            '(-n --dry-run)'{-n,--dry-run}'[Show planned actions without executing]' \
            '(-f --force)'{-f,--force}'[Force operation]' \
            '(-h --help)'{-h,--help}'[Show help message]' \
            '*:agent:'
          ;;
        agents)
          local -a agent_cmds
          agent_cmds=(
            'create:Create a new agent worktree'
            'list:List all agent worktrees'
            'remove:Remove an agent worktree'
          )
          _describe 'agents subcommand' agent_cmds
          ;;
      esac
      ;;
  esac
}

_maw "$@"
