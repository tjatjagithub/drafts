#! /usr/bin/env bash

# drafts.sh, version 0.1, 2023-08-19

FILE="$@"

set -e
set -u
set -o pipefail

if [ ! -s "${FILE}" ] ; then
	echo "Usage: $0 <DRAFTS_JSON_EXPORT>" >&2

	exit 1
fi

####

ERROR=
if ! type mlr >/dev/null ; then
	echo "ERROR: Install \"mlr\"" >&2

	echo "#sudo port install miller" >&2
	echo "#sudo brew install miller" >&2

	ERROR=true
fi

if ! type jq >/dev/null ; then
	echo "ERROR: Install \"jq\"" >&2

	echo "#sudo port install jq" >&2
	echo "#sudo brew install jq" >&2

	ERROR=true
fi

if [ $ERROR ] ; then
	exit 1
fi

####

split_drafts_json_export() {
	mlr --json --from "$@" split -g uuid >/dev/null

	return $?
}

handle_split() {
	sed '1d;$d' "$@" > .tmp

	#### get relevant data

	UUID=$( jq --raw-output '.uuid?' < ".tmp" )
	TAGS=$( jq --raw-output '.tags?' < ".tmp" | sed '1d;$d' )

	CREATED=$( jq --raw-output '.created_at?' < ".tmp" )
	MODIFIED=$( jq --raw-output '.modified_at?' < ".tmp" )
	ACCESSED=$( jq --raw-output '.accessed_at?' < ".tmp" )

	# determine file type, currently just .txt or .md

	GRAMMAR=$( jq --raw-output '.languageGrammar?' < ".tmp" )
	END=".txt"

	case ${GRAMMAR} in
		Markdown) END=".md" ;;
	esac

	#### output draft content

	jq --unbuffered --raw-output '.content?' < ".tmp" | sed '1s/^"//g;$s/\"$//g' > DRAFTS/"${UUID}_${CREATED}${END}"

	#### Create a speaking file name as hard link

	create_named_links DRAFTS/"${UUID}_${CREATED}${END}"

	rm -f .tmp

	#### set the timestamps
	
	touch -m -d "${MODIFIED}" DRAFTS/"${UUID}_${CREATED}"*
	touch -a -d "${ACCESSED}" DRAFTS/"${UUID}_${CREATED}"*
	touch -d "${CREATED}" DRAFTS/"${UUID}_${CREATED}"*

	return 0
}

create_named_links() {
	local file="$@"

	#### generate name from first line

	NAME=$( sed '/^$/d;s/^\.$//g' "${file}" | head -1 | tr -cd '[:print:]' | tr '/:;@' '_' | tr -cd '[:alnum:][:blank:]_' | tr '[:blank:]' '_' | sed 's/^-*//g;s/^_*//g;s/^ *//g' | sed 's/__*/_/g' | cut -c -39 ) || true

	#### hard-links with above name, add numbers if required

	APPEND=
	while ! ln DRAFTS/"${UUID}_${CREATED}${END}" LINKS/"${NAME}${APPEND}${END}" 2>/dev/null ; do
		if [ ! "${APPEND}" ] ; then
			i=1
			APPEND="_${i}"
		else
			i=$(( i + 1 ))
			APPEND="_${i}"
		fi
	done

	#### created file and hard link for flagged drafts

	FLAGGED=$( jq --raw-output '.flagged?' < ".tmp" )
	case ${FLAGGED} in
		true)
			touch DRAFTS/"${UUID}_${CREATED}.flagged"
			ln DRAFTS/"${UUID}_${CREATED}.flagged" LINKS/"${NAME}${APPEND}.flagged"
			;;
	esac

	#### create file for tags from the draft

	if [ "${TAGS}" ] ; then
		printf "%s\n" ${TAGS} > DRAFTS/"${UUID}_${CREATED}.tags"
		ln DRAFTS/"${UUID}_${CREATED}.tags" LINKS/"${NAME}${APPEND}.tags"
	fi

	return 0
}

metadata_flag_tags() {
	####  create new files

	for f in LINKS/*.txt LINKS/*.md ; do
		cp -p "${f}" DOCS/
	done

	####

	for f in LINKS/*.txt LINKS/*.md ; do
		N=$( sed 's/\.txt$//g;s/\.md$//g' <<< "${f}" )
		BN=$( basename "${N}" )

		FLAGGED=
		if [ -f "${N}.flagged" ] ; then
			FLAGGED=true
		fi

		TAGGED=
		if [ -s "${N}.tags" ] ; then
			TAGGED=true
		fi

		if [ $FLAGGED ] || [ $TAGGED ] ; then
			if [[ "${f}" =~ \.txt$ ]] ; then
				{ echo '---' ; [ $FLAGGED ] && echo "#flagged" ; [ $TAGGED ] && sed 's/\"//g;s/,$//g;s/^/#/g' "${N}.tags" ; echo '---' ; echo ; cat "${N}.txt" ; } > DOCS/"${BN}".txt
			elif [[ "${f}" =~ \.md$ ]] ; then
				{ echo '---' ; [ $FLAGGED ] && echo "#flagged" ; [ $TAGGED ] && sed 's/\"//g;s/,$//g;s/^/#/g' "${N}.tags" ; echo '---' ; echo ; cat "${N}.md" ; } > DOCS/"${BN}".md
			else
				echo "WARN: Unsupported file type: ${f}" >&2
			fi
		fi
	done

	for f in DOCS/* ; do
		BN=$( basename "${f}" )
		touch -r "LINKS/${BN}" DOCS/"${BN}"
	done

	return 0
}

sort_files() {
	for f in DOCS/* ; do
		Y=$( stat -f "%SB" "${f}" | awk '{print $NF}' )
		if [ ! -d "DOCS/${Y}" ] ; then
			mkdir DOCS/${Y}
		fi
		mv "${f}" DOCS/${Y}/
	done

	return 0
}

#### MAIN

for DIR in DRAFTS LINKS DOCS ; do
	if [ -d "${DIR}" ] ; then
		echo "ERROR: ${DIR} already exists" >&2

		exit 1
	fi

	mkdir "${DIR}"
done

split_drafts_json_export "${FILE}"

for file in split_* ; do
	handle_split "${file}"

	rm "${file}"
done

#### add flag and tags as meta data in new files

metadata_flag_tags

sort_files

exit 0
