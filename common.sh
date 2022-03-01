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

VERSION="2.2"

config_dir=~/.config/tarstag/
cmd_treehash="$(dirname $(readlink -f $0))/sha256_treehash/treehash.py"
list_file_in=.full-list-in
list_file_out=.full-list-out
list_file_excluded=.full-list-excluded

file_ext_glacier=".glacier"

f_log() {
	echo "$(date +%Y-%m-%d_%H:%M:%S): $*"
}

f_fatal() {
	f_log "ERROR: $*"
	exit 1
}

f_load_config_file() {
	[ -s "$config_dir/$1" ] || return 1
	. "$config_dir/$1"
}

f_print_seconds() {
    local cap_sec=$1
    if expr match "$cap_sec" '[0-9][0-9]*' >/dev/null
    then
        time_t=$cap_sec
        time_s=$((time_t%60))
        time_t=$(((cap_sec-time_s)/60))
        time_m=$((time_t%60))
        time_h=$(((time_t-time_m)/60))
        echo "${time_h}h ${time_m}m ${time_s}s"
    else
        echo "n/a"
    fi
}

f_send_email() {
	[ -n "$email_contact" ] || f_fatal "Config file: missing entry 'email_contact'"
	[ -n "$email_sender" ] && _sender="-r $email_sender"
	echo "Send email: [$1] '$_sender' -> '$email_contact'"
	mail -s "$1" $_sender $email_contact
}

. $(dirname $(readlink -f $0))/aws-glacier-helpers/aws-00_common.sh

