#!/bin/bash

SCRIPT_PATH="${BASH_SOURCE[0]}"
if [[ "$SCRIPT_PATH" == */* ]]; then
	SCRIPT_DIR="${SCRIPT_PATH%/*}"
else
	SCRIPT_DIR="."
fi
SCRIPT_DIR="$(cd -- "$SCRIPT_DIR" && pwd)"

NON_INTERACTIVE=0
COMMAND=""
REST_ARGS=()

print_usage () {
	local prog="${0##*/}"
	cat <<EOF
Unicron — $prog

Pure Bash CLI to simplify cron scheduling, backups, file management, and system
updates. Schedule with plain HH:MM; crontab entries are hashed and tagged to
avoid duplicates.

Features
  • Interactive menu and prompts; missing arguments are requested as you go
  • --non-interactive for CI/headless runs (no prompts; fail fast)
  • Human-readable HH:MM scheduling; crontab deduplication (# unicron:hash)
  • Backups/archives via tar with day-of-week filename rotation
  • update/upgrade using auto-detected package manager (apt, pacman, dnf,
    yum, zypper, apk, xbps, emerge, nix, brew, …)
  • file-create, file-update (multi-line), file-delete with safety guardrails
  • Strict quoting and smart privilege handling (sudo when needed)

Installation
  git clone git@github.com:fieldghost/unicron.git
  cd unicron/scripts && chmod +x unicron.sh executecron.sh

Usage
  $prog                              Interactive main menu
  $prog <command> [args ...]         Run a command (prompts if args missing)
  $prog --non-interactive <cmd> [..] No prompts; unsatisfied input fails

Examples
  $prog
  $prog backup /path/to/source /path/to/destination 14:00
  $prog --non-interactive update

Commands
  backup       Schedule a rotating tarball backup
  archive      Schedule a rotating tarball archive
  update       Refresh system package repositories
  upgrade      Upgrade installed packages
  file-create  Create a file and parent directories
  file-update  Overwrite or append (incl. multi-line) to a file
  file-delete  Delete a file (refuses critical system paths)

Architecture
  unicron.sh      Front-end: input, path validation, privileges, prompts
  executecron.sh  Back-end: escaped cron lines, job hashes, crontab edits

License: MIT  •  https://github.com/fieldghost/unicron
EOF
}

parse_args () {
	while [ $# -gt 0 ]; do
		case "$1" in
			"--non-interactive")
				NON_INTERACTIVE=1
				shift
				;;
			"--help"|"-h")
				print_usage
				exit 0
				;;
			*)
				COMMAND="$1"
				shift
				break
				;;
		esac
	done
	REST_ARGS=("$@")
}

prompt_required () {
	local prompt varName value
	prompt="$1"
	varName="$2"

	if [ "$NON_INTERACTIVE" -eq 1 ]; then
		return 1
	fi

	while true; do
		read -e -r -p "$prompt" value
		value="${value/#\~/$HOME}"
		if [ -n "$value" ]; then
			printf -v "$varName" '%s' "$value"
			return 0
		fi
	done
}

prompt_yes_no () {
	local prompt answer
	prompt="$1"

	if [ "$NON_INTERACTIVE" -eq 1 ]; then
		return 1
	fi

	while true; do
		read -r -p "$prompt (y/n): " answer
		case "$answer" in
			[Yy]) return 0 ;;
			[Nn]) return 1 ;;
		esac
	done
}

prompt_time () {
	local prompt varName value hh mm
	prompt="$1"
	varName="$2"

	if [ "$NON_INTERACTIVE" -eq 1 ]; then
		return 1
	fi

	while true; do
		read -r -p "$prompt" value
		if [[ "$value" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
			hh="${BASH_REMATCH[1]}"
			mm="${BASH_REMATCH[2]}"
			if [ "$hh" -ge 0 ] 2>/dev/null && [ "$hh" -le 23 ] && [ "$mm" -ge 0 ] 2>/dev/null && [ "$mm" -le 59 ]; then
				printf -v "$varName" '%s' "$value"
				return 0
			fi
		fi
		echo "Invalid time. Please use HH:MM (24h)."
	done
}

prompt_path_dir () {
	local prompt varName mustExist value
	prompt="$1"
	varName="$2"
	mustExist="$3"

	if [ "$NON_INTERACTIVE" -eq 1 ]; then
		return 1
	fi

	while true; do
		read -e -r -p "$prompt" value
		value="${value/#\~/$HOME}"
		if [ -z "$value" ]; then
			continue
		fi

		if [ "$mustExist" -eq 1 ] && [ ! -d "$value" ]; then
			echo "\"$value\" does not exist."
			continue
		fi

		printf -v "$varName" '%s' "$value"
		return 0
	done
}

ensure_dir_exists () {
	local path
	path="$1"

	if [ -d "$path" ]; then
		return 0
	fi

	echo "\"$path\" does not exist."
	if [ "$NON_INTERACTIVE" -eq 1 ]; then
		return 1
	fi

	if prompt_yes_no "Create it?"; then
		mkdir -p "$path" || return 1
		return 0
	fi

	return 1
}

run_privileged () {
	if [ "${EUID:-$(id -u)}" -eq 0 ]; then
		"$@"
		return $?
	fi

	if [ "$NON_INTERACTIVE" -eq 1 ]; then
		sudo -n "$@"
		return $?
	fi

	sudo "$@"
}

detect_pkg_manager () {
	if command -v pacman >/dev/null 2>&1; then
		echo "pacman"
	elif command -v apt >/dev/null 2>&1; then
		echo "apt"
	elif command -v dnf >/dev/null 2>&1; then
		echo "dnf"
	elif command -v yum >/dev/null 2>&1; then
		echo "yum"
	elif command -v zypper >/dev/null 2>&1; then
		echo "zypper"
	elif command -v apk >/dev/null 2>&1; then
		echo "apk"
	elif command -v xbps-install >/dev/null 2>&1; then
		echo "xbps"
	elif command -v emerge >/dev/null 2>&1; then
		echo "emerge"
	elif command -v nixos-rebuild >/dev/null 2>&1; then
		echo "nixos"
	elif command -v nix >/dev/null 2>&1; then
		echo "nix"
	elif command -v brew >/dev/null 2>&1; then
		echo "brew"
	fi
}

run_update () {
	local mgr
	mgr="$(detect_pkg_manager)"

	case "$mgr" in
		"pacman")
			echo "Detected pacman. Running 'sudo pacman -Sy'"
			run_privileged pacman -Sy
			;;
		"apt")
			echo "Detected apt. Running 'sudo apt update'"
			run_privileged apt update
			;;
		"dnf")
			echo "Detected dnf. Running 'sudo dnf check-update'"
			run_privileged dnf check-update
			;;
		"yum")
			echo "Detected yum. Running 'sudo yum check-update'"
			run_privileged yum check-update
			;;
		"zypper")
			echo "Detected zypper. Running 'sudo zypper refresh'"
			run_privileged zypper refresh
			;;
		"apk")
			echo "Detected apk. Running 'sudo apk update'"
			run_privileged apk update
			;;
		"xbps")
			echo "Detected xbps-install. Running 'sudo xbps-install -S'"
			run_privileged xbps-install -S
			;;
		"emerge")
			echo "Detected emerge. Running 'sudo emerge --sync'"
			run_privileged emerge --sync
			;;
		"nixos")
			if command -v nix-channel >/dev/null 2>&1; then
				echo "Detected nixos-rebuild. Running 'sudo nix-channel --update'"
				run_privileged nix-channel --update
			else
				echo "Detected nixos-rebuild but nix-channel not found; unable to update channels."
				return 1
			fi
			;;
		"nix")
			if command -v nix-channel >/dev/null 2>&1; then
				echo "Detected nix. Running 'sudo nix-channel --update'"
				run_privileged nix-channel --update
			else
				echo "Detected nix but nix-channel not found; unable to perform repository update."
				return 1
			fi
			;;
		"brew")
			echo "Detected brew. Running 'brew update'"
			brew update
			;;
		"")
			echo "No supported package manager found."
			echo "Supported: pacman, apt, dnf, yum, zypper, apk, xbps-install, emerge, nixos-rebuild/nix, brew"
			return 1
			;;
	esac
}

run_upgrade () {
	local mgr
	mgr="$(detect_pkg_manager)"

	case "$mgr" in
		"pacman")
			echo "Detected pacman. Running 'sudo pacman -Syu'"
			run_privileged pacman -Syu
			;;
		"apt")
			echo "Detected apt. Running 'sudo apt upgrade -y && sudo apt full-upgrade -y'"
			run_privileged apt upgrade -y && run_privileged apt full-upgrade -y
			;;
		"dnf")
			echo "Detected dnf. Running 'sudo dnf upgrade --refresh -y'"
			run_privileged dnf upgrade --refresh -y
			;;
		"yum")
			echo "Detected yum. Running 'sudo yum upgrade -y'"
			run_privileged yum upgrade -y
			;;
		"zypper")
			echo "Detected zypper. Running 'sudo zypper update -y'"
			run_privileged zypper update -y
			;;
		"apk")
			echo "Detected apk. Running 'sudo apk upgrade'"
			run_privileged apk upgrade
			;;
		"xbps")
			echo "Detected xbps-install. Running 'sudo xbps-install -Su'"
			run_privileged xbps-install -Su
			;;
		"emerge")
			echo "Detected emerge. Running 'sudo emerge -uDN @world'"
			run_privileged emerge -uDN @world
			;;
		"nixos")
			echo "Detected nixos-rebuild. Running 'sudo nixos-rebuild switch --upgrade'"
			run_privileged nixos-rebuild switch --upgrade
			;;
		"nix")
			echo "Detected nix but not NixOS; no generic system upgrade supported."
			echo "Tip: on NixOS, install/use nixos-rebuild; otherwise upgrade via your environment/flake tooling."
			return 1
			;;
		"brew")
			echo "Detected brew. Running 'brew upgrade'"
			brew upgrade
			;;
		"")
			echo "No supported package manager found."
			echo "Supported: pacman, apt, dnf, yum, zypper, apk, xbps-install, emerge, nixos-rebuild/nix, brew"
			return 1
			;;
	esac
}

task_backup () {
	local source dest time
	source="${1:-}"
	dest="${2:-}"
	time="${3:-}"

	if [ -z "$source" ]; then
		if ! prompt_path_dir "Please specify the /path/you/want/to/backup: " source 1; then
			echo "Missing source directory."
			return 1
		fi
	fi

	if [ -z "$dest" ]; then
		if ! prompt_required "Please specify the /path/you/want/to/backup/to: " dest; then
			echo "Missing destination directory."
			return 1
		fi
	fi

	if [ -z "$time" ]; then
		if ! prompt_time "Please specify the timestamp of the job, e.g. '14:00': " time; then
			echo "Missing time."
			return 1
		fi
	fi

	if [ ! -d "$source" ]; then
		echo "\"$source\" does not exist."
		return 1
	fi

	if ! ensure_dir_exists "$dest"; then
		echo "Aborting."
		return 1
	fi

	echo "Executing backup scheduler"
	"$SCRIPT_DIR/executecron.sh" "backup" "$source" "$dest" "$time"
}

task_archive () {
	local source dest time
	source="${1:-}"
	dest="${2:-}"
	time="${3:-}"

	if [ -z "$source" ]; then
		if ! prompt_path_dir "Please specify the /path/you/want/to/archive: " source 1; then
			echo "Missing source directory."
			return 1
		fi
	fi

	if [ -z "$dest" ]; then
		if ! prompt_required "Please specify the /path/you/want/to/archive/to: " dest; then
			echo "Missing destination directory."
			return 1
		fi
	fi

	if [ -z "$time" ]; then
		if ! prompt_time "Please specify the timestamp of the job, e.g. '14:00': " time; then
			echo "Missing time."
			return 1
		fi
	fi

	if [ ! -d "$source" ]; then
		echo "\"$source\" does not exist."
		return 1
	fi

	if ! ensure_dir_exists "$dest"; then
		echo "Aborting."
		return 1
	fi

	echo "Executing archive scheduler"
	"$SCRIPT_DIR/executecron.sh" "archive" "$source" "$dest" "$time"
}

task_update () {
	echo "Updating your package repositories..."
	run_update
}

task_upgrade () {
	echo "Upgrading your system packages..."
	if [ "$NON_INTERACTIVE" -eq 0 ]; then
		echo "This will upgrade system packages."
		if ! prompt_yes_no "Continue?"; then
			echo "Aborting."
			return 1
		fi
	fi
	run_upgrade
}

task_file_create () {
	local fileName fileType dirPath fullPath

	if [ "$NON_INTERACTIVE" -eq 1 ]; then
		echo "file-create is interactive; run without --non-interactive."
		return 1
	fi

	prompt_required "What is the name of the file? " fileName || return 1
	prompt_required "What is the filetype? (e.g., txt, sh, md) " fileType || return 1
	prompt_required "What directory should it be saved to? " dirPath || return 1

	if ! ensure_dir_exists "$dirPath"; then
		echo "Aborting file creation."
		return 1
	fi

	fullPath="${dirPath%/}/$fileName.$fileType"
	if [ -e "$fullPath" ]; then
		if ! prompt_yes_no "\"$fullPath\" already exists. Overwrite?"; then
			echo "Aborting file creation."
			return 1
		fi
	fi

	if touch "$fullPath"; then
		echo "File created at $fullPath"
	else
		echo "Failed to create file."
		return 1
	fi
}

task_file_update () {
	local updatePath updateOption newContent appendContent

	if [ "$NON_INTERACTIVE" -eq 1 ]; then
		echo "file-update is interactive; run without --non-interactive."
		return 1
	fi

	prompt_required "Enter the full path to the file you want to update: " updatePath || return 1
	if [ ! -f "$updatePath" ]; then
		echo "The file \"$updatePath\" does not exist (or is not a regular file)."
		return 1
	fi

	echo "Choose an update method:"
	echo "1) Overwrite the file"
	echo "2) Append to the file"
	read -r -p "Enter option (1/2): " updateOption

	if [ "$updateOption" = "1" ]; then
		echo "Enter content to overwrite file with. Press CTRL+D when done."
		newContent="$(cat)"
		printf '%s' "$newContent" > "$updatePath"
		echo "File overwritten."
	elif [ "$updateOption" = "2" ]; then
		echo "Enter content to append. Press CTRL+D when done."
		appendContent="$(cat)"
		printf '%s' "$appendContent" >> "$updatePath"
		echo "Content appended."
	else
		echo "Unknown option. Aborting."
		return 1
	fi
}

task_file_delete () {
	local deletePath

	if [ "$NON_INTERACTIVE" -eq 1 ]; then
		echo "file-delete is interactive; run without --non-interactive."
		return 1
	fi

	prompt_required "Enter the full path to the file you want to delete: " deletePath || return 1
	if [ ! -e "$deletePath" ]; then
		echo "The file \"$deletePath\" does not exist."
		return 1
	fi

	case "$deletePath" in
		"/" | "/bin"* | "/usr"* | "/etc"* | "/lib"* | "/opt"* | "/boot"* | "/sys"* | "/proc"* | "/root"* | "/dev"* | "/sbin"* | "/var" | "/var/"* | "$HOME" | "$HOME/" )
			echo "ERROR: Refusing to delete critical directories/files."
			return 1
			;;
		*)
			if [ -d "$deletePath" ]; then
				echo "ERROR: This tool will not delete entire directories."
				return 1
			fi
			;;
	esac

	echo "About to delete: $deletePath"
	if prompt_yes_no "Are you sure you want to delete it?"; then
		if rm "$deletePath"; then
			echo "File deleted."
		else
			echo "Failed to delete file."
			return 1
		fi
	else
		echo "Aborting file deletion."
	fi
}

show_menu () {
	echo
	echo "Unicron - choose an action:"
	echo "1) Backup (schedule)"
	echo "2) Archive (schedule)"
	echo "3) Update packages"
	echo "4) Upgrade packages"
	echo "5) File create"
	echo "6) File update"
	echo "7) File delete"
	echo "8) Exit"
	echo
}

run_menu () {
	local choice
	while true; do
		show_menu
		read -r -p "Enter option (1-8): " choice
		case "$choice" in
			1) task_backup ;;
			2) task_archive ;;
			3) task_update ;;
			4) task_upgrade ;;
			5) task_file_create ;;
			6) task_file_update ;;
			7) task_file_delete ;;
			8) exit 0 ;;
			*) echo "Unknown option." ;;
		esac
	done
}

main () {
	parse_args "$@"

	if [ -z "$COMMAND" ]; then
		if [ "$NON_INTERACTIVE" -eq 1 ]; then
			print_usage
			exit 1
		fi
		run_menu
		exit 0
	fi

	case "$COMMAND" in
		"backup") task_backup "${REST_ARGS[@]}" ;;
		"archive") task_archive "${REST_ARGS[@]}" ;;
		"update") task_update ;;
		"upgrade") task_upgrade ;;
		"file-create") task_file_create ;;
		"file-update") task_file_update ;;
		"file-delete") task_file_delete ;;
		*)
			echo "Unknown command: $COMMAND"
			print_usage
			return 1
			;;
	esac
}

main "$@"