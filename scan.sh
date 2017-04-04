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
[ -n "$email_contact" ] || f_fatal "Config file: missing entry 'email_contact'"
cmd_upload=$(dirname $0)/upload.sh
sleep_loop=30s

cd $(dirname $0)
umask 002

f_process_files() {
	while read file_csum
	do
		file_tarball=$(basename $file_csum .sha256sum)
		dir_tarball=$(dirname $file_csum)
		vault=$(basename $dir_tarball)
		file_log_local=/tmp/$file_tarball.log
		file_log_sync=$dir_tarball/$file_tarball.log
		if [ -r "$dir_tarball/$file_tarball" ]
		then
			echo "$(date +%Y%m%d_%H%M%S) : $vault | $file_tarball"
			if $cmd_upload $vault $dir_tarball/$file_tarball >$file_log_local 2>&1
			then
				mv $file_log_local $file_log_sync
				gzip $file_log_sync
			else
				{ cat <<-EOS
				$(date) - Syncthing/Glacier upload failed - EXITING
				Vault: $vault
				Blob: $dir_tarball/$file_tarball
				CheckSum: $file_csum

				*** Logs ***

				EOS
				cat $file_log_local
				} | mail -s "Syncthing/Glacier Upload failure." $email_contact
				mv $file_log_local $file_log_sync # Move if you can, keep local otherwise
				return 1
			fi
		fi
	done
}

while true
do
	#echo "Loop: $(date +%Y%m%d_%H%M%S)"
	if find $sync_dir -name "*.sha256sum" | f_process_files
	then
		sleep $sleep_loop
	else
		exit 1
	fi
done


