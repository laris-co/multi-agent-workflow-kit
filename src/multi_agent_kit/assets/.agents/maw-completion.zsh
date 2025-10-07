# Zsh completion for maw command
# Can be sourced directly or loaded via fpath

_maw() {
  local curcontext="$curcontext" state line
  typeset -A opt_args

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

  _arguments -C \
    '1: :->subcommand' \
    '*::arg:->args' && return 0

  case "$state" in
    subcommand)
      _describe -t subcommands 'maw subcommand' subcommands
      ;;
    args)
      case "${words[1]}" in
        warp)
          local -a targets
          targets=('root:Repository root directory')
          local agents_dir="${MAW_REPO_ROOT:-$PWD}/agents"
          if [[ -d "$agents_dir" ]]; then
            local agent
            for agent in "$agents_dir"/*(N:t); do
              [[ "$agent" == .* ]] && continue
              [[ "$agent" == ".gitignore" ]] && continue
              targets+=("$agent:Agent worktree")
            done
          fi
          _describe -t targets 'warp target' targets
          ;;
        start)
          local -a profiles
          profiles=(
            'profile0:Top pane + bottom left/right split (3 agents)'
            'profile1:Left column dominant'
            'profile2:Top row 2 agents + bottom full-width root (default)'
            'profile3:Top-full layout'
            'profile4:Three-pane layout'
            'profile5:Six-pane dashboard'
          )
          _describe -t profiles 'profile' profiles
          ;;
        remove|uninstall)
          _arguments \
            '(-n --dry-run)'{-n,--dry-run}'[Show planned actions without executing]' \
            '(-f --force)'{-f,--force}'[Force operation]' \
            '(-h --help)'{-h,--help}'[Show help message]'
          ;;
        agents)
          local -a agent_cmds
          agent_cmds=(
            'create:Create a new agent worktree'
            'list:List all agent worktrees'
            'remove:Remove an agent worktree'
          )
          _describe -t commands 'agents subcommand' agent_cmds
          ;;
      esac
      ;;
  esac

  return 0
}
