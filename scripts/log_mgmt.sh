#!/bin/bash

# [U-65] NTP 및 시각 동기화 설정
echo "--------------------------------------------------"
echo "[ U-65 ] NTP 및 시각 동기화 설정 (중요도: 중)"
echo "--------------------------------------------------"

# error counter
counter=0

# check chronyd
check_chronyd=$(systemctl is-active chronyd.service)

if [[ ${check_chronyd} == "active " ]]; then
    sync=$(chronyc sources | awk '{print $1}' | grep -ic "*")
    config=$(grep -Eic "^\s*server\s+" /etc/chrony.conf)

    if [[ ${sync} -eq 0 && ${config} -eq 0 ]]; then
        echo "[WARNING] /etc/chrony.config에서 설정이 누락되었습니다."
    else
        echo "[WARNING] Chrony에서 시간이 동기화되지 않았습니다."
    fi
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-66] 정책에 따른 시스템 로깅 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-66 ] 정책에 따른 시스템 로깅 설정 (중요도: 중)"
echo "--------------------------------------------------"

# error counter
counter=0

# check /etc/rsyslog.conf
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
            temp=$(grep -iE "^\s*${log_key[i]}\s+" ${file} | awk '{print $2}' | xargs)
            
            if [[ ${temp} != ${log_value[i]} ]]; then
                ((counter++))
                clean_key=${log_key[i]//\\/}
                echo "[ WARNING ] ${file}에서 ${clean_key} ${log_value[i]} 설정이 누락되었습니다."
            fi
        done
    fi
done

if [[ ${counter} -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-67] 로그 디렉터리 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-67 ] 로그 디렉터리 소유자 및 권한 설정 (중요도: 중)"
echo "--------------------------------------------------"

# error counter
counter=0

# check /var/log files owner and permission
check_file=$(find /var/log -type f \( ! -user root -o -perm /022 \))

for logfile in ${check_file}; do
    ((counter++))
    echo "[ WARNING ] ${logfile}의 소유자 및 권한이 잘못되었습니다."
done

if [[ ${counter} -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi

