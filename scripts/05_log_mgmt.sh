#!/bin/bash

# [U-65] NTP 및 시각 동기화 설정
echo "--------------------------------------------------"
echo "[ U-65 ] NTP 및 시각 동기화 설정 (중요도: 중)"
echo "--------------------------------------------------"

counter=0

check_chronyd=$(systemctl is-active chronyd.service 2>/dev/null)

if [[ ${check_chronyd} == "active" ]]; then
    sync=$(chronyc sources 2>/dev/null | grep -c "^\*")
    config=$(grep -Eic "^\s*(server|pool)\s+" /etc/chrony.conf)

    if [[ ${config} -eq 0 ]]; then
        echo "[ WARNING ] /etc/chrony.conf에서 동기화 서버 설정이 누락되었습니다."
    elif [[ ${sync} -eq 0 ]]; then
        echo "[ WARNING ] Chrony 서비스가 동작 중이나 외부 서버와 동기화되지 않았습니다."
    else
        echo "[ SAFE ] 점검 결과 : 안전"
    fi
else
    # [보완] NTP가 꺼져 있는 것은 보안상 취약(로그 시간 무결성 때문)이므로 경고 권장
    echo "[ WARNING ] NTP 서비스(chronyd)가 비활성화되어 있습니다."
fi


# [U-66] 정책에 따른 시스템 로깅 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-66 ] 정책에 따른 시스템 로깅 설정 (중요도: 중)"
echo "--------------------------------------------------"


counter=0

file_loop=("/etc/rsyslog.conf" "/etc/rsyslog.d/default.conf")

log_key=(
    "\*\.info;mail\.none;authpriv\.none;cron\.none" 
    "auth,authpriv\.\*" 
    "mail\.\*" 
    "cron\.\*" 
    "\*\.alert" 
    "\*\.emerg"
)

log_value=(
    "/var/log/messages"
    "/var/log/secure"
    "/var/log/maillog"
    "/var/log/cron"
    "/dev/console"
    "*"
)

for file in "${file_loop[@]}"; do
    if [[ -f ${file} ]]; then
        for ((i=0; i<${#log_key[@]}; i++)); do
            temp=$(grep -iE "^\s*${log_key[i]}\s+" "${file}" | awk '{print $2}' | xargs)
            
            if [[ -z ${temp} || ${temp} != ${log_value[i]} ]]; then
                ((counter++))
                clean_key=${log_key[i]//\\/}
                echo "[ WARNING ] ${file}에서 '${clean_key}' 설정이 누락되었거나 '${log_value[i]}'가 아닙니다."
            fi
        done
    fi
done

[ ${counter} -eq 0 ] && echo "[ SAFE ] 점검 결과 : 안전"


# [U-67] 로그 디렉터리 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-67 ] 로그 디렉터리 소유자 및 권한 설정 (중요도: 중)"
echo "--------------------------------------------------"

counter=0

mapfile -t check_file < <(find /var/log -xdev -type f \( ! -user root -o -perm /111 -o -perm /022 \) 2>/dev/null)

for logfile in "${check_file[@]}"; do
    if [[ -n "${logfile}" ]]; then
        ((counter++))
        echo "[ WARNING ] ${logfile}의 소유자(root 아님) 또는 권한(실행/쓰기 권한 과다)이 잘못되었습니다."
    fi
done

if [[ ${counter} -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi

