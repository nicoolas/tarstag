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
in=$(f_get_filepath "${vault}" "$file_job_init" "retrieval" "json")
out=$(f_get_filepath "${vault}" "$file_job_desc" "describe-job" "json")

f_check_file_read "$in"

job_id=$(jq '.jobId' $in | tr -d '"')
f_check_not_empty "$job_id" "Could not find JobId in file '$in'"

cat <<EOS

== $(basename $0) ==

Vault: $vault
In: $in
Out: $out
Job: $job_id

EOS

set -x
$aws_cmd glacier describe-job --vault-name $vault --account-id - --job-id="$job_id" | tee $out
