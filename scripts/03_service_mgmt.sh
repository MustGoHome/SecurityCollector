#!/bin/bash

# [U-34] Finger 서비스 비활성화
echo ""
echo "--------------------------------------------------"
echo "[ U-34 ] Finger 서비스 비활성화 (중요도: 상)"
echo "--------------------------------------------------"

finger_active=false

# 1. inetd 점검
if [[ -f /etc/inetd.conf ]]; then
    if grep -Ei '^\s*finger\s+' /etc/inetd.conf | grep -Ev '^\s*#' >/dev/null; then
        echo "[ WARNING ] /etc/inetd.conf에 Finger 서비스가 활성화되어 있습니다."
        finger_active=true
    fi
fi

# 2. xinetd 점검
if [[ -f /etc/xinetd.d/finger ]]; then
    disable_opt=$(grep -Ei '^\s*disable\s*=' /etc/xinetd.d/finger | grep -Ev '^\s*#' | awk -F'=' '{print tolower($2)}' | xargs)
    
    if [[ "${disable_opt}" != "yes" ]]; then
        echo "[ WARNING ] /etc/xinetd.d/finger에 Finger 서비스가 활성화되어 있습니다."
        finger_active=true
    fi
fi

# 3. systemd 점검 (현대적 방식)
if systemctl is-active --quiet finger.service 2>/dev/null || systemctl is-active --quiet finger.socket 2>/dev/null; then
    echo "[ WARNING ] systemd에 의해 Finger 서비스(또는 소켓)가 실행 중입니다."
    finger_active=true
fi

# 4. 포트 점검 (선택 사항: 실행 중인 프로세스 확인)
if netstat -antp 2>/dev/null | grep -q ":79 "; then
    echo "[ WARNING ] Finger 서비스 포트(79)가 열려 있습니다."
    finger_active=true
fi

# 최종 결과 출력
if [[ "${finger_active}" == true ]]; then
    echo ">> 점검 결과 : 취약"
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-35] 공유 서비스에 대한 익명 접근 제한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-35 ] 공유 서비스에 대한 익명 접근 제한 설정 (중요도: 상)"
echo "--------------------------------------------------"

warn=0

# 1. FTP 계정 존재 여부 (시스템 계정 레벨)
if grep -Eq '^(ftp|anonymous):' /etc/passwd; then
    echo "[ WARNING ] /etc/passwd에 익명 FTP 계정(ftp/anonymous)이 정의되어 있습니다."
    warn=1
fi

# 2. vsFTPd 익명 접속 설정
if systemctl is-active --quiet vsftpd; then
    # 여러 설정 파일 경로 체크 및 주석 제외 실설정값 확인
    vsftpd_conf=$(ls /etc/vsftpd.conf /etc/vsftpd/vsftpd.conf 2>/dev/null)
    if [[ -n "${vsftpd_conf}" ]]; then
        anon_res=$(grep -Ei '^\s*anonymous_enable\s*=' ${vsftpd_conf} | grep -vi '#' | awk -F= '{print tolower($2)}' | tr -d ' ')
        if [[ "${anon_res}" == "yes" ]]; then
            echo "[ WARNING ] vsFTPd: anonymous_enable=YES 설정이 활성화되어 있습니다."
            warn=1
        fi
    fi
fi

# 3. ProFTPd 익명 접속 설정
if systemctl is-active --quiet proftpd; then
    proftpd_conf=$(ls /etc/proftpd.conf /etc/proftpd/proftpd.conf 2>/dev/null)
    if [[ -n "${proftpd_conf}" ]]; then
        if sed -n '/<Anonymous/,/<\/Anonymous>/p' ${proftpd_conf} | grep -ivE '^\s*#' | grep -qi 'Anonymous'; then
            echo "[ WARNING ] ProFTPd: <Anonymous> 설정 블록이 활성화되어 있습니다."
            warn=1
        fi
    fi
fi

# 4. NFS 익명 접근 및 공유 설정 점검
if systemctl is-active --quiet nfs-server || systemctl is-active --quiet nfs; then
    if [[ -f /etc/exports ]]; then
        # 모든 호스트(*)에 공유하거나, 익명 매핑 옵션이 있는지 확인
        if grep -v '^\s*#' /etc/exports | grep -EiE '\*|all_squash|anonuid|anongid' >/dev/null; then
            echo "[ WARNING ] NFS: /etc/exports에 익명 접근 또는 과도한 공유 설정이 존재합니다."
            warn=1
        fi
    fi
fi

# 5. Samba 익명 접근 점검
if systemctl is-active --quiet smb; then
    smb_conf="/etc/samba/smb.conf"
    if [[ -f "${smb_conf}" ]]; then
        # guest ok, public, map to guest 세 가지 포인트 점검
        if grep -v '^\s*#' "${smb_conf}" | grep -Ei 'guest\s+ok\s*=\s*yes|public\s*=\s*yes|map\s+to\s+guest\s*=\s*bad\s+user' >/dev/null; then
            echo "[ WARNING ] Samba: 익명 접근(guest ok/public) 설정이 활성화되어 있습니다."
            warn=1
        fi
    fi
fi

# 최종 결과
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo ">> 점검 결과 : 취약"
fi


# [U-36] r 계열 서비스 비활성화
echo ""
echo "--------------------------------------------------"
echo "[ U-36 ] r 계열 서비스 비활성화 (중요도: 상)"
echo "--------------------------------------------------"

warn=0
r_services=("rlogin" "rsh" "rexec")

# 1. inetd 점검
inetd_conf="/etc/inetd.conf"
if [[ -f "${inetd_conf}" ]]; then
    for svc in "${r_services[@]}"; do
        if grep -Ei "^\s*${svc}\s+" "${inetd_conf}" | grep -Ev '^\s*#' >/dev/null; then
            echo "[ WARNING ] inetd: ${svc} 서비스가 활성화되어 있습니다."
            warn=1
        fi
    done
fi

# 2. xinetd 점검 (파일명과 설정을 매칭하여 더 정확하게 점검)
xinetd_dir="/etc/xinetd.d"
if [[ -d "${xinetd_dir}" ]]; then
    for svc in "${r_services[@]}"; do
        svc_file="${xinetd_dir}/${svc}"
        if [[ -f "${svc_file}" ]]; then
            disable_opt=$(grep -Ei '^\s*disable\s*=' "${svc_file}" | grep -Ev '^\s*#' | awk -F'=' '{print tolower($2)}' | xargs)
            if [[ "${disable_opt}" == "no" ]]; then
                echo "[ WARNING ] xinetd: ${svc} 서비스가 활성화되어 있습니다."
                warn=1
            fi
        fi
    done
fi

# 3. systemd 점검
systemd_r_pattern='^(rlogin|rsh|rexec|rlogind|rshd|rexecd)\.(service|socket)'
# 실행 중인 유닛 확인
active_r_units=$(systemctl list-units --type=service --type=socket --state=running --no-legend 2>/dev/null \
                 | awk '{print $1}' | grep -E "${systemd_r_pattern}")

if [[ -n "${active_r_units}" ]]; then
    echo "[ WARNING ] systemd: 다음 r 계열 유닛이 실행 중입니다: ${active_r_units}"
    warn=1
fi

# 4. 포트 점검 (512: rexec, 513: rlogin, 514: rsh)
# ss 또는 netstat 명령어를 사용하여 실제 리스닝 포트 확인
if command -v ss >/dev/null 2>&1; then
    listen_ports=$(ss -antl | grep -E ':(512|513|514)\b')
elif command -v netstat >/dev/null 2>&1; then
    listen_ports=$(netstat -antl | grep -E ':(512|513|514)\b')
fi

if [[ -n "${listen_ports}" ]]; then
    echo "[ WARNING ] 네트워크: r 계열 표준 포트(512, 513, 514)가 활성화되어 있습니다."
    warn=1
fi

# 최종 결과
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo ">> 점검 결과 : 취약"
fi


# [U-37] crontab 설정파일 권한 설정 미흡
echo ""
echo "--------------------------------------------------"
echo "[ U-37 ] crontab 설정파일 권한 설정 미흡 (중요도: 상)"
echo "--------------------------------------------------"

warn=0

# 1. crontab / at 실행 파일 점검 (SUID 및 권한)
check_bins=("/usr/bin/crontab" "/usr/bin/at")

for bin in "${check_bins[@]}"; do
    [[ -f "${bin}" ]] || continue
    
    owner=$(stat -c "%U" "${bin}")
    perm=$(stat -c "%a" "${bin}")
    # SUID 포함 여부 확인 (s 또는 S)
    is_suid=$(stat -c "%A" "${bin}" | grep -Ei 's')

    # 가이드라인: 소유자 root, 권한 750 이하, SUID 제거 권고
    if [[ "${owner}" != "root" || "${perm}" -gt 750 || -n "${is_suid}" ]]; then
        echo "[ WARNING ] 실행 파일 보안 미흡: ${bin} (소유자: ${owner}, 권한: ${perm}, SUID: ${is_suid:-None})"
        warn=1
    fi
done

# 2. cron 관련 설정 파일 및 디렉터리 점검
# 설정 파일 (640 이하)
cron_confs=("/etc/crontab" "/etc/cron.allow" "/etc/cron.deny")
# 설정 디렉터리 (750 이하)
cron_dirs=("/etc/cron.hourly" "/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly" "/etc/cron.d")

for conf in "${cron_confs[@]}"; do
    [[ -f "${conf}" ]] || continue
    if [[ $(stat -c "%U" "${conf}") != "root" || $(stat -c "%a" "${conf}") -gt 640 ]]; then
        echo "[ WARNING ] 설정 파일 권한 미흡: ${conf}"
        warn=1
    fi
done

for dir in "${cron_dirs[@]}"; do
    [[ -d "${dir}" ]] || continue
    if [[ $(stat -c "%U" "${dir}") != "root" || $(stat -c "%a" "${dir}") -gt 750 ]]; then
        echo "[ WARNING ] 설정 디렉터리 권한 미흡: ${dir}"
        warn=1
    fi
done

# 3. cron / at 스풀(Spool) 디렉터리 내 작업 파일 점검
spool_dirs=("/var/spool/cron" "/var/spool/cron/crontabs" "/var/spool/at" "/var/spool/cron/atjobs")

for s_dir in "${spool_dirs[@]}"; do
    [[ -d "${s_dir}" ]] || continue
    
    # 일반 사용자의 작업 파일은 소유자가 root가 아닐 수 있으므로 권한 위주로 점검
    bad_files=$(find "${s_dir}" -maxdepth 1 -type f -perm /027 2>/dev/null)
    if [[ -n "${bad_files}" ]]; then
        echo "[ WARNING ] 스풀 디렉터리에 권한이 과도한 파일이 존재합니다: ${s_dir}"
        warn=1
    fi
done

# 최종 결과
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo ">> 점검 결과 : 취약"
fi


# [U-38] DoS 공격에 취약한 서비스 비활성화
echo ""
echo "--------------------------------------------------"
echo "[ U-38 ] DoS 공격에 취약한 서비스 비활성화 (중요도: 상)"
echo "--------------------------------------------------"

warn=0
# 점검 대상: echo(7), discard(9), daytime(13), chargen(19), time(37)
dos_services=("echo" "discard" "daytime" "chargen" "time")
dos_pattern=$(echo "${dos_services[@]}" | sed 's/ /|/g')

# 1. /etc/inetd.conf 점검
inetd_conf="/etc/inetd.conf"
if [[ -f "${inetd_conf}" ]]; then
    if grep -Ei "^\s*(${dos_pattern})\s" "${inetd_conf}" | grep -Ev '^\s*#' >/dev/null; then
        echo "[ WARNING ] inetd: DoS 취약 서비스가 설정되어 있습니다."
        warn=1
    fi
fi

# 2. /etc/xinetd.d 점검
xinetd_dir="/etc/xinetd.d"
if [[ -d "${xinetd_dir}" ]]; then
    for svc in "${dos_services[@]}"; do
        if [[ -f "${xinetd_dir}/${svc}" ]]; then
            disable_opt=$(grep -Ei '^\s*disable\s*=' "${xinetd_dir}/${svc}" | grep -Ev '^\s*#' | awk -F'=' '{print tolower($2)}' | xargs)
            if [[ "${disable_opt}" == "no" ]]; then
                echo "[ WARNING ] xinetd: ${svc} 서비스가 활성화되어 있습니다."
                warn=1
            fi
        fi
    done
fi

# 3. systemd 점검 (서비스 및 소켓 포함)
# 실행 중이거나 활성화된 소켓/서비스 유닛 검색
active_units=$(systemctl list-units --type=service --type=socket --state=active --no-legend 2>/dev/null \
               | awk '{print $1}' | grep -E "^(${dos_pattern})(@.*)?\.(service|socket)")

if [[ -n "${active_units}" ]]; then
    echo "[ WARNING ] systemd: DoS 취약 유닛이 활성화 상태입니다: ${active_units}"
    warn=1
fi

# 4. 네트워크 포트 점검 (이중 확인)
# 7, 9, 13, 19, 37번 포트 리스닝 여부 확인
if command -v ss >/dev/null 2>&1; then
    listen_check=$(ss -tuln | grep -E ':(7|9|13|19|37)\b')
elif command -v netstat >/dev/null 2>&1; then
    listen_check=$(netstat -tuln | grep -E ':(7|9|13|19|37)\b')
fi

if [[ -n "${listen_check}" ]]; then
    echo "[ WARNING ] 네트워크: DoS 취약 서비스 포트가 열려 있습니다."
    warn=1
fi

# 최종 결과
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo ">> 점검 결과 : 취약"
fi


# [U-39] 불필요한 NFS 서비스 비활성화
echo ""
echo "--------------------------------------------------"
echo "[ U-39 ] 불필요한 NFS 서비스 비활성화 (중요도: 상)"
echo "--------------------------------------------------"

warn=0

# 1. NFS 관련 서비스 및 소켓 유닛 정의
# rpcbind는 nfs 서비스의 의존성 서비스로 매우 중요함
nfs_patterns="nfs-server|nfs|rpcbind|rpc-statd|rpc-mountd|rpc-idmapd|nfs-idmapd"

# 실행 중인 서비스(.service) 및 소켓(.socket) 점검
active_nfs_units=$(systemctl list-units --type=service --type=socket --state=active --no-legend 2>/dev/null \
    | awk '{print $1}' | grep -E "^(${nfs_patterns})(\.service|\.socket)")

if [[ -n "${active_nfs_units}" ]]; then
    echo "[ WARNING ] NFS 관련 서비스/소켓이 활성화되어 있습니다: "
    echo "${active_nfs_units}"
    warn=1
fi

# 2. 실제 공유 설정(/etc/exports) 존재 여부 확인
if [[ -f /etc/exports ]]; then
    export_content=$(grep -vE '^\s*#|^\s*$' /etc/exports)
    if [[ -n "${export_content}" ]]; then
        echo "[ WARNING ] /etc/exports 파일에 활성화된 공유 설정이 존재합니다."
        warn=1
    fi
fi

# 3. 네트워크 포트 점검 (111: RPC, 2049: NFS)
if command -v ss >/dev/null 2>&1; then
    nfs_port_check=$(ss -tuln | grep -E ':(111|2049)\b')
elif command -v netstat >/dev/null 2>&1; then
    nfs_port_check=$(netstat -tuln | grep -E ':(111|2049)\b')
fi

if [[ -n "${nfs_port_check}" ]]; then
    echo "[ WARNING ] 네트워크: NFS/RPC 관련 포트(111, 2049)가 열려 있습니다."
    warn=1
fi

# 최종 결과 출력
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo ">> 점검 결과 : 취약 (NFS 서비스 비활성화 권고)"
fi


# [U-40] NFS 접근 통제
echo ""
echo "--------------------------------------------------"
echo "[ U-40 ] NFS 접근 통제 (중요도: 상)"
echo "--------------------------------------------------"

warn=0
exports_file="/etc/exports"

if [[ -f "${exports_file}" ]]; then
    # 1. 파일 소유자 및 권한 점검
    owner=$(stat -c "%U" "${exports_file}")
    perm=$(stat -c "%a" "${exports_file}")

    if [[ "${owner}" != "root" || "${perm}" -gt 644 ]]; then
        echo "[ WARNING ] /etc/exports 파일 소유자(${owner}) 또는 권한(${perm}) 설정이 부적절합니다."
        warn=1
    fi

    # 2. 와일드카드(*) 또는 무분별한 접근 허용 점검
    # 주석 제외, 실제 설정 라인 중 '*'이 포함된 행 추출
    insecure_configs=$(grep -Ev '^\s*#|^\s*$' "${exports_file}" | awk '{print $2}' | grep '\*')

    if [[ -n "${insecure_configs}" ]]; then
        echo "[ WARNING ] /etc/exports에 와일드카드(*)를 사용한 접근 허용 설정이 존재합니다."
        echo "    설정 내용: $(grep -Ev '^\s*#|^\s*$' "${exports_file}" | grep '\*')"
        warn=1
    fi
    
    # 추가: 모든 네트워크(0.0.0.0/0) 허용 여부 점검 (선택 사항)
    if grep -Ev '^\s*#|^\s*$' "${exports_file}" | grep -q '0\.0\.0\.0/0'; then
        echo "[ WARNING ] /etc/exports에 전체 네트워크(0.0.0.0/0) 접근 허용 설정이 존재합니다."
        warn=1
    fi

else
    # 파일이 없는 경우 NFS 서비스를 사용하지 않는 것으로 간주
    echo "[ SAFE ] /etc/exports 파일이 존재하지 않습니다. (NFS 미사용)"
    # 여기서 return이나 exit를 하지 않고 스크립트 흐름을 유지합니다.
fi

# 3. 최종 결과 출력
if [[ "${warn}" -eq 0 && -f "${exports_file}" ]]; then
    echo "[ SAFE ] 점검 결과 : 안전 (적절한 접근 통제 적용 중)"
elif [[ "${warn}" -eq 1 ]]; then
    echo ">> 점검 결과 : 취약 (NFS 접근 통제 설정 보완 필요)"
fi


# [U-41] 불필요한 automountd 제거
echo ""
echo "--------------------------------------------------"
echo "[ U-41 ] 불필요한 automountd 제거 (중요도: 상)"
echo "--------------------------------------------------"

warn=0

# 1. 서비스 실구동 상태 확인 (Active)
if systemctl is-active --quiet autofs 2>/dev/null; then
    echo "[ WARNING ] autofs 서비스가 현재 '실행 중(active)'입니다."
    warn=1
fi

# 2. 부팅 시 자동 시작 설정 확인 (Enabled)
if systemctl is-enabled --quiet autofs 2>/dev/null; then
    echo "[ WARNING ] autofs 서비스가 '자동 시작(enabled)'으로 설정되어 있습니다."
    warn=1
fi

# 3. 프로세스 구동 여부 확인 (ps)
if ps -ef | grep -v "grep" | grep -qi "automount"; then
    echo "[ WARNING ] automount 프로세스가 시스템에서 동작 중입니다."
    warn=1
fi

# 최종 결과 출력
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전 (autofs 서비스가 비활성화되어 있습니다.)"
else
    echo ">> 점검 결과 : 취약 (불필요한 경우 autofs 서비스 중지 및 disable 권고)"
fi


# [U-42] 불필요한 RPC 서비스 비활성화
echo ""
echo "--------------------------------------------------"
echo "[ U-42 ] 불필요한 RPC 서비스 비활성화 (중요도: 상)"
echo "--------------------------------------------------"

warn=0
# 주요 RPC 관련 데몬 패턴
rpc_patterns="rpcbind|portmap|rpc\.|mountd|statd|lockd|rquotad"

# 1. inetd 점검
inetd_conf="/etc/inetd.conf"
if [[ -f "${inetd_conf}" ]]; then
    if grep -Ei "^\s*(${rpc_patterns})" "${inetd_conf}" | grep -Ev '^\s*#' >/dev/null; then
        echo "[ WARNING ] inetd 기반 RPC 서비스가 설정 파일에 활성화되어 있습니다."
        warn=1
    fi
fi

# 2. xinetd 점검
xinetd_dir="/etc/xinetd.d"
if [[ -d "${xinetd_dir}" ]]; then
    # disable=no 설정이 되어 있는 RPC 관련 파일 탐색
    bad_xinetd=$(grep -ril 'disable\s*=\s*no' "${xinetd_dir}" 2>/dev/null | grep -Ei "(${rpc_patterns})")
    if [[ -n "${bad_xinetd}" ]]; then
        echo "[ WARNING ] xinetd 기반 RPC 서비스가 활성화되어 있습니다: ${bad_xinetd}"
        warn=1
    fi
fi

# 3. systemd 점검 (서비스 및 소켓 포함)
# rpcbind는 소켓 형태로 대기하는 경우가 많으므로 socket 타입도 포함
active_rpc_units=$(systemctl list-units --type=service --type=socket --state=active --no-legend 2>/dev/null \
    | awk '{print $1}' | grep -Ei "^(${rpc_patterns})")

if [[ -n "${active_rpc_units}" ]]; then
    echo "[ WARNING ] systemd 기반 RPC 서비스/소켓이 활성화 상태입니다: ${active_rpc_units}"
    warn=1
fi

# 4. 네트워크 포트 점검 (111번 포트: RPC 핵심 포트)
if command -v ss >/dev/null 2>&1; then
    rpc_port_check=$(ss -tuln | grep -E ':(111)\b')
elif command -v netstat >/dev/null 2>&1; then
    rpc_port_check=$(netstat -tuln | grep -E ':(111)\b')
fi

if [[ -n "${rpc_port_check}" ]]; then
    echo "[ WARNING ] 네트워크: RPC Portmapper(111) 포트가 열려 있습니다."
    warn=1
fi

# 최종 결과 출력
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo ">> 점검 결과 : 취약 (불필요한 RPC 서비스 비활성화 권고)"
fi


# [U-43] NIS, NIS+ 점검
echo ""
echo "--------------------------------------------------"
echo "[ U-43 ] NIS, NIS+ 점검 (중요도: 상)"
echo "--------------------------------------------------"

warn=0
nis_services=("ypserv" "ypbind" "ypxfrd" "rpc.yppasswdd" "rpc.ypupdated")

# 1. systemd 서비스 상태 및 활성화 여부 점검
for svc in "${nis_services[@]}"; do
    # 실행 중(active)이거나 자동 시작(enabled)으로 설정된 경우 체크
    if systemctl is-active --quiet "${svc}" 2>/dev/null || \
       systemctl is-enabled --quiet "${svc}" 2>/dev/null; then
        echo "[ WARNING ] NIS 관련 서비스(${svc})가 활성화 또는 실행 중입니다."
        warn=1
    fi
done

# 2. NIS 도메인 네임 설정 확인
if [[ -n $(nisdomainname 2>/dev/null) && $(nisdomainname 2>/dev/null) != "(none)" ]]; then
    echo "[ WARNING ] 시스템에 NIS 도메인 네임이 설정되어 있습니다: $(nisdomainname)"
    warn=1
fi

# 3. xinetd 내 NIS 관련 설정 확인 (보완)
xinetd_dir="/etc/xinetd.d"
if [[ -d "${xinetd_dir}" ]]; then
    if grep -rEi "ypserv|ypbind" "${xinetd_dir}" | grep -v "disable *= *yes" >/dev/null 2>&1; then
        echo "[ WARNING ] xinetd 설정에 활성화된 NIS 서비스가 존재합니다."
        warn=1
    fi
fi

# 최종 결과 출력
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo ">> 점검 결과 : 취약 (NIS/NIS+ 서비스 비활성화 권고)"
fi


# [U-44] tftp, talk 서비스 비활성화
echo ""
echo "--------------------------------------------------"
echo "[ U-44 ] tftp, talk 서비스 비활성화 (중요도: 상)"
echo "--------------------------------------------------"

warn=0
svc_pattern='tftp|talk|ntalk'

# 1. inetd 점검
inetd_conf="/etc/inetd.conf"
if [[ -f "${inetd_conf}" ]]; then
    if grep -Ei "^\s*(${svc_pattern})\s" "${inetd_conf}" | grep -Ev '^\s*#' >/dev/null; then
        echo "[ WARNING ] inetd 기반 tftp/talk/ntalk 서비스가 활성화되어 있습니다."
        warn=1
    fi
fi

# 2. xinetd 점검
xinetd_dir="/etc/xinetd.d"
if [[ -d "${xinetd_dir}" ]]; then
    # 각 서비스 파일에서 disable = no 설정을 정밀하게 탐색
    bad_xinetd=$(grep -ril 'disable\s*=\s*no' "${xinetd_dir}" 2>/dev/null | grep -Ei "(${svc_pattern})")
    if [[ -n "${bad_xinetd}" ]]; then
        echo "[ WARNING ] xinetd 기반 서비스가 활성화되어 있습니다: ${bad_xinetd}"
        warn=1
    fi
fi

# 3. systemd 점검 (서비스 및 소켓 포함)
# tftp는 소켓 활성화 방식이 흔하므로 socket 타입도 반드시 포함
active_units=$(systemctl list-units --type=service --type=socket --state=active --no-legend 2>/dev/null \
    | awk '{print $1}' | grep -Ei "^(${svc_pattern})")

if [[ -n "${active_units}" ]]; then
    echo "[ WARNING ] systemd 기반 서비스/소켓이 활성화 상태입니다: ${active_units}"
    warn=1
fi

# 4. 네트워크 UDP 포트 점검 (69: tftp, 517: talk, 518: ntalk)
if command -v ss >/dev/null 2>&1; then
    udp_port_check=$(ss -tuln | grep -Ei ':(69|517|518)\b')
elif command -v netstat >/dev/null 2>&1; then
    udp_port_check=$(netstat -tuln | grep -Ei ':(69|517|518)\b')
fi

if [[ -n "${udp_port_check}" ]]; then
    echo "[ WARNING ] 네트워크: tftp/talk 관련 UDP 포트가 열려 있습니다."
    warn=1
fi

# 최종 결과 출력
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo ">> 점검 결과 : 취약 (해당 서비스의 완전한 중지 및 비활성화 권고)"
fi


# [U-45] 메일 서비스 버전 점검
echo ""
echo "--------------------------------------------------"
echo "[ U-45 ] 메일 서비스 버전 점검 (중요도: 상)"
echo "--------------------------------------------------"

warn=0
mail_found=0

# 1. Sendmail 점검
if systemctl is-active --quiet sendmail 2>/dev/null; then
    version=$(sendmail -d0.1 -bt < /dev/null 2>/dev/null | grep -i "Version" | awk '{print $2}')
    echo "[ WARNING ] Sendmail 서비스가 구동 중입니다. (현재 버전: ${version:-Unknown})"
    mail_found=1
    warn=1
fi

# 2. Postfix 점검
if systemctl is-active --quiet postfix 2>/dev/null; then
    version=$(postconf -d mail_version 2>/dev/null | awk '{print $3}')
    echo "[ WARNING ] Postfix 서비스가 구동 중입니다. (현재 버전: ${version:-Unknown})"
    mail_found=1
    warn=1
fi

# 3. Exim 점검
if systemctl is-active --quiet exim 2>/dev/null; then
    version=$(exim --version 2>/dev/null | head -n 1 | awk '{print $3}')
    echo "[ WARNING ] Exim 서비스가 구동 중입니다. (현재 버전: ${version:-Unknown})"
    mail_found=1
    warn=1
fi

# 최종 결과 출력
if [[ "${mail_found}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전 (구동 중인 메일 서비스 없음)"
else
    echo ">> 점검 결과 : 사용자 정의 (위 출력된 버전의 최신 보안 패치 여부를 수동으로 확인하십시오.)"
fi


# [U-46] 일반 사용자의 메일 서비스 실행 방지
echo ""
echo "--------------------------------------------------"
echo "[ U-46 ] 일반 사용자의 메일 서비스 실행 방지 (중요도: 상)"
echo "--------------------------------------------------"

warn=0

# 점검 대상 파일 확장
check_list=(
    "Sendmail|/usr/sbin/sendmail"
    "Postfix|/usr/sbin/postsuper"
    "Postfix|/usr/sbin/postqueue"
    "Postfix|/usr/sbin/postdrop"
    "Exim|/usr/sbin/exiqgrep"
    "Exim|/usr/sbin/exim"
)

for item in "${check_list[@]}"; do
    IFS="|" read -r service file <<< "${item}"

    [[ -f "${file}" ]] || continue

    # stat으로 권한 추출 (755 등)
    perm=$(stat -c "%a" "${file}")
    
    # 8진수 끝자리(Other) 추출 및 실행 권한(1, 3, 5, 7) 확인
    other_perm=$(( 8#$perm & 1 ))
    # 그룹 실행 권한(Group) 확인 (선택 사항이나 권장)
    group_perm=$(( 8#$perm & 8 ))

    if [[ "${other_perm}" -ne 0 ]]; then
        echo "[ WARNING ] ${service}: ${file}에 '일반 사용자(Other)' 실행 권한이 있습니다. (현재 권한: ${perm})"
        warn=1
    fi
done

# 최종 결과 출력
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo ">> 점검 결과 : 취약 (주요 메일 관리 바이너리의 실행 권한 제한 필요)"
fi


# [U-47] 스팸 메일 릴레이 제한
echo ""
echo "--------------------------------------------------"
echo "[ U-47 ] 스팸 메일 릴레이 제한 (중요도: 상)"
echo "--------------------------------------------------"

warn=0

# 1. Sendmail 점검
if systemctl is-active --quiet sendmail; then
    # promiscuous_relay 설정 확인 (모든 릴레이 허용)
    if grep -Ei 'promiscuous_relay' /etc/mail/sendmail.mc /etc/mail/sendmail.cf 2>/dev/null | grep -v '^\s*dnl' >/dev/null; then
        echo "[ WARNING ] Sendmail: 오픈 릴레이 설정(promiscuous_relay)이 활성화되어 있습니다."
        warn=1
    fi
    # access 파일 내 과도한 RELAY 허용 확인
    if [[ -f /etc/mail/access ]]; then
        if grep -v '^\s*#' /etc/mail/access | grep -q 'RELAY'; then
            echo "[ INFO ] Sendmail: /etc/mail/access 파일에 릴레이 허용 대역이 정의되어 있습니다. (수동 확인 권장)"
        fi
    fi
fi

# 2. Postfix 점검
if systemctl is-active --quiet postfix; then
    conf_file="/etc/postfix/main.cf"
    if [[ -f "${conf_file}" ]]; then
        mynetworks=$(postconf -h mynetworks 2>/dev/null)
        restrictions=$(postconf -h smtpd_recipient_restrictions 2>/dev/null)

        # 모든 네트워크 허용 여부 체크
        if [[ "${mynetworks}" =~ "0.0.0.0/0" || -z "${mynetworks}" ]]; then
            echo "[ WARNING ] Postfix: mynetworks 설정이 모든 대역(0.0.0.0/0)을 허용하거나 비어 있습니다."
            warn=1
        fi

        # 릴레이 제한 정책 확인
        if [[ ! "${restrictions}" =~ "reject_unauth_destination" ]]; then
            echo "[ WARNING ] Postfix: smtpd_recipient_restrictions에 reject_unauth_destination 설정이 없습니다."
            warn=1
        fi
    fi
fi

# 3. Exim 점검
exim_conf=$(ls /etc/exim/exim.conf /etc/exim4/exim4.conf 2>/dev/null | head -n 1)
if [[ -n "${exim_conf}" ]] && systemctl is-active --quiet exim 2>/dev/null; then
    # 모든 호스트 릴레이 허용 확인
    if grep -v '^\s*#' "${exim_conf}" | grep -E 'accept\s+hosts\s*=\s*\*' >/dev/null; then
        echo "[ WARNING ] Exim: 모든 호스트(*)에 대해 릴레이가 허용되어 있습니다."
        warn=1
    fi
    
    # 릴레이 허용 리스트 존재 여부
    if ! grep -v '^\s*#' "${exim_conf}" | grep -q 'hostlist\s+relay_from_hosts'; then
        echo "[ WARNING ] Exim: relay_from_hosts(신뢰 호스트 리스트) 설정이 누락되었습니다."
        warn=1
    fi
fi

# 최종 결과 출력
if [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo ">> 점검 결과 : 취약 (메일 릴레이 제한 설정 보완 필요)"
fi


# [U-48] expn, vrfy 명령어 제한
echo ""
echo "--------------------------------------------------"
echo "[ U-48 ] expn, vrfy 명령어 제한 (중요도: 중)"
echo "--------------------------------------------------"

warn=0
mail_server_count=0

# 1. Sendmail 점검
if systemctl is-active --quiet sendmail; then
    mail_server_count=$((mail_server_count + 1))
    sendmail_cf="/etc/mail/sendmail.cf"
    if [[ -f "${sendmail_cf}" ]]; then
        # PrivacyOptions 내에 noexpn, novrfy 또는 이를 모두 포함하는 goaway 설정 확인
        # 주석(#) 처리된 라인은 제외
        if ! grep -v '^\s*#' "${sendmail_cf}" | grep -Ei 'PrivacyOptions' | grep -EiE '(noexpn|novrfy|goaway)' >/dev/null; then
            echo "[ WARNING ] Sendmail: PrivacyOptions에서 noexpn 또는 novrfy 설정이 누락되었습니다."
            warn=1
        fi
    fi
fi

# 2. Postfix 점검
if systemctl is-active --quiet postfix; then
    mail_server_count=$((mail_server_count + 1))
    # postconf 명령어로 실제 적용된 설정값 확인
    vrfy_res=$(postconf -h disable_vrfy_command 2>/dev/null)
    if [[ "${vrfy_res}" != "yes" ]]; then
        echo "[ WARNING ] Postfix: disable_vrfy_command 설정이 'yes'가 아닙니다. (현재값: ${vrfy_res:-no})"
        warn=1
    fi
fi

# 3. Exim 점검
if systemctl is-active --quiet exim 2>/dev/null; then
    mail_server_count=$((mail_server_count + 1))
    exim_conf=$(ls /etc/exim/exim.conf /etc/exim4/exim4.conf 2>/dev/null | head -n 1)
    if [[ -n "${exim_conf}" ]]; then
        # vrfy나 expn을 명시적으로 허용(accept)하는 설정이 있는지 확인
        if grep -v '^\s*#' "${exim_conf}" | grep -Ei 'acl_smtp_(vrfy|expn)' | grep -qi 'accept'; then
            echo "[ WARNING ] Exim: SMTP 명령(vrfy/expn) 허용 설정이 감지되었습니다. (${exim_conf})"
            warn=1
        fi
    fi
fi

# 최종 결과 출력
if [[ "${mail_server_count}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전 (활성화된 메일 서비스가 없습니다.)"
elif [[ "${warn}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전 (모든 메일 서비스의 정보 노출 명령어 제한 설정이 양호합니다.)"
else
    echo ">> 점검 결과 : 취약 (메일 서버 정보 노출 방지 설정 보완 필요)"
fi


# [U-49] DNS 보안 버전 패치
echo ""
echo "--------------------------------------------------"
echo "[ U-49 ] DNS 보안 버전 패치 (중요도: 상)"
echo "--------------------------------------------------"
echo "[ SAFE ] 점검 결과 : 사용자 정의"


# [U-50] DNS ZoneTransfer 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-50 ] DNS ZoneTransfer 설정 (중요도: 상)"
echo "--------------------------------------------------"

warn=0

# 1. named 서비스 구동 확인 (전체 스크립트 흐름을 위해 exit 대신 if 사용)
if systemctl is-active --quiet named; then
    
    # 2. 레거시 named.boot 파일 점검
    xfr_files=("/etc/named.boot" "/etc/bind/named.boot")
    for file in "${xfr_files[@]}"; do
        [[ -f "${file}" ]] || continue
        # 주석 제외하고 xfrnets 설정 확인
        if grep -vE '^\s*(#|//|;)' "${file}" | grep -Ei 'xfrnets' | grep -Eq '(any|\*)'; then
            echo "[ WARNING ] xfrnets 설정이 전체 허용(any/*)으로 설정되어 있습니다. (${file})"
            warn=1
        fi
    done

    # 3. 현대적 named.conf 파일 점검
    named_conf_files=(
        "/etc/named.conf"
        "/etc/bind/named.conf"
        "/etc/bind/named.conf.options"
    )

    for file in "${named_conf_files[@]}"; do
        [[ -f "${file}" ]] || continue
        
        # allow-transfer 블록 내에 any 또는 *가 포함되어 있는지 점검
        # 주석을 제외하고 실질적인 설정을 확인
        target_lines=$(grep -vE '^\s*(#|//|;)' "${file}" | grep -Ei 'allow-transfer')
        
        if echo "${target_lines}" | grep -Eq '(any|\*)'; then
            echo "[ WARNING ] allow-transfer가 전체 허용(any/*)으로 설정되어 있습니다. (${file})"
            warn=1
        fi
    done

    # 4. allow-transfer 설정이 아예 누락되었는지 확인 (보안 권고)
    # options 블록 내에 allow-transfer 설정이 하나도 없는 경우
    all_confs=$(cat "${named_conf_files[@]}" 2>/dev/null | grep -vE '^\s*(#|//|;)')
    if ! echo "${all_confs}" | grep -qi 'allow-transfer'; then
        echo "[ WARNING ] allow-transfer 설정이 명시적으로 존재하지 않습니다. (기본값에 의한 정보 유출 위험)"
        warn=1
    fi

    # 결과 출력
    if [[ "${warn}" -eq 0 ]]; then
        echo "[ SAFE ] 점검 결과 : 안전 (영역 전송이 제한되어 있습니다.)"
    else
        echo ">> 점검 결과 : 취약 (보조 서버로만 영역 전송을 제한해야 합니다.)"
    fi

else
    echo "[ SAFE ] 점검 결과 : 안전 (DNS 서비스가 실행 중이지 않습니다.)"
fi


# [U-51] DNS 서비스의 취약한 동적 업데이트 설정 금지
echo ""
echo "--------------------------------------------------"
echo "[ U-51 ] DNS 서비스의 취약한 동적 업데이트 설정 금지 (중요도: 중)"
echo "--------------------------------------------------"

warn=0

# 1. named 서비스 구동 확인 (exit 대신 if 블록 사용)
if systemctl is-active --quiet named; then

    # 점검할 설정 파일 목록
    named_conf_files=(
        "/etc/named.conf"
        "/etc/bind/named.conf"
        "/etc/bind/named.conf.options"
    )

    for file in "${named_conf_files[@]}"; do
        [[ -f "${file}" ]] || continue
        
        # 2. 주석(//, #)을 제외한 실제 설정 라인에서 allow-update 블록 추출
        # 구문: allow-update { any; }; 또는 allow-update { *; }; 점검
        target_config=$(grep -vE '^\s*(#|//|;)' "${file}" | grep -Ei 'allow-update')

        if echo "${target_config}" | grep -Eq '\b(any|\*)\b'; then
            echo "[ WARNING ] allow-update가 전체 허용(any/*)으로 설정되어 있습니다. (${file})"
            warn=1
        fi
    done

    # 3. 최종 결과 출력
    if [[ "${warn}" -eq 0 ]]; then
        echo "[ SAFE ] 점검 결과 : 안전 (동적 업데이트 설정이 적절히 제한되어 있습니다.)"
    else
        echo ">> 점검 결과 : 취약 (특정 호스트 또는 TSIG 키로 업데이트를 제한해야 합니다.)"
    fi

else
    echo "[ SAFE ] 점검 결과 : 안전 (DNS 서비스가 실행 중이지 않습니다.)"
fi


# [U-53] FTP 서비스 정보 노출 제한
echo ""
echo "--------------------------------------------------"
echo "[ U-53 ] FTP 서비스 정보 노출 제한 (중요도: 하)"
echo "--------------------------------------------------"

counter=0
vsftpd_conf=("/etc/vsftpd.conf" "/etc/vsftpd/vsftpd.conf")
for file in "${vsftpd_conf[@]}"; do
    if [[ -f "${file}" ]]; then
        temp=$(grep -Ei '^\s*ftpd_banner\s*=' "${file}" | grep -Ev '^\s*#' | wc -l)
        if [[ "${temp}" -eq 0 ]]; then
            ((counter++))
            echo "[ WARNING ] vsFTPd: ${file}에 ftpd_banner 설정이 존재하지 않습니다."
        fi
    fi
done

# check ProFTPd banner 
proftpd_conf=(
    "/etc/proftpd.conf" "/etc/proftpd/proftpd.conf"
)

for file in "${proftpd_conf[@]}"; do
    if [[ -f "${file}" ]]; then
        temp=$(grep -Ei '^\s*ServerIdent\s+' "${file}" | grep -Ev '^\s*#' | wc -l)
        if [[ "${temp}" -eq 0 ]]; then
            ((counter++))
            echo "[ WARNING ] ProFTPd: ${file}에 ServerIdent 설정이 존재하지 않습니다."
        fi
    fi
done

[ ${counter} -eq 0 ] && echo "[ SAFE ] 점검 결과 : 안전"


# [U-54] 암호화되지 않는 FTP 서비스 비활성화
echo ""
echo "--------------------------------------------------"
echo "[ U-54 ] 암호화되지 않는 FTP 서비스 비활성화 (중요도: 중)"
echo "--------------------------------------------------"

ftp_active=false

# 1. inetd 기반 FTP 점검
if [[ -f "/etc/inetd.conf" ]]; then
    if grep -Ei '^\s*ftp\s+' /etc/inetd.conf | grep -vEv '^\s*#' >/dev/null 2>&1; then
        ftp_active=true
    fi
fi

# 2. xinetd 기반 FTP 점검
if [[ -f "/etc/xinetd.d/ftp" ]]; then
    if grep -Ei '^\s*disable\s*=\s*no' /etc/xinetd.d/ftp | grep -vEv '^\s*#' >/dev/null 2>&1; then
        ftp_active=true
    fi
fi

# 3. 독립 실행형 FTP (vsftpd, proftpd) 점검
if systemctl is-active --quiet vsftpd 2>/dev/null || systemctl is-active --quiet proftpd 2>/dev/null; then
    ftp_active=true
fi

# 4. 일반적인 ftpd 서비스 이름들 추가 점검 (선택 사항)
if systemctl is-active --quiet pure-ftpd 2>/dev/null || systemctl is-active --quiet ftpd 2>/dev/null; then
    ftp_active=true
fi

# 최종 결과 판단
if [[ "${ftp_active}" == true ]]; then
    echo "[ WARNING ] 암호화되지 않은 일반 FTP 서비스가 동작 중입니다."
    echo " >> 조치 권고: FTP 서비스를 중지하고 SFTP(SSH) 또는 FTPS 사용을 권장합니다."
else
    echo "[ SAFE ] 점검 결과 : 안전 (일반 FTP 서비스가 활성화되어 있지 않습니다.)"
fi


# [U-55] FTP 계정 shell 제한
echo ""
echo "--------------------------------------------------"
echo "[ U-55 ] FTP 계정 shell 제한 (중요도: 중)"
echo "--------------------------------------------------"

ftp_entry=$(grep -E '^ftp:' /etc/passwd)

if [[ -z "${ftp_entry}" ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    ftp_shell=$(echo "${ftp_entry}" | awk -F':' '{print $7}')
    if [[ "${ftp_shell}" != "/bin/false" && "${ftp_shell}" != "/sbin/nologin" ]]; then
        echo "[ WARNING ] ftp 계정에 안전하지 않은 로그인 쉘이 설정되어 있습니다. (${ftp_shell})"
    else
        echo "[ SAFE ] 점검 결과 : 안전"
    fi
fi


# [U-56] FTP 서비스 접근 제어 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-56 ] FTP 서비스 접근 제어 설정 (중요도: 중)"
echo "--------------------------------------------------"

ftp_active=false
ftp_control=false

# check FTP active
if systemctl is-active --quiet vsftpd || systemctl is-active --quiet proftpd; then
    ftp_active=true
fi

# ftpusers
for file in /etc/ftpusers /etc/ftpd/ftpusers; do
    if [[ -f "${file}" ]]; then
        owner=$(stat -c "%U" "${file}")
        perm=$(stat -c "%a" "${file}")
        line_cnt=$(grep -Ev '^\s*#|^\s*$' "${file}" | wc -l)

        if [[ "${owner}" == "root" && "${perm}" -le 640 && "${line_cnt}" -gt 0 ]]; then
            ftp_control=true
        fi
    fi
done

# vsftpd
for list in /etc/vsftpd/user_list /etc/vsftpd.user_list /etc/vsftpd/ftpusers /etc/vsftpd.ftpusers; do
    if [[ -f "${list}" ]]; then
        owner=$(stat -c "%U" "${list}")
        perm=$(stat -c "%a" "${list}")
        line_cnt=$(grep -Ev '^\s*#|^\s*$' "${list}" | wc -l)

        if [[ "${owner}" == "root" && "${perm}" -le 640 && "${line_cnt}" -gt 0 ]]; then
            ftp_control=true
        fi
    fi
done

# proftpd
for conf in /etc/proftpd.conf /etc/proftpd/proftpd.conf; do
    if [[ -f "${conf}" ]]; then
        use_ftpusers=$(grep -Ei '^\s*UseFtpUsers\s+' "${conf}" | awk '{print tolower($2)}')
        if [[ "${use_ftpusers}" == "on" ]]; then
            for file in /etc/ftpusers /etc/ftpd/ftpusers; do
                if [[ -f "${file}" ]]; then
                    owner=$(stat -c "%U" "${file}")
                    perm=$(stat -c "%a" "${file}")
                    line_cnt=$(grep -Ev '^\s*#|^\s*$' "${file}" | wc -l)

                    if [[ "${owner}" == "root" && "${perm}" -le 640 && "${line_cnt}" -gt 0 ]]; then
                        ftp_control=true
                    fi
                fi
            done
        fi
    fi
done

if [[ "${ftp_active}" == false || "${ftp_control}" == true ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo "[ WARNING ] FTP 서비스 접근 제어 설정이 적용되어 있지 않습니다."
fi


# [U-57] Ftpusers 파일 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-57 ] Ftpusers 파일 설정 (중요도: 중)"
echo "--------------------------------------------------"

root_blocked=false

# ftpusers
for file in /etc/ftpusers /etc/ftpd/ftpusers; do
    if [[ -f "${file}" ]]; then
        if grep -Ev '^\s*#|^\s*$' "${file}" | grep -qx "root"; then
            root_blocked=true
        fi
    fi
done

# vsftpd
for list in /etc/vsftpd/user_list /etc/vsftpd.user_list /etc/vsftpd/ftpusers /etc/vsftpd.ftpusers; do
    if [[ -f "${list}" ]]; then
        if grep -Ev '^\s*#|^\s*$' "${list}" | grep -qx "root"; then
            root_blocked=true
        fi
    fi
done

# proftpd (RootLogin off)
for conf in /etc/proftpd.conf /etc/proftpd/proftpd.conf; do
    if [[ -f "${conf}" ]]; then
        rootlogin=$(grep -Ei '^\s*RootLogin\s+' "${conf}" | awk '{print tolower($2)}')
        if [[ "${rootlogin}" == "off" ]]; then
            root_blocked=true
        fi
    fi
done

if [[ "${ftp_active}" == false ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
elif [[ "${root_blocked}" == true ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo "[ WARNING ] FTP 서비스에서 root 계정 접근이 차단되어 있지 않습니다."
fi


# [U-58] 불필요한 SNMP 서비스 구동 점검
echo ""
echo "--------------------------------------------------"
echo "[ U-58 ] 불필요한 SNMP 서비스 구동 점검 (중요도: 중)"
echo "--------------------------------------------------"

snmp_active=false

# 1. snmpd 및 snmptrapd 서비스 활성화 여부 체크
# --quiet 옵션으로 출력은 숨기고 종료 코드만 확인합니다.
if systemctl is-active --quiet snmpd 2>/dev/null || systemctl is-active --quiet snmptrapd 2>/dev/null; then
    echo "[ WARNING ] SNMP 서비스(snmpd 또는 snmptrapd)가 활성화 상태입니다."
    snmp_active=true
    
    # 추가 정보 제공: 실제 사용 중인지 관리자에게 확인 유도
    echo " >> 조치 권고: SNMP 서비스가 불필요한 경우 'systemctl stop/disable' 처리가 필요합니다."
    echo " >> 참고: SNMP를 반드시 사용해야 한다면 커뮤니티 스트링(U-59) 설정을 점검하십시오."
else
    echo "[ SAFE ] 점검 결과 : 안전 (SNMP 서비스가 비활성화되어 있습니다.)"
    snmp_active=false
fi


# [U-59] 안전한 SNMP 버전 사용
echo ""
echo "--------------------------------------------------"
echo "[ U-59 ] 안전한 SNMP 버전 사용 (중요도: 상)"
echo "--------------------------------------------------"

snmp_v3=false
snmp_conf="/etc/snmp/snmpd.conf"

# 1. SNMP 서비스가 비활성화된 경우 안전
if [[ "${snmp_active}" == false ]]; then
    echo "[ SAFE ] 점검 결과 : 안전 (SNMP 서비스가 비활성화되어 있습니다.)"
else
    if [[ -f "${snmp_conf}" ]]; then
        # [수정] 취약한 버전(v1, v2c)의 설정이 존재하는지 확인 (rocommunity, rwcommunity 등)
        # v1, v2c 설정이 주석 없이 살아 있다면 취약한 것으로 간주합니다.
        insecure_ver=$(grep -Ev '^\s*#|^\s*$' "${snmp_conf}" | grep -Ei '^\s*(rocommunity|rwcommunity|com2sec)\s+' | wc -l)

        # [기본] SNMPv3 관련 설정 확인
        v3_user_cnt=$(grep -Ev '^\s*#|^\s*$' "${snmp_conf}" | grep -Ei '^\s*createUser\s+' | wc -l)
        v3_access_cnt=$(grep -Ev '^\s*#|^\s*$' "${snmp_conf}" | grep -Ei '^\s*(rouser|rwuser)\s+' | wc -l)

        # 판정 논리: v1/v2c 설정이 없고, v3 설정이 정상적으로 존재하는 경우만 SAFE
        if [[ "${insecure_ver}" -eq 0 && "${v3_user_cnt}" -gt 0 && "${v3_access_cnt}" -gt 0 ]]; then
            echo "[ SAFE ] 점검 결과 : 안전 (SNMPv3가 안전하게 설정되어 있습니다.)"
            snmp_v3=true
        elif [[ "${insecure_ver}" -gt 0 ]]; then
            echo "[ WARNING ] 취약한 SNMP 버전(v1, v2c) 설정이 발견되었습니다."
            echo " >> 조치 권고: rocommunity/rwcommunity 설정을 제거하고 SNMPv3 사용을 권장합니다."
            snmp_v3=false
        else
            echo "[ WARNING ] SNMPv3 사용을 위한 사용자 또는 권한 설정이 부족합니다."
            snmp_v3=false
        fi
    else
        echo "[ WARNING ] SNMP 설정 파일(${snmp_conf})을 찾을 수 없습니다."
    fi
fi


# [U-60] SNMP Community String 복잡성 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-60 ] SNMP Community String 복잡성 설정 (중요도: 중)"
echo "--------------------------------------------------"

# 1. SNMP가 비활성화되어 있거나 이미 안전한 v3를 사용 중이면 안전
if [[ "${snmp_active}" == false || "${snmp_v3}" == true ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    snmp_conf="/etc/snmp/snmpd.conf"
    
    if [[ -f "${snmp_conf}" ]]; then
        # [수정] com2sec 외에 rocommunity, rwcommunity 설정도 모두 추출
        # 주석(#) 제외 후 4번째 또는 2번째 필드에서 스트링 추출
        communities=$(grep -Ev '^\s*#|^\s*$' "${snmp_conf}" | grep -Ei '^\s*(com2sec|rocommunity|rwcommunity)\s+' | awk '{
            if($1 ~ /com2sec/i) print $4;
            else print $2;
        }')

        weak_found=0
        
        # 발견된 모든 커뮤니티 스트링에 대해 루프 점검
        for community in ${communities}; do
            # 기본값(public, private) 체크 및 복잡성 체크
            # 규칙: (10자 이상 + 영문/숫자 조합) OR (8자 이상 + 영문/숫자/특수문자 조합)
            if [[ "${community}" == "public" || "${community}" == "private" ]]; then
                ((weak_found++))
                echo "[ WARNING ] 기본 커뮤니티 스트링이 사용 중입니다: ${community}"
            elif ! (
                ([[ ${#community} -ge 10 ]] && [[ "${community}" =~ [A-Za-z] ]] && [[ "${community}" =~ [0-9] ]]) ||
                ([[ ${#community} -ge 8  ]] && [[ "${community}" =~ [A-Za-z] ]] && [[ "${community}" =~ [0-9] ]] && [[ "${community}" =~ [^A-Za-z0-9] ]])
            ); then
                ((weak_found++))
                echo "[ WARNING ] 복잡성 규칙 미준수 스트링 발견: ${community}"
            fi
        done

        if [[ ${weak_found} -gt 0 ]]; then
            echo "[ WARNING ] SNMPv1/v2 Community String 설정이 취약합니다."
        else
            echo "[ SAFE ] 점검 결과 : 안전"
        fi
    else
        echo "[ WARNING ] SNMP 설정 파일(${snmp_conf})이 존재하지 않습니다."
    fi
fi

# [U-61] SNMP Access Control 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-61 ] SNMP Access Control 설정 (중요도: 상)"
echo "--------------------------------------------------"

# 1. SNMP 서비스가 비활성화된 경우 안전
if [[ "${snmp_active}" == false ]]; then
    echo "[ SAFE ] 점검 결과 : 안전 (SNMP 서비스가 비활성화되어 있습니다.)"
else
    snmp_conf="/etc/snmp/snmpd.conf"
    
    if [[ -f "${snmp_conf}" ]]; then
        # [수정] 접근 제어 설정 라인 추출 (com2sec, rocommunity, rwcommunity)
        # 주석(#) 제외 후 소스 주소(Source) 부분을 확인
        access_list=$(grep -Ev '^\s*#|^\s*$' "${snmp_conf}" | grep -Ei '^\s*(com2sec|rocommunity|rwcommunity)\s+')

        if [[ -z "${access_list}" ]]; then
            echo "[ WARNING ] SNMP 접근 제어 설정이 존재하지 않습니다."
        else
            # [논리] 설정 중 소스 주소가 'default'로 된 것이 있는지 확인
            # default는 모든 호스트의 접속을 허용하므로 취약으로 간주
            insecure_access=$(echo "${access_list}" | grep -Ei '\s+default\s+' | wc -l)

            if [[ "${insecure_access}" -gt 0 ]]; then
                echo "[ WARNING ] 모든 호스트(default)로부터의 SNMP 접속이 허용되어 있습니다."
                echo " >> 조치 권고: 'default' 대신 특정 관리자 IP 또는 네트워크 대역으로 제한하십시오."
            else
                echo "[ SAFE ] 점검 결과 : 안전 (접근 제어 설정이 적용되어 있습니다.)"
            fi
        fi
    else
        echo "[ WARNING ] SNMP 설정 파일(${snmp_conf})이 존재하지 않습니다."
    fi
fi

# [U-62] 로그인 시 경고 메시지 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-62 ] 로그인 시 경고 메시지 설정 (중요도: 하)"
echo "--------------------------------------------------"

counter=0

# 1. 시스템 로컬 로그온 배너 점검 (/etc/motd, issue, issue.net)
server_conf=("/etc/motd" "/etc/issue" "/etc/issue.net")
for file in "${server_conf[@]}"; do
    if [[ -f "${file}" ]]; then
        # 주석 및 공백 제외 내용이 있는지 확인
        content_cnt=$(grep -Ev '^\s*#|^\s*$' "${file}" | wc -l)
        if [[ "${content_cnt}" -eq 0 ]]; then
            ((counter++))
            echo "[ WARNING ] ${file}: 파일이 비어있거나 경고 메시지가 설정되어 있지 않습니다."
        fi
    fi
done

# 2. SSH 서비스 배너 점검
ssh_conf="/etc/ssh/sshd_config"
if [[ -f "${ssh_conf}" ]]; then
    # Banner 경로 설정 확인
    banner_path=$(grep -iE '^\s*Banner\s+' "${ssh_conf}" | grep -vE '^\s*#' | awk '{print $2}')
    
    if [[ -z "${banner_path}" || "${banner_path,,}" == "none" ]]; then
        ((counter++))
        echo "[ WARNING ] ${ssh_conf}: Banner 설정이 누락되었거나 none입니다."
    elif [[ ! -f "${banner_path}" ]]; then
        ((counter++))
        echo "[ WARNING ] ${ssh_conf}: 설정된 배너 파일(${banner_path})이 존재하지 않습니다."
    else
        # 배너 파일 내용 확인
        if [[ $(grep -Ev '^\s*#|^\s*$' "${banner_path}" | wc -l) -eq 0 ]]; then
            ((counter++))
            echo "[ WARNING ] SSH 배너 파일(${banner_path})의 내용이 비어있습니다."
        fi
    fi
fi

# 3. 메일 서비스 점검 (Sendmail/Postfix)
# Sendmail
sendmail_conf="/etc/mail/sendmail.cf"
if [[ -f "${sendmail_conf}" ]]; then
    if ! grep -qiE '^\s*O\s+SmtpGreetingMessage\s*=' "${sendmail_conf}"; then
        ((counter++))
        echo "[ WARNING ] Sendmail: SMTP 경고 메시지 설정이 누락되었습니다."
    fi
fi
# Postfix
postfix_conf="/etc/postfix/main.cf"
if [[ -f "${postfix_conf}" ]]; then
    if ! grep -qiE '^\s*smtpd_banner\s*=' "${postfix_conf}"; then
        ((counter++))
        echo "[ WARNING ] Postfix: smtpd_banner 설정이 누락되었습니다."
    fi
fi

# 4. FTP 서비스 점검 (vsftpd)
vsftpd_conf=("/etc/vsftpd.conf" "/etc/vsftpd/vsftpd.conf")
for file in "${vsftpd_conf[@]}"; do
    if [[ -f "${file}" ]]; then
        if ! grep -qiE '^\s*ftpd_banner\s*=' "${file}"; then
            ((counter++))
            echo "[ WARNING ] vsFTPd: FTP 로그온 배너 설정이 누락되었습니다. (${file})"
        fi
    fi
done

# 5. DNS 서비스 버전 정보 은폐 점검 (BIND)
dns_conf=("/etc/named.conf" "/etc/bind/named.conf.options")
for file in "${dns_conf[@]}"; do
    if [[ -f "${file}" ]]; then
        # version "none" 또는 "unknown" 등 임의 문자열로 가려져 있는지 확인
        if ! grep -qiE '^\s*version\s+\".*\";' "${file}"; then
            ((counter++))
            echo "[ WARNING ] DNS: ${file}에서 버전 정보 은폐 설정(version)이 누락되었습니다."
        fi
    fi
done

# 최종 결과 출력
if [[ "${counter}" -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-63] sudo 명령어 접근 관리
echo ""
echo "--------------------------------------------------"
echo "[ U-63 ] sudo 명령어 접근 관리 (중요도: 중)"
echo "--------------------------------------------------"

counter=0

mapfile -t bad_sudo_files < <(find /etc/sudoers /etc/sudoers.d -type f \( ! -user root -o -perm /022 -o -perm /111 \) 2>/dev/null)

if [[ ${#bad_sudo_files[@]} -gt 0 ]]; then
    for file in "${bad_sudo_files[@]}"; do
        if [[ -n "${file}" ]]; then
            ((counter++))
            echo "[ WARNING ] 부적절한 권한 설정 발견: ${file}"
            ls -l "${file}"
        fi
    done
fi

if [[ ${counter} -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전 (sudo 설정 파일의 소유자 및 권한이 적절합니다.)"
else
    echo "[ WARNING ] 총 ${counter}개의 sudo 설정 파일에 대한 보안 조치가 필요합니다."
    echo " >> 권장 설정: 소유자 root, 권한 0440 (또는 0640)"
fi
