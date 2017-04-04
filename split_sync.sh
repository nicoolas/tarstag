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
f_load_config_file "split.conf"

blob_size=256M
blob_encrypt=false

sha256_suffix=sha256sum

f_usage() {
cat <<EOF

Usage:
  $(basename $0) -h
  $(basename $0) [-e] -p prefix -v vault_name <files>

  -h : this help.
  -a : archive name
  -p : destination blob prefix

EOF
    exit $1
}

while getopts a:p:he o
do
    case "$o" in
    a) archive_name=$OPTARG ;;
    p) dest_prefix=$OPTARG ;;
    e) blob_encrypt=true ;;
    h) f_usage 0;;
    *) f_usage 1;;
    esac
done
shift $(($OPTIND-1))

# Check config
[ -n "$split_dest_dir" ] || f_fatal "Config file: missing entry 'split_dest_dir'"
if [ "$blob_encrypt" = true ]
then
	[ -n "$gpg_encrypt_recipient" ] || f_fatal "Config file: missing entry 'gpg_encrypt_recipient'"
fi

archive_dir=$split_dest_dir/$archive_name
blob_dest=$archive_dir/${dest_prefix}.tar

[ -n "$archive_name" ] || f_usage  1
[ -n "$dest_prefix" ] || f_usage  1
[ -n "$1" ] || f_usage  1
[ -d "$split_dest_dir" ] || f_fatal "No directory: '$split_dest_dir'"
[ "$blob_encrypt" = "true" ] && blob_dest=$blob_dest.gpg
cat <<EOS

	Archive name: $archive_name
	Archive files: $(basename $blob_dest)*
	Destination: $archive_dir

EOS

if ! [ -d $archive_dir ]
then
	echo "* Make destination dir: '$archive_dir'"
	mkdir -v $archive_dir || f_fatal "Failed to mkdir '$archive_dir'"
	chmod g+w "$archive_dir"
fi

echo "* TAR all files"
f_split() { split --bytes=${blob_size} --suffix-length=2 - $1; }
f_encrypt() { gpg --encrypt --recipient $gpg_encrypt_recipient ; }
if [ "$blob_encrypt" = "true" ]
then
	time tar c "$@"  | f_split ${blob_dest}. || f_fatal "Tar+Split failed (no encryption)"
else
	time tar c "$@"  | f_encrypt | f_split ${blob_dest}. || f_fatal "Tar+Split failed (with encryption)"
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

