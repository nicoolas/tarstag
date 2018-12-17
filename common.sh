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

VERSION="2.0"

config_dir=~/.config/tarstag/
cmd_treehash="$(dirname $(readlink -f $0))/sha256_treehash/treehash.py"
list_file_in=.full-list-in
list_file_out=.full-list-out

file_ext_glacier=".glacier"

f_load_config_file() {
	[ -s "$config_dir/$1" ] || return 1
	. "$config_dir/$1"
}

. $(dirname $(readlink -f $0))/aws-glacier-helpers/aws-00_common.sh

