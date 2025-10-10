# Bash completion for maw command
# shellcheck shell=bash

_maw_complete() {
  local cur prev words cword
  _init_completion || return

  local subcommands="attach agents catlab direnv help hey install kill remove send setup start uninstall version warp zoom"

  if [[ $cword -eq 1 ]]; then
    # Complete main subcommands
    COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
    return 0
  fi

  local subcommand="${words[1]}"

  case "$subcommand" in
    hey)
      # Complete agent names + special targets
      if [[ $cword -eq 2 ]]; then
        local agents_dir="${MAW_REPO_ROOT:-$PWD}/agents"
        local targets="root all"
        if [[ -d "$agents_dir" ]]; then
          local agent_dirs
          agent_dirs=$(ls -1 "$agents_dir" 2>/dev/null | grep -v '^\.')
          targets="$targets $agent_dirs"
        fi
        COMPREPLY=($(compgen -W "$targets" -- "$cur"))
      fi
      return 0
      ;;
    warp)
      # Complete agent names + "root"
      local agents_dir="${MAW_REPO_ROOT:-$PWD}/agents"
      local targets="root"
      if [[ -d "$agents_dir" ]]; then
        local agent_dirs
        agent_dirs=$(ls -1 "$agents_dir" 2>/dev/null | grep -v '^\.')
        targets="$targets $agent_dirs"
      fi
      COMPREPLY=($(compgen -W "$targets" -- "$cur"))
      return 0
      ;;
    zoom)
      # Complete agent names + "root" for zoom command
      local agents_dir="${MAW_REPO_ROOT:-$PWD}/agents"
      local targets="root --list"
      if [[ -d "$agents_dir" ]]; then
        local agent_dirs
        agent_dirs=$(ls -1 "$agents_dir" 2>/dev/null | grep -v '^\.')
        targets="$targets $agent_dirs"
      fi
      COMPREPLY=($(compgen -W "$targets" -- "$cur"))
      return 0
      ;;
    start)
      # Complete profile names
      local profiles="profile0 profile1 profile2 profile3 profile4 profile5"
      local flags="--prefix --detach -d"
      if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "$flags" -- "$cur"))
      else
        COMPREPLY=($(compgen -W "$profiles" -- "$cur"))
      fi
      return 0
      ;;
    remove|uninstall)
      # Complete with common flags
      local flags="--dry-run -n --force -f --help -h"
      COMPREPLY=($(compgen -W "$flags" -- "$cur"))
      return 0
      ;;
    agents)
      # Complete agents.sh subcommands
      local agent_cmds="create list remove"
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "$agent_cmds" -- "$cur"))
      fi
      return 0
      ;;
  esac

  return 0
}

complete -F _maw_complete maw
