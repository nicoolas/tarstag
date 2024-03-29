#!/bin/sh

# Tarstag: Transfer data -> tar -> synthing -> amazon glacier
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

. $(dirname $(readlink -f $0))/common.sh
f_load_config_file "scan.conf"

[ -n "$sync_dir" ] || f_fatal "Config file: missing entry 'sync_dir'"
cmd_upload=$(dirname $0)/upload.sh
sleep_loop=20s
email_subject_prefix="Syncthing/Glacier Upload"

cat <<EOS

$(basename $0) - Version: $VERSION

  sync_dir: $sync_dir
  email_contact: $email_contact

EOS

cd $(dirname $0)
umask 002

f_process_file_list() {
	local dir="$1"
	if [ -r "$dir/$list_file_in" ]
	then
		if [ ! -r "$dir/$list_file_out" ]
		then # IN but no OUT
			echo "Copy '$dir/$list_file_out'"
			cp -v "$dir/$list_file_in" "$dir/$list_file_out" || echo "** Cannot copy $dir/$list_file_out **"
		fi
		for f in "$dir"/*$file_ext_glacier
		do
			f_base=$(basename $f $file_ext_glacier)
			sed -i "/^${f_base}$/s/^/#/" "$dir/$list_file_out"
		done
		if ! grep -qv '^#' "$dir/$list_file_out"
		then
            {
				cat <<-EOS
				$(date) - Syncthing/Glacier Upload Vault "$vault" Success
				Vault: $vault
				Nb blobs: $(wc -l "$dir/$list_file_out")
				EOS
            } | f_send_email "$email_subject_prefix Success."
		fi
	fi
}

f_log_line() {
	echo "$(date +%Y%m%d_%H%M%S) : $1 | $2 --> $3"
}

f_process_files() {
	local _nb=0
	while read file_csum
	do
		file_tarball=$(basename $file_csum .sha256sum)
		dir_tarball=$(dirname $file_csum)
		vault=$(basename $dir_tarball)
		file_log_local=/tmp/$file_tarball.log
		file_log_sync=$dir_tarball/$file_tarball.log
		if [ -r "$dir_tarball/$file_tarball" ]
		then
			if $cmd_upload $vault $dir_tarball/$file_tarball >$file_log_local 2>&1
			then
				rm $file_log_local
				f_log_line "$vault" "$file_tarball" "DONE"
				f_process_file_list "$dir_tarball"
				_nb=1
			else
				f_log_line "$vault" "$file_tarball" "ERROR"
				{
					cat <<-EOS
					$(date) - Syncthing/Glacier upload failed - EXITING
					Vault: $vault
					Blob: $dir_tarball/$file_tarball
					CheckSum: $file_csum

					*** Logs ***

					EOS
					cat $file_log_local
	            } | f_send_email "$email_subject_prefix Failure."
				mv $file_log_local $file_log_sync
				_nb=2
				break
			fi
		fi
	done
	return $_nb
}

while true
do
	if find $sync_dir -name "*.sha256sum" | f_process_files
	then
		sleep $sleep_loop
	fi
done


