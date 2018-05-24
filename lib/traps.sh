#!/bin/bash

current_trap_cmd() {
  local _trap="$1"

  extract_trap_cmd() { printf '%s\n' "$3"; }

  eval "extract_trap_cmd $(trap -p "${_trap}")"
}

prefix_trap() {
  local _function=$1
  local _trap=$2 

  trap -- "$( printf '%s\n%s' "${_function}" "$( current_trap_cmd ${_trap})" )" "${_trap}"
}

suffix_trap() {
  local _function=$1
  local _trap=$2 

  trap -- "$( printf '%s\n%s' "$( current_trap_cmd ${_trap})" "${_function}" )" "${_trap}"
}
