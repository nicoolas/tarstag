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

# *DOC*
# Initiate Job (POST jobs)
# This operation initiates the following types of Amazon S3 Glacier (Glacier) jobs:
#  select: Perform a select query on an archive
#  archive-retrieval: Retrieve an archive
#  inventory-retrieval: Inventory a vault


 

. $(dirname $(readlink -f $0))/aws-00_common.sh

f_check_not_empty "$1" "Missing arg. (Vault Name)"
f_check_not_empty "$2" "Missing arg. (Job Type)"

vault="$1"
job_type="$2"
cmd=initiate-job

out=$(f_get_filepath "${vault}" "$file_job_init" "$job_type" "json")

cat <<EOS

== $(basename $0) ==

Vault: $vault
Type: $job_type
out: $out

EOS

aws glacier $cmd --vault-name $vault --account-id -  --job-parameters "{\"Type\": \"$job_type\"}" | tee $out
