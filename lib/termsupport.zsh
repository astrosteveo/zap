#!/usr/bin/env zsh
#
# termsupport.zsh - Terminal window and tab title support
#
# WHY: Automatically sets terminal title to show current command and directory.
# This provides excellent UX - users can see at a glance what's running in each tab.
#
# Based on Oh-My-Zsh's termsupport.zsh
# Reference: https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/termsupport.zsh
#
# Configuration (via zstyle):
#   zstyle ':zap:terminal' title 'yes|no'  # Enable auto-title (default: yes)
#   zstyle ':zap:terminal' osc7 'yes|no'   # Enable OSC 7 (default: yes)
#
# Examples:
#   # Disable auto-title
#   zstyle ':zap:terminal' title 'no'

# Read configuration
local enable_title
zstyle -s ':zap:terminal' title 'enable_title' || enable_title='yes'

# Exit early if disabled
[[ "$enable_title" == 'no' ]] && return 0

#
# _zap_title - Set terminal window and tab/icon title
#
# Purpose: Updates terminal emulator title using escape sequences
# Parameters:
#   $1 - Short title (for tab)
#   $2 - Long title (for window) - optional, defaults to $1
# WHY: Different terminals support different title formats. This function
#      handles the escape sequence differences across terminals.
#
_zap_title() {
  setopt localoptions nopromptsubst

  # Don't set title inside emacs (unless using vterm)
  # WHY: Emacs terminal emulator doesn't support title setting
  [[ -n "${INSIDE_EMACS:-}" && "$INSIDE_EMACS" != vterm ]] && return

  # if $2 is unset use $1 as default
  : ${2=$1}

  case "$TERM" in
    cygwin|xterm*|putty*|rxvt*|konsole*|ansi|mlterm*|alacritty*|st*|foot*|contour*|wezterm*)
      print -Pn "\e]2;${2:q}\a" # Set window name
      print -Pn "\e]1;${1:q}\a" # Set tab name
      ;;
    screen*|tmux*)
      print -Pn "\ek${1:q}\e\\" # Set screen hardstatus
      ;;
    *)
      if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
        print -Pn "\e]2;${2:q}\a" # Set window name
        print -Pn "\e]1;${1:q}\a" # Set tab name
      else
        # Try to use terminfo to set the title
        if (( ${+terminfo[fsl]} && ${+terminfo[tsl]} )); then
          print -Pn "${terminfo[tsl]}$1${terminfo[fsl]}"
        fi
      fi
      ;;
  esac
}

# Title format strings
# WHY: Provide sensible defaults that show useful context without clutter
ZAP_THEME_TERM_TAB_TITLE_IDLE="${ZAP_THEME_TERM_TAB_TITLE_IDLE:-%15<..<%~%<<}"  # 15 char truncated PWD
ZAP_THEME_TERM_TITLE_IDLE="${ZAP_THEME_TERM_TITLE_IDLE:-%n@%m:%~}"             # user@host:path

# Avoid duplication of directory in terminals with independent dir display
# WHY: Apple Terminal shows pwd in title bar already
if [[ "$TERM_PROGRAM" == Apple_Terminal ]]; then
  ZAP_THEME_TERM_TITLE_IDLE="%n@%m"
fi

#
# _zap_termsupport_precmd - Update title when prompt is shown
#
# WHY: This hook runs before each prompt display, showing idle state
#
_zap_termsupport_precmd() {
  _zap_title "$ZAP_THEME_TERM_TAB_TITLE_IDLE" "$ZAP_THEME_TERM_TITLE_IDLE"
}

#
# _zap_termsupport_preexec - Update title when command executes
#
# Purpose: Shows running command in terminal title
# Parameters:
#   $1 - The command being executed (unused, but passed by hook)
#   $2 - The full command line with arguments
# WHY: Seeing "git push" or "npm install" in the tab title is incredibly useful
#      for tracking long-running commands across multiple terminal tabs.
#
_zap_termsupport_preexec() {
  emulate -L zsh
  setopt extended_glob

  # Split command into array of arguments
  local -a cmdargs
  cmdargs=("${(z)2}")

  # If running fg, extract the command from the job description
  # WHY: "fg" doesn't tell you what's being foregrounded; show the actual command
  if [[ "${cmdargs[1]}" = fg ]]; then
    local job_id jobspec="${cmdargs[2]#%}"

    # Parse job specification (see zsh jobs documentation)
    case "$jobspec" in
      <->) job_id=${jobspec} ;;                                # %number
      ""|%|+) job_id=${(k)jobstates[(r)*:+:*]} ;;            # current job
      -) job_id=${(k)jobstates[(r)*:-:*]} ;;                   # previous job
      [?]*) job_id=${(k)jobtexts[(r)*${(Q)jobspec}*]} ;;      # %?string
      *) job_id=${(k)jobtexts[(r)${(Q)jobspec}*]} ;;          # %string
    esac

    # Override with actual job command if found
    if [[ -n "${jobtexts[$job_id]}" ]]; then
      1="${jobtexts[$job_id]}"
      2="${jobtexts[$job_id]}"
    fi
  fi

  # Extract command name (skip assignments, sudo, ssh, etc.)
  # WHY: Show "vim" not "sudo vim", show "deploy.sh" not "SSH=... ./deploy.sh"
  local CMD="${1[(wr)^(*=*|sudo|ssh|mosh|rake|-*)]:gs/%/%%}"
  local LINE="${2:gs/%/%%}"

  # Set title: tab shows command, window shows full line
  _zap_title "$CMD" "%100>...>${LINE}%<<"
}

#
# _zap_termsupport_cwd - Report current directory to terminal (OSC 7)
#
# WHY: Modern terminals use OSC 7 to track the current directory. This enables:
#      - "New Tab at Current Directory" in iTerm2/Terminal.app
#      - Proper directory display in terminal tab bars
#      - Terminal multiplexer integration
#
# Reference: https://gitlab.freedesktop.org/Per_Bothner/specifications/blob/master/proposals/semantic-prompts.md
#
_zap_termsupport_cwd() {
  # URL-encode the hostname and path
  # WHY: File URIs require percent-encoding for special characters
  local URL_HOST URL_PATH
  URL_HOST="$(omz_urlencode -P $HOST)" || return 1
  URL_PATH="$(omz_urlencode -P $PWD)" || return 1

  # Konsole doesn't want the host
  # WHY: Konsole errors if HOST is provided in OSC 7
  [[ -n "$KONSOLE_PROFILE_NAME" || -n "$KONSOLE_DBUS_SESSION" ]] && URL_HOST=""

  # Emit OSC 7 escape sequence
  printf "\e]7;file://%s%s\e\\" "${URL_HOST}" "${URL_PATH}"
}

#
# URL encoding function (from Oh-My-Zsh)
#
# WHY: OSC 7 requires percent-encoded paths
#
omz_urlencode() {
  emulate -L zsh
  local -a opts
  zparseopts -D -E -a opts r m P

  local in_str="$@"
  local url_str=""
  local spaces_as_plus
  if [[ -z $opts[(r)-P] ]]; then spaces_as_plus=1; fi
  local str="$in_str"

  # URLs must use UTF-8 encoding; convert if required
  # WHY: Only convert if we have a valid encoding and it's not already UTF-8
  local encoding="${langinfo[CODESET]:-UTF-8}"
  local safe_encodings
  safe_encodings=(UTF-8 utf8 US-ASCII)
  if [[ -n "$encoding" && -z ${safe_encodings[(r)$encoding]} ]]; then
    # Try to convert, but don't fail if iconv isn't available or has issues
    # WHY: URL encoding for OSC 7 is a nice-to-have, not critical functionality
    local converted
    if converted=$(echo -E "$str" | iconv -f "$encoding" -t UTF-8 2>/dev/null); then
      str="$converted"
    fi
    # If iconv fails, just use the original string (it will likely work anyway)
  fi

  # Use LC_CTYPE=C to process text byte-by-byte
  local i byte ord LC_ALL=C
  export LC_ALL
  local reserved=';/?:@&=+$,'
  local mark='_.!~*''()-'
  local dont_escape="[A-Za-z0-9"
  if [[ -z $opts[(r)-r] ]]; then
    dont_escape+=$reserved
  fi
  # $mark must be last because of the "-"
  if [[ -z $opts[(r)-m] ]]; then
    dont_escape+=$mark
  fi
  dont_escape+="]"

  # Implemented to use a single printf call and avoid subshells in the loop,
  # for performance.
  url_str=""
  for (( i = 1; i <= ${#str}; ++i )); do
    byte="$str[i]"
    if [[ "$byte" =~ "$dont_escape" ]]; then
      url_str+="$byte"
    else
      if [[ "$byte" == " " && -n $spaces_as_plus ]]; then
        url_str+="+"
      else
        ord=$(( [##16] #byte ))
        url_str+="%$ord"
      fi
    fi
  done
  echo -E "$url_str"
}

#
# Initialize terminal support
#
# WHY: Register hooks to update title automatically. Use precmd instead of chpwd
#      to avoid contaminating output when scripts change directory.
#

# Don't initialize if inside Emacs or in SSH session
# WHY: Emacs doesn't support title setting; SSH sessions might have terminal mismatch
if [[ -n "$INSIDE_EMACS" && "$INSIDE_EMACS" != vterm ]]; then
  return
fi

# Don't initialize in unsupported terminals
# WHY: Some terminals don't support OSC sequences or handle them incorrectly
case "$TERM" in
  xterm*|putty*|rxvt*|konsole*|mlterm*|alacritty*|screen*|tmux*|contour*|foot*) ;;
  *)
    case "$TERM_PROGRAM" in
      Apple_Terminal|iTerm.app) ;;
      *) return ;;
    esac
    ;;
esac

# Register hooks
autoload -Uz add-zsh-hook
add-zsh-hook precmd _zap_termsupport_precmd
add-zsh-hook preexec _zap_termsupport_preexec

# Register OSC 7 support (skip in SSH sessions)
# WHY: OSC 7 is for local terminals, not useful in SSH
if [[ -z "$SSH_CLIENT" && -z "$SSH_TTY" ]]; then
  add-zsh-hook precmd _zap_termsupport_cwd
fi
