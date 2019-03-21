
f_fatal() {
	echo "$@"
	exit 1
}

f_check_util() {
	which $1 >/dev/null 2>&1 || f_fatal "Utility '$1' missing, aborting"
}

f_check_file_read() {
	[ -r "$1" ] || f_fatal "Cannot read file '$1'"
}

f_check_not_empty() {
	[ -z "$1" ] && f_fatal "Error: $2"
}

# Arg 1: Vault name
# Arg 2: file prefix
# Arg 3: file suffix
# Arg 4: file extension

f_get_filepath() {
	[ -d "$file_dir" ] || mkdir -p "$file_dir"
	[ -d "$file_dir" ] || f_fatal "Cannot create directory '$file_dir'"
	[ "$4" = "log" ] && tag="_$(date +%Y%m%d_%H%M%S)"
	echo "$file_dir/${1}_${2}_$3${tag}.$4"
}

bin_dir=$(dirname $(readlink -f $0))/
file_dir=$(pwd)/aws-glacier-output
file_info="00-info"
file_job_init="10-job-init"
file_job_desc="20-job-desc"
file_job_output="30-job-output"
file_actions="40-actions"

