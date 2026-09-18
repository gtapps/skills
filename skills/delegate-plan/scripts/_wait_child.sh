# Shared by all three drivers. Waits for the executor and turns silence into an event:
# executor.log's mtime is the liveness clock, so when it has not moved for STALL_SECS
# the driver prints one DELEGATE_STALL line (the Monitor wakes the host once). If the log
# moves again the flag resets silently: a recovery needs no action, so it earns no wake;
# the next line the host sees is DELEGATE_DONE. Nothing is killed or resumed here; the
# 30m Monitor cap stays the backstop. A crash needs no extra handling: the child exits
# and the driver's DELEGATE_DONE line carries the exit code. Callers set CHILD, RUN and
# INTERRUPTED (the TERM/INT trap) before calling; wait_child sets rc.
STALL_SECS=600
wait_child() {
  local executor="$1" stalled=0 age
  while kill -0 "$CHILD" 2>/dev/null && [ "$INTERRUPTED" = 0 ]; do
    age=$(( $(date +%s) - $(stat -c %Y "$RUN/executor.log" 2>/dev/null || date +%s) ))
    if [ "$stalled" = 0 ] && [ "$age" -ge "$STALL_SECS" ]; then
      stalled=1; echo "DELEGATE_STALL executor=$executor idle=${age}s log=$RUN/executor.log"
    elif [ "$stalled" = 1 ] && [ "$age" -lt "$STALL_SECS" ]; then
      stalled=0
    fi
    sleep 15
  done
  wait "$CHILD" 2>/dev/null; rc=$?
  if [ "$INTERRUPTED" = 1 ]; then rc=143; fi
}
