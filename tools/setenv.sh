#!/bin/sh
for i in "$@"; do
	if test -f .env.local; then
		contents="$(cat .env.local | grep -v "^$(echo $i | cut -d'=' -f1).*")"
		if test -n "$contents"; then
			contents="$contents"$'\n'
		fi
	fi
	echo "${contents}$i" >.env.local
done