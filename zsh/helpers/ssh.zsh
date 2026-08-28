# Start or reuse an SSH agent and load local private keys. Homebrew keychain is
# optional; when it isn't installed, keep the agent environment in ~/.ssh.
function load-our-ssh-keys() {
	emulate -L zsh
	setopt local_options no_unset

	local agent_file=$HOME/.ssh/ssh-agent
	local agent_status agent_keys key fingerprint fingerprint_line
	local -a keys
	typeset -g _ZQS_SSH_KEYS=
	typeset -gi _ZQS_SSH_KEYS_STATUS=2
	typeset -gi _ZQS_SSH_KEYS_VALID=0

	if (( $+commands[keychain] )); then
		eval "$(keychain -q --eval)" || return
		agent_keys=$(ssh-add -l 2>/dev/null)
		agent_status=$?
	else
		mkdir -p -- "$HOME/.ssh" || return
		chmod 700 -- "$HOME/.ssh" 2>/dev/null

		agent_keys=$(ssh-add -l 2>/dev/null)
		agent_status=$?
		if (( agent_status == 2 )) && [[ -r $agent_file ]]; then
			source "$agent_file"
			agent_keys=$(ssh-add -l 2>/dev/null)
			agent_status=$?
		fi

		if (( agent_status == 2 )); then
			eval "$(ssh-agent -s)" >/dev/null || return
			{
				print -r -- "export SSH_AUTH_SOCK=${(q)SSH_AUTH_SOCK}"
				print -r -- "export SSH_AGENT_PID=${(q)SSH_AGENT_PID}"
			} >| "$agent_file"
			chmod 600 -- "$agent_file" 2>/dev/null
			agent_keys=
			agent_status=1
		fi
	fi

	(( agent_status == 2 )) && return 1
	_ZQS_SSH_KEYS=$agent_keys
	_ZQS_SSH_KEYS_STATUS=$agent_status
	(( agent_status == 0 )) && _ZQS_SSH_KEYS_VALID=1

	if (( agent_status == 1 )); then
		if [[ $OSTYPE == darwin* ]]; then
			if (( $+commands[sw_vers] )) && (( ${$(sw_vers -productVersion)%%.*} >= 12 )); then
				ssh-add --apple-load-keychain >/dev/null 2>&1
			else
				ssh-add -qA >/dev/null 2>&1
			fi
			agent_keys=$(ssh-add -l 2>/dev/null)
			agent_status=$?
			_ZQS_SSH_KEYS=$agent_keys
			_ZQS_SSH_KEYS_STATUS=$agent_status
			(( agent_status == 0 )) && _ZQS_SSH_KEYS_VALID=1
		fi

		keys=(~/.ssh/**/*id_(rsa|dsa|ecdsa|ed25519)(N.))
		for key in $keys; do
			fingerprint_line=$(ssh-keygen -l -f "$key" 2>/dev/null) || continue
			fingerprint=${${(z)fingerprint_line}[2]}
			[[ -n $fingerprint ]] || continue
			if [[ $agent_keys != *"$fingerprint"* ]] && ssh-add -q -- "$key"; then
				agent_keys+=$'\n'$fingerprint
				_ZQS_SSH_KEYS_VALID=0
			fi
		done
	fi
}
