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


. $(dirname $(readlink -f $0))/aws-00_common.sh

f_check_util jq

f_check_not_empty "$1" "Missing arg. (Vault Name)"

vault="$1"
cmd=delete-archive
in=$(f_get_filepath "${vault}" "$file_job_output" "inventory" "json")
out=$(f_get_filepath "${vault}" "$file_actions" "delete-old-archives" "log")

f_check_file_read "$in"

cat <<EOS

Vault: $vault
In: $in
Out: $out

EOS

# List all ArchiveID created more than 90 days ago
jq -c '.ArchiveList | .[] | [if .CreationDate | fromdate < now-7776000 then [.ArchiveId,.CreationDate] else empty end] | .[]' $in | \
	tr -d '[]"' | tr ',' ' ' | \
	{
		while read archive_id creation_date
		do
			echo "Delete old archive: $creation_date $(echo $archive_id | cut -c 1-16)..."
			$aws_cmd glacier $cmd --vault-name $vault --account-id - --archive-id="$archive_id" || f_fatal
		done
	} | tee $out

