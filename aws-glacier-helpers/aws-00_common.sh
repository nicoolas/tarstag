
f_fatal() {
	echo "$@"
	exit 1
}

f_check_file_read() {
	[ -r "$1" ] || f_fatal "Cannot read file '$1'"
}

f_check_not_empty() {
	[ -z "$1" ] && f_fatal "Error: $2"
}

# Arg 1: Vault name
# Arg 2: file suffix
f_get_filepath() {
	[ -d "$file_dir" ] || mkdir -p "$file_dir"
	[ -d "$file_dir" ] || f_fatal "Cannot create directory '$file_dir'"
	echo "$file_dir/$1$2"
}

file_dir=$(dirname $(readlink -f $0))/output
file_job_inventory=".10.job-inventory.json"
file_job_description=".20.job-description.json"
file_job_output=".30.job-output"
