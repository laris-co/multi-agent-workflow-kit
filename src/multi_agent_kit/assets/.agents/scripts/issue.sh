#!/bin/bash
set -euo pipefail

usage() {
    cat <<'USAGE'
Usage: issue.sh [options] [title] [body]

Create a GitHub issue for the current repository (or a specified repo).

Options:
  --title <title>           Issue title (defaults to first positional arg)
  --body <body>             Issue body text (use quotes for multi-line text)
  --body-file <path>        Read issue body from file
  --label <name>            Add a single label (repeatable)
  --labels <l1,l2,...>      Comma-separated label list
  --assignee <login>        Assign issue to user (repeatable)
  --assignees <u1,u2,...>   Comma-separated assignee list
  --repo <owner/name>       Target repository (defaults to current repo)
  --web                     Open the created issue in the browser
  --dry-run                 Print the gh command without executing
  -h, --help                Show this help message

Body precedence (first non-empty wins):
  1. --body-file
  2. --body argument
  3. Remaining positional arguments (after title)
  4. Piped STDIN
USAGE
}

print_error() {
    printf '❌ %s\n' "$1" >&2
}

trim() {
    # Trim leading/trailing whitespace
    local value=$1
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

ensure_gh_authenticated() {
    if ! command -v gh >/dev/null 2>&1; then
        print_error "GitHub CLI (gh) is not installed. Install it from https://cli.github.com/."
        exit 1
    fi

    if ! gh auth status >/dev/null 2>&1; then
        print_error "GitHub CLI is not authenticated. Run 'gh auth login' and try again."
        exit 1
    fi
}

detect_repo_slug() {
    # Attempt gh repo view first (works inside any git worktree)
    local slug
    if slug=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null); then
        if [[ -n "$slug" ]]; then
            printf '%s\n' "$slug"
            return 0
        fi
    fi

    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null || true)
    if [[ -z "$remote_url" ]]; then
        return 1
    fi

    remote_url=${remote_url%.git}
    remote_url=${remote_url#git@github.com:}
    remote_url=${remote_url#ssh://git@github.com/}
    remote_url=${remote_url#https://github.com/}
    remote_url=${remote_url#http://github.com/}
    remote_url=${remote_url#git://github.com/}
    remote_url=${remote_url#github.com:}
    remote_url=${remote_url#github.com/}

    if [[ "$remote_url" =~ ^[^/]+/[^/]+$ ]]; then
        printf '%s\n' "$remote_url"
        return 0
    fi

    return 1
}

TITLE=""
BODY=""
BODY_FILE=""
REPO_OVERRIDE=""
DRY_RUN=0
OPEN_IN_BROWSER=0
declare -a LABELS=()
declare -a ASSIGNEES=()
declare -a POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --title)
            [[ $# -ge 2 ]] || { print_error "--title requires a value"; exit 1; }
            TITLE=$2
            shift 2
            ;;
        --body)
            [[ $# -ge 2 ]] || { print_error "--body requires a value"; exit 1; }
            BODY=$2
            shift 2
            ;;
        --body-file)
            [[ $# -ge 2 ]] || { print_error "--body-file requires a path"; exit 1; }
            BODY_FILE=$2
            shift 2
            ;;
        --label)
            [[ $# -ge 2 ]] || { print_error "--label requires a value"; exit 1; }
            LABELS+=("$2")
            shift 2
            ;;
        --labels)
            [[ $# -ge 2 ]] || { print_error "--labels requires a value"; exit 1; }
            IFS=',' read -ra parts <<< "$2"
            for part in "${parts[@]}"; do
                part=$(trim "$part")
                [[ -n "$part" ]] && LABELS+=("$part")
            done
            shift 2
            ;;
        --assignee)
            [[ $# -ge 2 ]] || { print_error "--assignee requires a value"; exit 1; }
            ASSIGNEES+=("$2")
            shift 2
            ;;
        --assignees)
            [[ $# -ge 2 ]] || { print_error "--assignees requires a value"; exit 1; }
            IFS=',' read -ra parts <<< "$2"
            for part in "${parts[@]}"; do
                part=$(trim "$part")
                [[ -n "$part" ]] && ASSIGNEES+=("$part")
            done
            shift 2
            ;;
        --repo)
            [[ $# -ge 2 ]] || { print_error "--repo requires a value"; exit 1; }
            REPO_OVERRIDE=$2
            shift 2
            ;;
        --web)
            OPEN_IN_BROWSER=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                POSITIONAL+=("$1")
                shift
            done
            break
            ;;
        -*)
            print_error "Unknown option: $1"
            usage >&2
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

if [[ -z "$TITLE" && ${#POSITIONAL[@]} -gt 0 ]]; then
    TITLE=${POSITIONAL[0]}
    POSITIONAL=("${POSITIONAL[@]:1}")
fi

if [[ -n "$BODY_FILE" && -n "$BODY" ]]; then
    print_error "Specify either --body or --body-file, not both."
    exit 1
fi

if [[ -z "$BODY" && -z "$BODY_FILE" && ${#POSITIONAL[@]} -gt 0 ]]; then
    BODY=$(printf '%s ' "${POSITIONAL[@]}")
    BODY=$(trim "$BODY")
    POSITIONAL=()
fi

if [[ -z "$BODY" && -z "$BODY_FILE" && ! -t 0 ]]; then
    BODY=$(cat)
fi

if [[ -z "$TITLE" ]]; then
    print_error "Issue title is required. Provide it via --title or as the first positional argument."
    usage >&2
    exit 1
fi

if [[ -z "$BODY" && -z "$BODY_FILE" ]]; then
    print_error "Issue body is required. Provide it via --body, --body-file, positional arguments, or piped STDIN."
    usage >&2
    exit 1
fi

if [[ -n "$BODY_FILE" && ! -f "$BODY_FILE" ]]; then
    print_error "Body file not found: $BODY_FILE"
    exit 1
fi

ensure_gh_authenticated

TARGET_REPO="$REPO_OVERRIDE"
if [[ -z "$TARGET_REPO" ]]; then
    if TARGET_REPO=$(detect_repo_slug); then
        :
    else
        print_error "Unable to determine repository slug. Use --repo owner/name."
        exit 1
    fi
fi

BODY_PATH="$BODY_FILE"
TEMP_FILE=""
cleanup() {
    if [[ -n "$TEMP_FILE" && -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
    fi
}
trap cleanup EXIT

if [[ -z "$BODY_PATH" ]]; then
    TEMP_FILE=$(mktemp "${TMPDIR:-/tmp}/maw-issue.XXXXXX")
    printf '%s\n' "$BODY" >"$TEMP_FILE"
    BODY_PATH="$TEMP_FILE"
fi

if (( DRY_RUN )); then
    echo "ℹ️  Dry run: would create issue in $TARGET_REPO"
    echo "    Title: $TITLE"
    if [[ -n "$BODY_PATH" ]]; then
        echo "    Body source: $BODY_PATH"
    fi
    if [[ ${#LABELS[@]} -gt 0 ]]; then
        echo "    Labels: ${LABELS[*]}"
    fi
    if [[ ${#ASSIGNEES[@]} -gt 0 ]]; then
        echo "    Assignees: ${ASSIGNEES[*]}"
    fi
    exit 0
fi

CMD=(gh issue create --title "$TITLE" --repo "$TARGET_REPO" --body-file "$BODY_PATH")

if (( ${#LABELS[@]} )); then
    for label in "${LABELS[@]}"; do
        CMD+=(--label "$label")
    done
fi

if (( ${#ASSIGNEES[@]} )); then
    for assignee in "${ASSIGNEES[@]}"; do
        CMD+=(--assignee "$assignee")
    done
fi

if (( OPEN_IN_BROWSER )); then
    CMD+=(--web)
fi

echo "📨 Creating issue in $TARGET_REPO..."
"${CMD[@]}"
