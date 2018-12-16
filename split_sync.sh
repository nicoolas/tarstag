#!/bin/sh -e

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
f_load_config_file "split.conf"

blob_size=256M
blob_encrypt=""
sha256_suffix=sha256sum

f_usage() {
cat <<EOF

Usage:
  $(basename $0) -h
  $(basename $0) [-e recipient] [-b] -a archive_prefix -d archive_dir [-t [-d <temp_dir]] <files>

  -h : this help.
  -a : Archive name prefix
  -v : Vault Name (and destination directory name)
  -t : Use temporary directory (from -d option or config file)
  -d : Temporary directory path
  -e : Encrypt for given recipient
  -b : bzip2 compression
  -s : blob size (default: $blob_size)

EOF
    exit $1
}

compress_bz=false
use_temp_dir=false

while getopts s:a:td:v:he:b o
do
    case "$o" in
    b) compress_bz=true ;;
    v) vault_name=$OPTARG ;;
    a) archive_prefix=$OPTARG ;;
    d) temp_path=$OPTARG ;;
    t) use_temp_dir=true ;;
    e) blob_encrypt=$OPTARG ;;
    s) blob_size=$OPTARG ;;
    h) f_usage 0 ;;
    *) f_usage 1 ;;
    esac
done
shift $(($OPTIND-1))

# Check config
[ -n "$split_dest_dir" ] || f_fatal "Config file: missing entry 'split_dest_dir'"
[ -n "$temp_path" -a "$use_temp_dir" != "true" ] && f_fatal "Temp dir configfured, but not activated (use -t option)"
archive_dir=$split_dest_dir/$vault_name

if [ "$use_temp_dir" = "true" ]
then
	if [ -z "$temp_path" ]
	then
		echo "Using temporary path from option: '$temp_path'"
	else
		[ -n "$split_temp_dir" ] || f_fatal "Temporary directory is missing (use config file 'split_temp_dir', or -d option)"
		temp_path="$split_temp_dir"
		echo "Using temporary path from config file: '$temp_path'"
	fi
fi
		

if [ -n "$temp_path" ]; then
	[ -d "$temp_path" ] || f_fatal  "Temp. dir is not a directory: '$temp_path'"
	temp_dir=$temp_path/$vault_name
else
	temp_dir="$archive_dir"
fi
[ -n "$archive_dir" ] || f_usage  1
[ -n "$archive_prefix" ] || f_usage  1
[ -n "$1" ] || f_usage  1

blob_dest=$temp_dir/${archive_prefix}.tar
[ "$compress_bz" = "true" ] && blob_dest=$blob_dest.bz
# Fail if GPG recipient is not valid
if [ -n "$blob_encrypt" ]
then
	blob_dest=$blob_dest.gpg
	gpg --list-secret-keys "$blob_encrypt" >/dev/null || f_fatal "Unknown gpg recipient '$blob_encrypt'"
fi

[ -d "$split_dest_dir" ] || f_fatal "No directory: '$split_dest_dir'"
cat <<EOS

	Archive name: $archive_prefix
	Archive files: $(basename $blob_dest)*
	Destination: $archive_dir
	Temp. dir: $temp_dir

EOS

for d in "$archive_dir" "$temp_dir"
do
	if [ "$d" != "" ]
	then
		if [ ! -d "$d" ]
		then
			echo "* Make dir: '$d'"
			mkdir -v -p $d || f_fatal "Failed to mkdir '$d'"
			chmod g+w "$d"
		fi
	fi
done

echo "* TAR all files"
f_split() { split --bytes=${blob_size} --suffix-length=2 - $1; }
f_encrypt() { gpg --encrypt --recipient $blob_encrypt ; }
[ "$compress_bz" = "true" ] && tar_opt=j

if [ -z "$blob_encrypt" ]
then
	time tar c$tar_opt "$@"  | f_split ${blob_dest}. || f_fatal "Tar+Split failed (no encryption)"
else
	time tar c$tar_opt "$@"  | f_encrypt | f_split ${blob_dest}. || f_fatal "Tar+Split failed (with encryption)"
fi

echo "* Compute sha256 checksums"
for f in ${blob_dest}*
do
	echo "$f" | grep "$sha256_suffix$" && continue
	echo "File: $f"
	f_dir=$(dirname "$f")
	f_file=$(basename "$f")
	( cd $f_dir ; sha256sum --binary "$f_file" > "$f_file.$sha256_suffix" )
	chmod g+w "$f" "$f.$sha256_suffix"
done

if [ "$archive_dir" != "$temp_dir" ]
then
	echo "* Move files to final destination"
	mv ${blob_dest}*.${sha256_suffix}* "$archive_dir/"
	mv ${blob_dest}* "$archive_dir/"
fi

