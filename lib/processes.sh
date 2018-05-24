#!/bin/bash
# Kudos to http://stas-blogspot.blogspot.co.uk/2010/02/kill-all-child-processes-from-shell.html for inspiring this.

kill_child_processes() {
  local _curPid=$1
  local _signal=${2:-SIGHUP}
  local _isTopmost=${3:-1}

  local _childPids=`ps -o pid --no-headers --ppid ${_curPid}`

  for childPid in ${_childPids}
  do
    kill_child_processes ${childPid} ${_signal} 0
  done

  if [ ${_isTopmost} -eq 0 ]; then
    kill -{$_signal} ${_curPid} 2> /dev/null
  fi
}


kill_process_tree() {
  local _pid=$1
  local _signal=${2:-SIGHUP}

  kill_child_processes ${_pid} ${_signal}

  kill -{$_signal} ${_pid} 2> /dev/null
}
