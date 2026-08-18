#!/usr/bin/env bash
#
# Catches the two ways kramdown silently mangles math in a post:
#
#   1. Leaked "$$" in the rendered HTML — kramdown failed to pair the math
#      delimiters. Usually a typo like `$$g$` (one closing dollar).
#   2. Phantom <table> elements — a bare `|` inside inline math tripped
#      kramdown's table parser, which splits the line into cells, breaks the
#      `$$` pairing and eats the bars. Fix: use \lvert ... \rvert (and \mid
#      for divisibility) in any $$...$$ that shares a line with prose.
#
# Ground truth comes from rendering through real kramdown in Docker. With no
# Docker daemon we fall back to a source-level lint, which is approximate but
# still catches both root causes.
#
# Usage: script/check-post-math.sh FILE...
#        script/check-post-math.sh --staged   (renders staged blobs, not worktree)

set -uo pipefail

IMAGE="seroze-blog-mathcheck:1"
DOCKERFILE="$(dirname "$0")/mathcheck.Dockerfile"
status=0

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- gather the files to check, and their content -----------------------------

declare -a names=()

if [ "${1:-}" = "--staged" ]; then
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        n="$(echo "$f" | tr '/' '_')"
        git show ":$f" > "$tmp/$n" 2>/dev/null || continue
        names+=("$n")
        echo "$f" > "$tmp/$n.origin"
    done < <(git diff --cached --name-only --diff-filter=ACM -- '_posts/*.md')
else
    for f in "$@"; do
        [ -f "$f" ] || continue
        n="$(echo "$f" | tr '/' '_')"
        cp "$f" "$tmp/$n"
        names+=("$n")
        echo "$f" > "$tmp/$n.origin"
    done
fi

[ ${#names[@]} -eq 0 ] && exit 0

# Strip YAML frontmatter — kramdown would render it as a paragraph.
for n in "${names[@]}"; do
    sed '1{/^---$/!q};1,/^---$/d' "$tmp/$n" > "$tmp/$n.body"
done

# Count genuine source tables: contiguous runs of lines starting with `|`,
# ignoring fenced code blocks. Anything kramdown renders beyond this is phantom.
count_source_tables() {
    awk '
        /^[ \t]*```/ { fence = !fence; prev = 0; next }
        fence        { next }
        /^[ \t]*\|/  { if (!prev) { blocks++; prev = 1 } next }
                     { prev = 0 }
        END          { print blocks + 0 }
    ' "$1"
}

report() { echo "  $1"; }

# Lines where a bare `|` inside inline math will trip kramdown's table parser.
# Verified against kramdown's actual behaviour, which fires only when ALL hold:
#   - the line starts a block (blank line before it, or it's a list-item line);
#     a continuation line inside an existing paragraph/bullet is safe
#   - the pipe is unescaped (`\|` is fine) and not inside a `code span`
#   - the line mixes math with prose; a standalone $$...$$ line parses as a
#     math block before the table parser ever sees it
suspect_lines() {
    awk '
        BEGIN                { blank = 1 }
        /^[ \t]*```/         { fence = !fence; blank = 0; next }
        fence                { next }
        /^[ \t]*$/           { blank = 1; next }
        /^[ \t]*\|/          { blank = 0; next }   # a genuine table row
        {
            line = $0
            gsub(/`[^`]*`/, "", line)     # code spans are safe
            gsub(/\\\|/, "", line)        # escaped pipes are safe
            islist = (line ~ /^[ \t]*([-*+]|[0-9]+\.)[ \t]/)
            if ((blank || islist) &&
                line ~ /\$\$/ && line ~ /\|/ &&
                line !~ /^[ \t]*\$\$[^$]*\$\$[ \t]*$/)
                print "    line " FNR ": " substr($0, 1, 110)
            blank = 0
        }
    ' "$1"
}

# --- fallback: lint the markdown source directly ------------------------------

source_lint() {
    local body="$1" src="$2" bad=0

    # Unbalanced $$ (outside code fences) means a delimiter typo.
    local dollars
    dollars=$(awk '
        /^[ \t]*```/ { fence = !fence; next }
        fence        { next }
        { n = gsub(/\$\$/, "&"); total += n }
        END          { print total + 0 }
    ' "$body")
    if [ $((dollars % 2)) -ne 0 ]; then
        report "odd number of \$\$ delimiters ($dollars) — one span is unclosed"
        # A bare `$$` on its own line is a legitimate block delimiter and is
        # expected to be odd; the culprit is a prose line with odd parity.
        awk '
            /^[ \t]*```/         { fence = !fence; next }
            fence                { next }
            /^[ \t]*\$\$[ \t]*$/ { next }
            { if (gsub(/\$\$/, "&") % 2) print "    line " FNR ": " substr($0, 1, 110) }
        ' "$body"
        bad=1
    fi

    # Bare | inside inline math (a line with math AND prose, not a table row).
    local hits
    hits=$(suspect_lines "$body")
    if [ -n "$hits" ]; then
        report "bare | inside inline math — use \\lvert ... \\rvert or \\mid"
        echo "$hits"
        bad=1
    fi

    [ $bad -eq 0 ] && return 0
    echo "  ^ in $src"
    return 1
}

# --- primary: render through real kramdown ------------------------------------

use_docker=1
if ! docker info >/dev/null 2>&1; then
    use_docker=0
    echo "WARNING: Docker unavailable — falling back to source-level lint."
    echo "         This is approximate; run the full render before publishing."
fi

if [ $use_docker -eq 1 ] && ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    echo "Building $IMAGE (one time)..."
    docker build -q -t "$IMAGE" -f "$DOCKERFILE" "$(dirname "$DOCKERFILE")" >/dev/null 2>&1 \
        || { echo "WARNING: image build failed — falling back to source lint."; use_docker=0; }
fi

if [ $use_docker -eq 1 ]; then
    docker run --rm -v "$tmp":/w -w /w "$IMAGE" \
        sh -c 'for f in *.body; do kramdown --math-engine mathjax "$f" > "$f.html" 2>/dev/null; done' \
        >/dev/null 2>&1
fi

for n in "${names[@]}"; do
    src="$(cat "$tmp/$n.origin")"

    if [ $use_docker -eq 0 ] || [ ! -s "$tmp/$n.body.html" ]; then
        source_lint "$tmp/$n.body" "$src" || status=1
        continue
    fi

    html="$tmp/$n.body.html"
    file_bad=0

    leaked=$(grep -c '\$\$' "$html")
    if [ "$leaked" -ne 0 ]; then
        echo "$src"
        report "$leaked leaked \$\$ in rendered HTML — unpaired math delimiters"
        grep -n '\$\$' "$html" | head -5 | sed 's/^/    /'
        file_bad=1
    fi

    rendered=$(grep -c '<table>' "$html")
    genuine=$(count_source_tables "$tmp/$n.body")
    if [ "$rendered" -gt "$genuine" ]; then
        [ $file_bad -eq 0 ] && echo "$src"
        report "$rendered <table> rendered but only $genuine in source — $((rendered - genuine)) phantom"
        report "caused by a bare | inside inline math; use \\lvert ... \\rvert or \\mid"
        suspect_lines "$tmp/$n.body"
        file_bad=1
    fi

    [ $file_bad -eq 1 ] && status=1
done

if [ $status -ne 0 ]; then
    echo
    echo "Math rendering check failed. See the Math / LaTeX section of CLAUDE.md."
    echo "To commit anyway: git commit --no-verify"
fi

exit $status
