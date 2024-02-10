debug() {
    [ ! -z "$DEBUG" ] && echo "[DEBUG] $@" 1>&2
    "$@"
}

debug_log() {
    [ ! -z "$DEBUG" ] && echo "[DEBUG] $1" 1>&2
    return 0
}

log() {
    ICON="${2:-🏗}"
    echo "$ICON $1"
}

ssh_exec() {
    debug ssh -p ${SSH_PORT:=22} ${SSH_CONNECT} $@
}

ssh_exec_current_release() {
    ssh_exec "cd ${PATH_CURRENT_RELEASE_FOLDER} && ${@}"
}

scp_exec() {
    debug scp -P ${SSH_PORT:=22} $@
}

rsync_exec() {
    debug rsync -arz -K --exclude='.git/' --exclude='*/.git/' -e "ssh -p ${SSH_PORT:=22}" $@
}

gitlab_ci_log_section_start() {
    IDENTIFIER=$1
    TITLE=$2
    echo -e "\e[0Ksection_start:$(date +%s):$IDENTIFIER\r\e[0K$TITLE"
}

gitlab_ci_log_section_end() {
    IDENTIFIER=$1
    TITLE=$2
    echo -e "\e[0Ksection_end:$(date +%s):$IDENTIFIER\r\e[0K"
}
