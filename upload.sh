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
f_load_config_file "upload.conf"


[ -n "$cmd_treehash" ] || f_fatal "bug: missing treehash computation command"
[ -x "$cmd_treehash" ] || f_fatal "bug: treehash computation command not found '$cmd_treehash'"
[ -n "$AWS_ACCOUNT_ID" ] || f_fatal "Config file: missing entry 'AWS_ACCOUNT_ID'"

#dry_run=echo 

vault="$1"
input_file="$2"
input_file_dir=$(dirname "$input_file")
blob="$(basename $input_file)"
treehash="$blob.sha256treehash"
sha256sum="$blob.sha256sum"
output_log="$blob$file_ext_glacier"
output_vaults="$blob.vaults"

umask 002
echo

f_log() {
	echo
	echo "$(date +%Y-%m-%d_%H:%M:%S): $*"
}
f_fatal() {
	echo "ERROR: $1"
	exit 1
}
which jq >/dev/null || f_fatal "Missing tool 'jq'"

[ -n "$vault" ] || f_fatal "Missing argument"
[ -n "$input_file" ] || f_fatal "Missing argument"
[ -r "$input_file" ] || f_fatal "Cannot read file '$input_file'"

[ -x "$input_file_dir" ] || f_fatal "Dir '$input_file_dir' is not executable - $(ls -ld $input_file_dir)"
[ -w "$input_file_dir" ] || f_fatal "Dir '$input_file_dir' is not writable - $(ls -dl $input_file_dir)"
cd "$input_file_dir" || f_fatal "Could not chdir to $input_file_dir"

[ -r "$blob" ] || f_fatal "Cannot read file '$blob'"
[ -r "$sha256sum" ] || f_fatal "Cannot read file '$sha256sum'"

f_log "* Verify SHA256 checksum"
sha256sum -c "$sha256sum" || f_fatal "SHA256 Checksum failed"

f_log "* Generate SHA256 Tree Hash"
$cmd_treehash $(readlink -f $blob) || f_fatal "Tree Hash failed (for file '$blob')"
[ -r "$treehash" ] || f_fatal "Cannot read file '$treehash'"

f_check_vault() {
	f_log "* List available vaults ($output_vaults)"
	aws glacier list-vaults --account-id $AWS_ACCOUNT_ID > $output_vaults || f_fatal "Failed to list current vaults"
	[ -r "$output_vaults" ] || f_fatal "Cannot read file '$output_vaults'"
	
	jq '."VaultList"|.[]|."VaultName"' $output_vaults | grep -q "\"$vault\""
}

if f_check_vault
then
	f_log "-> Vault '$vault' already exists"
else
	f_log "-> Vault '$vault' does not exist: creating it"
	aws glacier create-vault --account-id $AWS_ACCOUNT_ID --vault-name "$vault" || f_fatal "Failed to create vault '$vault'"
	f_check_vault || f_fatal "Vault '$vault' was not created properly"
fi

f_log "* Upload archive '$blob'"
timeout_s=600
$dry_run timeout $timeout_s \
	aws glacier upload-archive \
    --vault-name $vault \
    --account-id $AWS_ACCOUNT_ID \
    --archive-description "Backup: $blob" \
    --body $blob \
    --checksum $(cat $treehash) >$output_log 2>&1
aws_ret=$?
echo '<<< aws glacier upload-archive logs'
[ -r "$output_log" ] && cat "$output_log"
echo '>>>'

[ $aws_ret -eq 0 ] || f_fatal "'aws glacier upload-archive' failed. Return code: $aws_ret"

f_log "Delete input files"
rm -fv "$blob" "$sha256sum" "$treehash" "$output_vaults"

f_log "* Done"

echo
