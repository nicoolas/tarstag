
f_fatal() {
	echo "$@"
	exit 1
}

f_check_util() {
	which $1 || f_fatal "Utility '$1' missing, aborting"
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
#
f_get_filepath() {
	[ -d "$file_dir" ] || mkdir -p "$file_dir"
	[ -d "$file_dir" ] || f_fatal "Cannot create directory '$file_dir'"
	echo "$file_dir/$1$2$3$4"
}

file_dir=$(dirname $(readlink -f $0))/output
file_job_init=".10.job-init"
file_job_desc=".20.job-desc"
file_job_output=".30.job-output"
