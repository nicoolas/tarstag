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
cmd=get-job-output
in=$(f_get_filepath "${vault}" "$file_job_desc" "describe-job" "json")

f_check_file_read $in
job_id=$(jq '.JobId' $in | tr -d '"')
#vault=$(jq '.VaultARN' $in | tr -d '"' | sed 's:^.*vaults/::')

jq '.Action' $in | grep -q "InventoryRetrieval" || f_fatal "Wrong Action"

out=$(f_get_filepath "${vault}" "$file_job_output" "inventory" "json")

cat <<EOS

== $(basename $0) ==

Vault: $vault
Job: $job_id

In: $in
Out: $out

EOS

jq '.Completed' $in | grep -q "true" || f_fatal "Error: Process not completed"

set -x
$aws_cmd glacier $cmd --vault-name $vault --account-id - --job-id="$job_id" $out

