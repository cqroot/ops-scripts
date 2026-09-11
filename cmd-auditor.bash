#!/usr/bin/env bash
set -euo pipefail

# cmd-auditor 是一个简单的二进制命令审计工具。
# cmd-auditor 会用一个简单的脚本替换目标二进制，来保证每次目标二进制的调用都会打印日志到 /var/log/<cmd>_audit.log。
# 由于 cmd-auditor 生成的二进制为普通 Bash 脚本，因此频繁调用的场景下无法保证性能，请不要在生产场景使用。

readonly MARKER="# CMD-AUDITOR-WRAPPER-v1"

function require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        echo "Error: must run as root" 1>&2
        return 1
    fi
}

function apply() {
    local audit_bin=${1:-}
    local audit_cmd
    audit_cmd=$(basename "${audit_bin}")

    require_root

    if [[ ! -x "${audit_bin}" ]]; then
        echo "Error: ${audit_bin} is not executable or does not exist" 1>&2
        return 1
    fi

    if [[ -e "${audit_bin}_bak" ]]; then
        echo "Error: ${audit_bin}_bak already exists, refusing to overwrite" 1>&2
        return 1
    fi

    local log_file="/var/log/${audit_cmd}_audit.log"
    touch "${log_file}"
    chmod 666 "${log_file}"

    cp -a "${audit_bin}" "${audit_bin}_bak"

    local tmp_wrapper
    tmp_wrapper=$(mktemp "${audit_bin}.XXXXXX")
    cat >"${tmp_wrapper}" <<WRAPPER
#!/bin/bash
${MARKER}
AUDIT_CMD="${audit_cmd}"
AUDIT_BAK="${audit_bin}_bak"
AUDIT_LOG="${log_file}"

START=\$(date '+%Y-%m-%d %H:%M:%S')
"\${AUDIT_BAK}" "\$@"
RC=\$?
END=\$(date '+%Y-%m-%d %H:%M:%S')
echo "[\${START} -> \${END}] [USER=\$(id -un)] [PWD=\$(pwd)] [RC=\${RC}] [ARGS=\${AUDIT_CMD} \$*] CALLER=\$(tr '\0' ' ' < /proc/\$PPID/cmdline)" >> "\${AUDIT_LOG}"
exit \${RC}
WRAPPER
    chmod a+x "${tmp_wrapper}"
    mv -f "${tmp_wrapper}" "${audit_bin}"
}

function clean() {
    local audit_bin=${1:-}
    local audit_cmd
    audit_cmd=$(basename "${audit_bin}")

    require_root

    if [[ ! -e "${audit_bin}_bak" ]]; then
        echo "Error: ${audit_bin}_bak does not exist, nothing to clean" 1>&2
        return 1
    fi

    if [[ -f "${audit_bin}" ]] && ! grep -qF "${MARKER}" "${audit_bin}" 2>/dev/null; then
        echo "Error: ${audit_bin} is not a cmd-auditor wrapper, refusing to overwrite" 1>&2
        return 1
    fi

    cp -a "${audit_bin}_bak" "${audit_bin}"
    chmod a+x "${audit_bin}"
    rm -f "${audit_bin}_bak"
}

function main() {
    local action=${1:-}
    local audit_bin=${2:-}

    if [[ -z "${action}" || -z "${audit_bin}" ]]; then
        echo "Usage: $0 {apply|clean} <binary>" 1>&2
        return 1
    fi

    case "${action}" in
    apply)
        apply "${audit_bin}"
        ;;
    clean)
        clean "${audit_bin}"
        ;;
    *)
        echo "Usage: $0 {apply|clean} <binary>" 1>&2
        return 1
        ;;
    esac
}

main "$@"