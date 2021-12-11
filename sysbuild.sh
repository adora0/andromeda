#!/usr/bin/env bash
## cosmos build environment script

# globals
basedir=$(pwd)
toolsdir="tools"
noticefile="NOTICE"
versionfile="VERSION"
envfile=".env"
binariesfile="${toolsdir}/BINARIES"
gitignore=".gitignore"

# defaults
remote_server="ftp://ftp.gnu.org"
remote_keyring="${remote_server}/gnu/gnu-keyring.gpg"
remote_binutils="${remote_server}/gnu/binutils"
remote_gcc="${remote_server}/gnu/gcc"
version_binutils="2.37"
version_gcc="11.2.0"
archive_ext="tar.gz"
archlist=(i386-elf)
target_32="i386-elf"
target_x86_64="x86_64-elf"

default_builddir="build"
default_prefix="local"
default_target="${target_32}"
default_execname="cosmos"
logcolor=$'\e[2m'
logcolor_notice=$'\e[1;32m'
logcolor_error=$'\e[1;91m'
logcolor_clear=$'\e[0m'
boot_basename="boot.bin"
kernel_basename="kernel.bin"
cflags=
asflags=
cflags_debug=-g
asflags_debug=-g

qemu_exec_32="qemu-system-i386"
qemu_exec_64="qemu-system-x86_64"
gdb_exec="gdb"
gdb_socket=".gdb.socket"

# unset configured variables
unset boot_bin
unset kernel_bin
unset qemu_args
unset gdb_args
unset NOTICE
unset RECURSE

# unset options
unset BUILDDIR
unset PREFIX
unset TARGET
unset QEMU
unset GDB
unset SILENT
unset BUILD_DEBUG
unset RUN_DEBUG
unset NORMALIZE
unset IGNORE_SIG
unset IGNORE_INSTALLED

err() {
    # $1: message, $2: exit code
    echo "$1" >&2
    exit $(($2))
}

arg_err() {
    # $OPTARG: argument value
    if [[ "${OPTARG}" = '?' ]]; then
        err $"Incomplete argument." 2
    else
        err $"Invalid argument '${OPTARG}'" 2
    fi
}

command_err() {
    # $OPT: command value
    if [[ "${OPT}" = '?' ]]; then
        err $"Incomplete command." 2
    else
        err $"Invalid command '${OPT}'" 2
    fi
}

command_log() {
    # $1...: message
    # (optional) $NOTICE
    if [[ -z "${SILENT-}" ]]; then
        local color
        if [[ -z "${NORMALIZE-}" ]]; then
            if [[ -n "${ERROR-}" ]]; then
                color=${logcolor_error}
            elif [[ -n "${NOTICE-}" ]]; then
                color=${logcolor_notice}
            else
                color=${logcolor}
            fi
        fi
        echo -e "${color}${@}${logcolor_clear}" >&2
    fi
}; command_log_notice() { NOTICE=1 command_log "$@"; }

log_err() {
    # $1: message, $2: exit code
    ERROR=1 command_log "$1"
    exit $(($2))
}

is_declared() {
    # $1: variable name, $2: array name
    ## expansion of array with name
    eval arr=(\${$2[@]})
    for var in ${arr[@]}; do
        if [[ "${var}" = "$1" ]]; then
            return 0
        fi
    done
    return 1
}

get_long() {
	# $BASEARG, $OPTARG, $1: output, $2...: <args>
    ## retrieve argument of long option
	local -n ref="$1"
    if [[ "${BASEARG}" = "${OPTARG}" ]]; then
        OPTIND=$(($OPTIND+1))
        ref="${!OPTIND}"
    else
        ref="${BASEARG#*=}"
    fi
}

fetch_keyring() {
    # $1: url
    ## retrieve remote keyring
    ## prints output path to stdout
    local remote="$1"
    local out="${BUILDDIR}/$(basename "${remote}")"
    if [[ -n "${SILENT-}" ]]; then
        curl_args='--silent'
    else
        curl_args='--progress-bar'
    fi
    command_log $"Fetching '${remote}'..."
    curl ${curl_args} -o "${out}" "${remote}"
    [[ $? -eq 0 ]] || log_err $"Unable to retrive keyring." 1
    echo "${out}"
}

verify_version() {
    # $1: path to archive, $2: path to signature, $3: path to keyring
    local file="$1"
    local sig="$2"
    local keyring="$3"
    gpg --keyring "${keyring}" --verify "${sig}" "${file}" &>/dev/null
}

fetch_version() (
    # $1: url
    # (optional) $2: extension, $KEYRING: path, $USE_LATEST, $RECURSE
    ## retrieve remote archive (uses subshell)
    ## prints output path to stdout
    local remote="$1"
    local ext
    local curl_args
    local contents
    local latest
    local remote
    local remote_sig
    local out_sig
    if [[ -n "${SILENT-}" ]]; then
        curl_args='--silent'
    else
        curl_args='--progress-bar'
    fi
    verify_fetch() {
        command_log $"Fetching '${remote_sig}'..."
        curl ${curl_args} -o "${out_sig}" "${remote_sig}"
        if verify_version "${out}" "${out_sig}" "${KEYRING}"; then
            command_log $"Verification successful for file '${out}'."
            echo "${out}"
            return 0
        else
            command_log $"Verification failed for file '${out}'."
            return 1
        fi
    }

    if [[ -n "${USE_LATEST-}" ]]; then
        ext="$2"
        if [[ -n "${RECURSE-}" ]]; then
            # fetch root directory contents
            command_log $"Fetching contents of '${remote}'..."
            contents=$(curl ${curl_args} "${remote}")
            [[ $? -eq 0 ]] || log_err $"Unable to retrive remote directory contents." 1

            # scan for latest version in directory entries only
            ## awk 9th field (name) of lines starting with 'd' (directory)
            latest=$(awk '/^d.*/ {print $9}' <<< "${contents}" |
                sort -V |
                tail -n 1)
            [[ -n "${latest}" ]] || log_err $"Unable to determine subdirectory of latest version." 1

            # fetch directory contents
            remote="${remote}${latest}/"
            command_log $"Fetching contents of '${remote}'..."
            contents=$(curl ${curl_args} --list-only "${remote}")
            [[ $? -eq 0 ]] || log_err $"Unable to retrive remote directory contents." 1
        else
            # fetch directory contents
            command_log $"Fetching contents of '${remote}'..."
            contents=$(curl ${curl_args} --list-only "${remote}")
            [[ $? -eq 0 ]] || log_err $"Unable to retrive remote directory contents." 1
        fi
        # scan for latest entry
        latest=$(grep ".*${ext}$" <<< "${contents}" |
            sort -V |
            tail -n 1)
        [[ -n "${latest}" ]] || log_err $"Unable to determine latest version." 1

        # get file
        remote="${remote}${latest}"
    fi
    out="${BUILDDIR}/$(basename "${remote}")"
    remote_sig="${remote}.sig"
    out_sig="${out}.sig"
    if [[ -e "${out}" ]]; then
        if [[ -n "${IGNORE_SIG-}" ]] || [[ -n "$(verify_fetch)" ]]; then
            echo "${out}"
            return 0
        else
            rm "${out}"
        fi
    fi
    command_log $"Fetching '${remote}'..."
    curl ${curl_args} -o "${out}" "${remote}" || log_err $"Unable to retrieve file." 1
    if [[ -n "${IGNORE_SIG-}" ]] || [[ -n "$(verify_fetch)" ]]; then
        echo "${out}"
        return 0
    else
        rm "${out}" "${out_sig}"
        return 1
    fi
); fetch_version_recurse() { RECURSE=1 fetch_version "$@"; }

start_build() {
    # $1: directory
    # (optional) $2: autoconf arguments
    local srcdir="$(realpath "$1")"
    local objdir="${srcdir}-build"
    local prefix="$(realpath "${PREFIX}")"
    local args

    mkdir -p "${objdir}"
    cd "${objdir}"
    local rel=""
    if [[ -n "${2-}" ]]; then
        args="$2"
        "${srcdir}/configure" --prefix="${prefix}" --target="${TARGET}" ${args}
    else
        "${srcdir}/configure" --prefix="${prefix}" --target="${TARGET}"
    fi
    [[ $? -eq 0 ]] || log_err $"Failed to configure source directory '${srcdir}'" 1
}

configure_env() {
    ## set environment variables
    if [[ -n "${TARGET-}" ]]; then
        if ! is_declared "${TARGET}" archlist; then
            log_err $"Invalid target architecture '${TARGET}'" 2
        fi
    else
        TARGET="${default_target}"
    fi

    # echo arguments to expand paths
    if [[ -n "${PREFIX-}" ]]
    then PREFIX=$(eval echo ${PREFIX})
    else PREFIX=${default_prefix}
    fi
    if [[ -n "${BUILDDIR-}" ]]
    then BUILDDIR=$(eval echo ${BUILDDIR})
    else BUILDDIR=${default_builddir}
    fi
    [[ -n "${EXECNAME}" ]] || EXECNAME=${default_execname}
    boot_bin="${BUILDDIR}/${boot_basename}"
    kernel_bin="${BUILDDIR}/${kernel_basename}"
}

configure() (
    ## prepare build environment (uses subshell)
    extract_archive() {
        # $1: path to archive
        local in="$1"
        local out="${BUILDDIR}/$(basename "${in}" ".${archive_ext}")"
        command_log $"Extracting '${in}'..."
        mkdir -p "${out}" >&2
        tar -xzf "${in}" -C "${BUILDDIR}" >&2
        [[ $? -eq 0 ]] || log_err $"Failed to extract archive '${in}'" 1
        echo "${out}"
    }

    # set environment variables
    configure_env
    command_log_notice $"* Configuring build for target '${TARGET}'"
    command_log $"Using prefix '${PREFIX}'"
    
    # set local environment file
    cat <<-EOF >"${envfile}"
prefix=${PREFIX}
builddir=${BUILDDIR}
target=${TARGET}
execname=${EXECNAME}
boot_bin=${boot_bin}
kernel_bin=${kernel_bin}
EOF

    if [[ -n "${BUILD_DEBUG-}" ]]; then
        cat <<-EOF >>"${envfile}"
CFLAGS=${cflags_debug}
ASFLAGS=${asflags_debug}
EOF
    else
        cat <<-EOF >>"${envfile}"
CFLAGS=${cflags}
ASFLAGS=${asflags}
EOF
    fi

    # check prefix for installed toolchains
    local installed
    if [[ -z "${IGNORE_INSTALLED-}" && -e "${binariesfile}" ]]; then
        local fail
        while read name; do
            if [[ ! -x "${PREFIX}/bin/${TARGET}-${name}" ]]; then
                fail=1
                break
            fi
        done < "${binariesfile}"
        [[ ${fail} = 1 ]] || installed=true
    fi

    if [[ -n "${installed-}" ]]; then
        command_log $"Found existing toolchain binaries."
    else
        mkdir -p "${BUILDDIR}"
        mkdir -p "${PREFIX}"

        # fetch archives
        local arc_binutils
        local arc_gcc
        [[ -n ${IGNORE_SIG} ]] || KEYRING=$(fetch_keyring "${remote_keyring}")
        if [[ -n ${USE_LATEST-} ]]; then
            arc_binutils=$(fetch_version \
                "${remote_binutils}" \
                "${archive_ext}")
            arc_gcc=$(fetch_version_recurse \
                "${remote_gcc}" \
                "${archive_ext}")
        else
            arc_binutils=$(fetch_version \
                "${remote_binutils}/binutils-${version_binutils}.${archive_ext}")
            arc_gcc=$(fetch_version \
                "${remote_gcc}/gcc-${version_gcc}/gcc-${version_gcc}.${archive_ext}")
        fi

        # build binutils
        local src_binutils=$(extract_archive "${arc_binutils}")
        command_log $"Starting build for binutils..."
        start_build "${src_binutils}"
        make
        make install || log_err $"Failed to install binutils." 1
        cd "${basedir}"
        
        # build gcc
        local src_gcc=$(extract_archive "${arc_gcc}")
        command_log $"Starting build for gcc..."
        start_build "${src_gcc}"
        make all-gcc
        make all-target-libgcc
        make install-gcc
        make install-target-libgcc || log_err $"Failed to install gcc." 1
        cd "${basedir}"
    fi
    command_log_notice $"Configuration completed."
)

clean() {
    ## delete all objects listed in .gitignore
    ## separate into children of the root directory and global matches
    if [[ -f "${gitignore}" ]]; then
        local ignore_objects=$(grep -v "#" < "${gitignore}")
        local base_objects=$(grep "^/" <<< "${ignore_objects}" |
            cut -c 2-)
        local all_objects=$(grep "^[^/]" <<< "${ignore_objects}")

        [[ -z "${base_objects}" ]] || rm -rf ${base_objects}
        for search in ${all_objects}; do
            # remove wholenames if contained in subdirectory
            if [[ "${search}" = *'/'* ]]; then
                local objects=$(find . -wholename "$search")
            else
                local objects=$(find . -name "$search")
            fi
            
            [[ -z "${objects}" ]] || rm -rf ${objects}
        done
    fi
}

run() {
    ## run the system in QEMU
    configure_env

    if [[ -z "${QEMU-}" ]]; then
        if [[ "${TARGET}" = "${target_x86_64}" ]]; then
            QEMU=${qemu_exec_64}
        else
            QEMU=${qemu_exec_32}
        fi
    fi
    
    if ! which "${QEMU-}" >/dev/null 2>&1; then
        log_err $"Unable to locate QEMU executable."
    fi

    if [[ -n "${QEMU_USE_KERNEL-}" ]]; then
        qemu_args="-kernel "${kernel_bin}" ${qemu_args}"
    else
        qemu_args="-drive file="${boot_bin}",index=0,if=floppy,format=raw ${qemu_args}"
    fi

    qemu_args="-machine type=pc-i440fx-3.1 ${qemu_args}"

    if [[ -n "${RUN_DEBUG}" ]]; then
        if [[ -z "${GDB-}" ]]; then
            GDB=${gdb_exec}
        fi

        if ! which "${GDB-}" >/dev/null 2>&1; then
            log_err $"Unable to locate gdb executable."
        fi

        gdb_args="-ex 'target remote "${gdb_socket}"' ${gdb_args}"
        if [[ -e "${kernel_bin}" ]]; then
            gdb_args="-ex 'file "${kernel_bin}"' ${gdb_args}"
        fi
        
        qemu_args="-chardev socket,path="${gdb_socket}",server=on,wait=off,id=gdb0 \
    -gdb chardev:gdb0 \
    -S \
    ${qemu_args}"

        ${QEMU} ${qemu_args} &
        eval ${GDB} ${gdb_args}
        while [[ -n "$(jobs -p)" ]]; do
            kill %%
            wait
        done
        [[ ! -f "${gdb_socket}" ]] || rm "${gdb_socket}"
    else
        ${QEMU} ${qemu_args}
    fi
}

usage() {
    local basename=$(basename "$0")
    echo $"usage: ${basename} [options]... [commands]...
Build script for the Cosmos Operating System
options:
 -h, --help                 show this usage
 -V, --version              show version
 -s, --silent               silence log output
 --normalize                disable log colorization
 --list-targets             show available target architectures

 --target=<name>            specify target architecture
 --output=<path>            specify build directory
 --prefix=<path>            specify toolchain prefix
 --name=<name>              specify default executable name
 --build-debug              use debug build flags

 --use-latest               fetch latest toolchain versions
 --allow-unauthenticated    ignore gpg signatures
 --ignore-installed         ignore existing binaries in prefix

 --qemu=<exec>              specify QEMU executable
 --gdb=<exec>               specify GDB executable
 --use-kernel               (qemu) boot from kernel
 --use-fda                  (qemu) boot from floppy (default)

commands:
 configure                  prepare the build environment and dependencies
 clean                      remove all entries found in .gitignore
 run                        run the built system in QEMU
 debug                      debug the built system in QEMU using GDB"
}

version() {
    [[ ! -f "${versionfile}" ]] || local version=$(<"${versionfile}")
    echo $"cosmos sysbuild ${version} (Build Environment for the Cosmos Operating System)"
    [[ ! -f "${noticefile}" ]] || cat "${noticefile}"
}

show_arch() {
    local archlist_display="${archlist[@]}"
    echo $"available architectures:
${archlist_display// /, }"
}

# prepare variables for getopts
optstr=':hVsn-:'
# process non-option arguments and save initial values
nopt_argc=0
args=($@)
while [[ $# -gt 0 && $1 != '-'* ]]; do
    nopt_argc=$((${nopt_argc}+1))
    shift
done
# scan for options after argument shift
while getopts "${optstr}" OPT; do
    case ${OPT} in
        (-) # process '--' argument prefix
            # store complete argument for --<name>=<value> one-word syntax
            BASEARG="${OPTARG}"
            # set argument from after first '=' separator
            OPTARG="${BASEARG%%=*}"
            case "${OPTARG}" in
                ($"help")   
                    usage
                    exit ;;
                ($"version")
                    version
                    exit ;;
                ($"list-targets")
                    show_arch
                    exit ;;
                ($"target")
                    get_long TARGET "$@" ;;
                ($"output")
                    get_long BUILDDIR "$@" ;;
                ($"prefix")
                    get_long PREFIX "$@" ;;
                ($"name")
                    get_long EXECNAME "$@" ;;
                ("qemu")
                    get_long QEMU "$@" ;;
                ("gdb")
                    get_long GDB "$@" ;;
                ($"build-debug")
                    BUILD_DEBUG=1 ;;
                ($"silent")
                    SILENT=1 ;;
                ($"normalize")
                    NORMALIZE=1 ;;
                ($"use-latest")
                    USE_LATEST=1 ;;
                ($"allow-unauthenticated")
                    IGNORE_SIG=1 ;;
                ($"ignore-installed")
                    IGNORE_INSTALLED=1 ;;
                ($"use-kernel")
                    QEMU_USE_KERNEL=1 ;;
                ($"use-fda")
                    QEMU_USE_FDA=1 ;;
                (*)
                    arg_err ;;
            esac
            ;;
        (h) # usage
            usage
            exit ;;
        (V) # version
            version
            exit ;;
        (s) # silent
            SILENT=1 ;;
        (n) # normalize
            NORMALIZE=1 ;;
        (*) # not recognised
            arg_err ;;
    esac
done

# reset arguments to only non-options if the non-options were first
if [[ $((${nopt_argc})) -eq 0 ]]; then
    args=${args[@]:$((${OPTIND}-1))}
fi
# scan non-options
for COM in ${args}
do
    case "${COM}" in
        ($"configure")
            configure
            exit ;;
        ($"clean")
            clean
            exit ;;
        ($"run")
            run
            exit ;;
        ($"debug")
            RUN_DEBUG=1 run
            exit ;;
        (*) # not recognised
            command_err ;;
    esac
done
# show usage if no non-option arguments or commands were processed
usage