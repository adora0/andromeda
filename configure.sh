#!/usr/bin/env bash
## Build configuration script

## Environment files
sh_env=./.env
make_env=./.env.mk

## Default options
## Can be overriden by arguments
TARGET=i386-elf
PROJECT_NAME=andromeda
BUILDDIR=$(realpath ./build)
SYSROOT=${BUILDDIR}/sysroot
PREFIX=/usr

err() {
    ## $1: message, $2: exit code
    echo "$1" >&2
    exit $2
}

arg_err() {
    ## $OPTARG: argument value
    if [[ "${OPTARG}" = '?' ]]; then
        err $"Incomplete argument." 1
    else
        err $"Invalid argument '${OPTARG}'" 1
    fi
}

get_long() {
    ## Retrieve argument of long option
	## $BASEARG: option name, $OPTARG: option parameter
    ## $1: output variable, $2...: command line arguments
	local -n ref=$1
    if [[ "${BASEARG}" = "${OPTARG}" ]]; then
        # Set value to next argument
        OPTIND=$(($OPTIND+1))
        ref=${!OPTIND}
    else
        # Set value to string after the '=' delimiter
        ref=${BASEARG##*=}
    fi
}

save_env() {
    ## Write variable to environment file
    ## $1: variable name
    ## $EXPAND: optional
    local name=$1
	local -n value=$1
    local contents

    if [[ -n "${EXPAND-}" ]]; then
        value=${value/#\~/$HOME}
    fi

    ## Save shell environment file (quoted values)
    if [[ -f "${sh_env}" ]]; then
        contents="$(cat "${sh_env}" | grep -v "^$(echo ${name} | cut -d'=' -f1).*")"
        if [ -n "${contents}" ]; then
            contents="${contents}"$'\n'
        fi
    fi
    
    echo "${contents}${name}='${value}'" >"${sh_env}"

    ## Save Makefile environment file
    unset contents
    if [[ -f "${make_env}" ]]; then
        contents="$(cat "${make_env}" | grep -v "^$(echo ${name} | cut -d'=' -f1).*")"
        if [[ -n "${contents}" ]]; then
            contents="${contents}"$'\n'
        fi
    fi
    
    echo "${contents}${name}=${value}" >"${make_env}"

}

save_env_path() {
    ## Write variable contining file path to environment file
    ## $1: variable name
    EXPAND=1 save_env $@
}

usage() {
    local basename=$(basename "$0")
    echo $"Usage: ${basename} [OPTION]...

Build configuration script for the Andromeda Operating System.

  -h, --help            show this usage
  --target=STRING       specify the target architecture
  --builddir=DIRECTORY  specify the build directory
  --sysroot=DIRECTORY   specify the directory into which libraries will be installed
  --prefix=DIRECTORY    specify the toolchain prefix
"
}

rm -f "$sh_env" "$make_env"
## Process command line arguments
optstr=':h-:'
while getopts "${optstr}" OPT; do
    case ${OPT} in
        (-)
            ## Process '--' argument prefix
            # Store complete argument for --<name>=<value> syntax
            BASEARG=${OPTARG}
            # Get option name from before the first '=' delimiter
            OPTARG=${BASEARG%%=*}

            case "${OPTARG}" in
                ($"help")   
                    usage
                    exit
                    ;;
                ($"target")
                    get_long TARGET $@
                    ;;
                ($"builddir")
                    get_long BUILDDIR $@
                    ;; 
                ($"sysroot")
                    get_long SYSROOT $@
                    ;;
                ($"prefix")
                    get_long PREFIX $@
                    ;;
                (*)
                    arg_err
                    ;;
            esac
            ;;
        (h)
            usage
            exit
            ;;
        (*)
            arg_err
            ;;
    esac
done

## Get architecture string from target
if echo "${TARGET}" | grep -Eq 'i[[:digit:]]86'; then
    ARCH=i386
else
    ARCH=$(echo "${TARGET}" | grep -Eo '^[[:alnum:]_]*')
fi

## Save environment variables
unset EXPAND
save_env TARGET
save_env ARCH
save_env_path BUILDDIR
save_env_path SYSROOT
save_env_path PREFIX
save_env CFLAGS
