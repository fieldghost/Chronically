#!/bin/bash

COMMAND="${1:-}"

if [ -z "$COMMAND" ]; then
	exit 1
fi

SOURCE_DIR="${2:-}"
DESTINATION_DIR="${3:-}"
TIME_SPECIFICATION="${4:-}"

if [ -z "$SOURCE_DIR" ] || [ -z "$DESTINATION_DIR" ] || [ -z "$TIME_SPECIFICATION" ]; then
	echo "Missing arguments. Expected: <command> /source/path /destination/path time"
	exit 1
fi

HOUR="${TIME_SPECIFICATION%:*}"
MINUTE="${TIME_SPECIFICATION#*:}"

hash_string () {
	if command -v sha1sum >/dev/null 2>&1; then
		sha1sum | awk '{print $1}'
	elif command -v shasum >/dev/null 2>&1; then
		shasum | awk '{print $1}'
	elif command -v md5sum >/dev/null 2>&1; then
		md5sum | awk '{print $1}'
	elif command -v md5 >/dev/null 2>&1; then
		md5 | awk '{print $NF}'
	else
		cat
	fi
}

install_cron_job () {
	local cronJob jobId tempCron
	cronJob="$1"
	jobId="$2"
	tempCron="$(mktemp)"

	crontab -l 2>/dev/null > "$tempCron" || true

	grep -vF "# autocron:${jobId}" "$tempCron" | grep -vF "$cronJob" > "${tempCron}.new" || true
	mv "${tempCron}.new" "$tempCron"

	echo "$cronJob" >> "$tempCron"
	crontab "$tempCron"
	local status=$?
	rm "$tempCron"
	return "$status"
}

shell_single_quote () {
	printf "'%s'" "$(printf "%s" "$1" | sed "s/'/'\"'\"'/g")"
}

schedule_tar_job () {
	local mode cronCommand jobId cronJob
	mode="$1"

	local destPrefixQuoted sourceDirQuoted
	destPrefixQuoted="$(shell_single_quote "$DESTINATION_DIR/${mode}_")"
	sourceDirQuoted="$(shell_single_quote "$SOURCE_DIR")"
	cronCommand="tar czf ${destPrefixQuoted}"'$(date +\%A)'"'.tgz' ${sourceDirQuoted} >/dev/null 2>&1"
	jobId="$(printf '%s' "${mode}|$SOURCE_DIR|$DESTINATION_DIR|$MINUTE|$HOUR" | hash_string)"
	cronJob="$MINUTE $HOUR * * * $cronCommand # autocron:${jobId}"

	install_cron_job "$cronJob" "$jobId"
}

case "$COMMAND" in
	"backup"|"archive")
		if schedule_tar_job "$COMMAND"; then
			exit 0
		else
			exit 1
		fi
		;;
esac

echo "Unknown command: $COMMAND"
exit 1
