#!/usr/bin/env bash

DRY_RUN=1
FOLDER=$1

if [ -z "$FOLDER" ]; then
	echo "Deduplicate files."
	echo "Usage: dedup FOLDER"
	exit
fi

find $FOLDER -type f -exec md5sum "{}" \; > /tmp/original.txt
awk '{print $1}' < /tmp/original.txt | sort > /tmp/hashes.txt
cat /tmp/hashes.txt | uniq > /tmp/hashes_no_dups.txt

# find duped hashes
diff /tmp/hashes.txt /tmp/hashes_no_dups.txt | awk '/^</{print $2}' \
	| sort | uniq > /tmp/dups.txt

# find duped files by hash
while read line; do
	grep "$line" /tmp/original.txt;
done < /tmp/dups.txt | sort > /tmp/dup_files.txt

# find files to remove
hash1=""
while read line; do
	IFS='  ' read -a array <<< "$line"
	hash2="${array[0]}"
	file2="${array[@]:1}"
	# leave the first, remove the rest
	if [ "$hash1" = "$hash2" ]; then echo "$file2"; fi
	hash1="$hash2"
done < /tmp/dup_files.txt | sort > /tmp/to_remove.txt

# remove files
while read line; do
	if [ -e "$line" ]; then
		if [ $DRY_RUN = 1 ]; then
			echo "remove? $line"
		else
			rm "$line"
			echo "removed $line"
		fi
	fi
done < /tmp/to_remove.txt

# check the result
while read line; do
	IFS='  ' read -a array <<< "$line"
	hash2="${array[0]}"
	file2="${array[@]:1}"
	if [ -e "$file2" ]; then
		echo "exists  $hash2 $file2";
	else
		echo "removed $hash2 $file2";
	fi
done < /tmp/dup_files.txt > /tmp/result.txt
