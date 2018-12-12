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

# *DOC*
# Retrieving an archive or a vault inventory are asynchronous operations
# that require you to initiate a job.
# Retrieval is a two-step process:
#  - Initiate a retrieval job by using the Initiate Job (POST jobs) operation. 
#  - After the job completes, download the bytes using the Get Job Output (GET output) operation.

. $(dirname $(readlink -f $0))/aws-00_common.sh

f_check_not_empty "$1" "Missing arg. (Vault Name)"

$bin_dir/aws-10_initiate-job.sh "$1" "archive-retrieval"
