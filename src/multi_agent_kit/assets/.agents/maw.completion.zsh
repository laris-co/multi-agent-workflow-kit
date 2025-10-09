# Zsh completion for maw command
# Can be sourced directly or loaded via fpath

_maw() {
  local curcontext="$curcontext" state line
  typeset -A opt_args

  local -a subcommands
  subcommands=(
    'attach:Attach to the running tmux session'
    'agents:Run agents.sh to manage worktrees manually'
    'catlab:Download CLAUDE.md guidelines from catlab gist'
    'direnv:Run direnv allow in repo root and all agent worktrees'
    'help:Show help message'
    'hey:Send a message to a specific agent'
    'install:Run setup.sh to provision or refresh agent worktrees'
    'kill:Run kill-all.sh to terminate tmux sessions by prefix'
    'remove:Run remove.sh to delete agent worktrees'
    'send:Run send-commands.sh to broadcast commands to panes'
    'setup:Alias for install'
    'start:Run start-agents.sh to launch the tmux session'
    'uninstall:Run uninstall.sh to remove toolkit assets'
    'version:Show toolkit version information'
    'warp:Navigate to agent worktree or root'
    'zoom:Toggle zoom (maximize/restore) for a specific agent pane'
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
        hey)
          if [[ $CURRENT -eq 3 ]]; then
            # Complete agent names and special targets
            local agents_dir="${MAW_REPO_ROOT:-$PWD}/agents"
            local -a targets
            targets=('root:Main worktree pane' 'all:Broadcast to all agents')

            if [[ -d "$agents_dir" ]]; then
              local dir
              for dir in "$agents_dir"/*(N/); do
                local basename="${dir:t}"
                [[ "$basename" == .* ]] && continue
                targets+=("$basename:Agent worktree")
              done
            fi

            _describe -t targets 'agent' targets
          fi
          ;;
        warp)
          local agents_dir="${MAW_REPO_ROOT:-$PWD}/agents"
          local -a agent_dirs

          # Add root option
          _wanted targets expl 'warp target' compadd -d '(Repository root directory)' root

          # Add agent directories if they exist
          if [[ -d "$agents_dir" ]]; then
            agent_dirs=()
            local dir
            for dir in "$agents_dir"/*(N/); do
              local basename="${dir:t}"
              [[ "$basename" == .* ]] && continue
              agent_dirs+=("$basename")
            done

            if [[ ${#agent_dirs[@]} -gt 0 ]]; then
              _wanted agents expl 'agent worktree' compadd -a agent_dirs
            fi
          fi
          ;;
        zoom)
          local agents_dir="${MAW_REPO_ROOT:-$PWD}/agents"
          local -a agent_dirs

          # Add special options
          _wanted targets expl 'zoom target' compadd -d '(Repository root directory)' root
          _wanted options expl 'zoom options' compadd --list

          # Add agent directories if they exist
          if [[ -d "$agents_dir" ]]; then
            agent_dirs=()
            local dir
            for dir in "$agents_dir"/*(N/); do
              local basename="${dir:t}"
              [[ "$basename" == .* ]] && continue
              agent_dirs+=("$basename")
            done

            if [[ ${#agent_dirs[@]} -gt 0 ]]; then
              _wanted agents expl 'agent worktree' compadd -a agent_dirs
            fi
          fi
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
