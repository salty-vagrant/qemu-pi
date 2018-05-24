#!/bin/bash
#

keyfile_check() {
	local _pass=$1

	local _keyfile=true

	if [[ ! -f "${_pass}" ]]; then
		_isKeyfile=false
		local _sshpassInstalled=$(dpkg-query -W -f='${Status}' sshpass 2>/dev/null | grep -c "ok installed")
		if [[ ${_sshpassInstalled} != 1 ]]; then
			if [[ ${AUTOINSTALL} == 1 ]]; then
				sudo apt install -y sshpass
			else
				echo "qemu_ssh() required sshpass when using password rather than key file" >2
				return 1
			fi
		fi
	fi

	echo ${_keyfile}
}

ssh_qemu() {
	local _target=$1
	local _username=$2
	local _pass=$3
	local _cmd=${4:-exit}

	local _iskeyfile=$(keyfile_check);
	local _sshR=1

	# Important: The use of StrictHostKeyChecking=no is only acceptable here because we know we're connecting to a local VM under our control
	local _conn="-o StrictHostKeyChecking=no ${_username}@${_target}"
	
	echo "Attempting to ssh ${_conn} \"${_cmd}\""

	if [[ ${_isKeyfile} == true ]]; then
		ssh -i ${_pass} ${_conn} "${_cmd}"
		_sshR=$?
	else
		sshpass -p ${_pass} ssh ${_conn} "${_cmd}"
		_sshR=$?
		echo "ssh returned ${_sshR}"
	fi

	return ${_sshR}
}

scp_qemu() {
	local _target=$1
	local _username=$2
	local _pass=$3
	local _source=$4
	local _destination=$5

	local _iskeyfile=$(keyfile_check);
	local _scpR=1
	local _flags='-o StrictHostKeyChecking=no'

	# Important: The use of StrictHostKeyChecking=no is only acceptable here because we know we're connecting to a local VM under our control
	local _conn="${_username}@${_target}"

	if [ -d "${_source}" ]; then
		_flags="${_flags} -r"
	fi
	
	echo "Attempting to scp ${_flags} ${_conn} \"${_source}\" \"${_destination}\""

	if [[ ${_isKeyfile} == true ]]; then
		scp ${_flags} -i ${_pass} "${_source}" "${_conn}:${_destination}"
		_scpR=$?
	else
		sshpass -p ${_pass} -- scp ${_flags} "${_source}" "${_conn}:${_destination}"
		_scpR=$?
	fi

	return ${_scpR}
}

wait_on_ssh() {
	local _target=$1
	local _username=$2
	local _pass=$3
	local _timeout=${4:-10}
	local _maxAttempts=${5:-10}

	local _attempt=1
	local _result=1
	while (( ${_attempt} <= ${_maxAttempts} )); do
		ssh_qemu "${_target}" "${_username}" "${_pass}" "exit"
		case $? in
			0) _result=0; 
			   break;;
			*) echo "${_attempt} of ${_maxAttempts} to ${_target}: Still not ready. (waiting ${_timeout} second to retry)"
			    ;;
		esac
		sleep ${_timeout}
		(( _attempt++ ))
	done

	return ${_result}
}
