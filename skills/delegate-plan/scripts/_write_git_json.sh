# Shared by all three drivers. git.json is the authoritative evidence the host reads, so it
# is built in a temp file and moved only on success: a half-written or empty one would be
# read as fact. $h is required non-empty, else committed would read true (h != b) purely
# because rev-parse failed. Callers set WT, BASE and RUN before calling.
write_git_json() {
  ( cd "$WT" && h=$(git rev-parse HEAD) && [ -n "$h" ] && jq -n \
      --arg b "$BASE" \
      --arg h "$h" \
      --arg t "$(git diff --name-only "$BASE")" \
      --arg o "$(git ls-files --others --exclude-standard)" \
      --arg u "$(git status --porcelain)" \
      '{base_sha:$b, head_sha:$h, committed:($h != $b),
        files_touched:(($t + "\n" + $o) | split("\n") | map(select(length > 0)) | unique),
        uncommitted:$u}' \
  ) > "$RUN/git.json.tmp" 2>"$RUN/git.json.err" \
    && [ -s "$RUN/git.json.tmp" ] && mv "$RUN/git.json.tmp" "$RUN/git.json" \
    || rm -f "$RUN/git.json.tmp"
}
