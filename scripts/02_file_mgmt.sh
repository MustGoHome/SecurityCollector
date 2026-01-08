#!/bin/bash

# [U-14] root 홈 및 PATH 디렉터리 권한·환경변수 설정(verify)
echo "--------------------------------------------------"
echo "[ U-14 ] root 홈 및 PATH 디렉터리 권한·환경변수 설정 (중요도: 상)"
echo "--------------------------------------------------"

counter=0

temp_runtime=$(echo $PATH | grep -iEc "(^|:)(\.|\s*)(:|$)|::")

if [[ ${temp_runtime} -ne 0 ]]; then
    ((counter++))
    echo "[ WARNING ] 현재 시스템의 PATH 환경변수에 '.' 또는 빈 경로(::)가 포함되어 있습니다."
fi

file_key=("/etc/profile" "${HOME}/.bash_profile" "${HOME}/.bashrc" "/etc/bash.bashrc")

for ((i=0; i<${#file_key[@]}; i++)); do
    if [[ -f "${file_key[i]}" ]]; then
        temp_file=$(grep -iE "^\s*(export\s+)?PATH\s*=" "${file_key[i]}" | grep -iEc "(^|:)(\.|\s*)(:|$)|::")
        if [[ ${temp_file} -ne 0 ]]; then
            ((counter++))
            echo "[ WARNING ] ${file_key[i]} 파일 내 PATH 설정에 취약점이 발견되었습니다."
        fi
    fi
done

[ ${counter} -eq 0 ] && echo "[ SAFE ] 점검 결과 : 안전"


# [U-15] 파일 및 디렉터리 소유자 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-15 ] 파일 및 디렉터리 소유자 설정"
echo "--------------------------------------------------"

counter=0

mapfile -t temp_unowned < <(find / -xdev \( -nouser -o -nogroup \) -print 2>/dev/null)

if [[ ${#temp_unowned[@]} -gt 0 ]]; then
    for file in "${temp_unowned[@]}"; do
        if [[ -n "$file" ]]; then
            ((counter++))
            echo "[ WARNING ] 소유자/그룹이 없는 파일 발견: $file"
        fi
    done
fi

[ ${counter} -eq 0 ] && echo "[ SAFE ] 점검 결과 : 안전"


# [U-16] /etc/passwd 파일 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-16 ] /etc/passwd 파일 소유자 및 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

temp=$(find /etc/passwd \( ! -user root -o -perm /111 -o -perm /022 \))

if [[ -n ${temp} ]]; then
    echo "[ WARNING ] /etc/passwd의 소유자 및 권한이 잘못되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-17] 시스템 시작 스크립트 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-17 ] 시스템 시작 스크립트 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

counter=0

mapfile -t check_systemd < <(find /usr/lib/systemd/system -type f -name "*.service" -perm /002)

for ((i=0; i<${#check_systemd[@]}; i++)); do
    ((counter++))
    echo "[ WARNING ] ${check_systemd[i]}의 권한이 취약합니다 (Other Write)."
done

[ ${counter} -eq 0 ] && echo "[ SAFE ] 점검 결과 : 안전"


# [U-18] /etc/shadow 파일 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-18 ] /etc/shadow 파일 소유자 및 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

temp=$(find /etc/shadow \( ! -user root -o -perm /377 \))

if [[ -n ${temp} ]]; then
    echo "[ WARNING ] /etc/shadow의 소유자 및 권한이 잘못되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-19] /etc/shadow 파일 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-19 ] /etc/hosts 파일 소유자 및 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

temp=$(find /etc/hosts \( ! -user root -o -perm /133 \))

if [[ -n ${temp} ]]; then
    echo "[ WARNING ] /etc/hosts의 소유자 및 권한이 잘못되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-20] /etc/(x)inetd.conf 파일 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-20 ] /etc/(x)inetd.conf 파일 소유자 및 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

counter=0

mapfile -t check_systemd_conf < <(find /etc/systemd -type f \( ! -user root -o -perm /177 \) 2>/dev/null)

for ((i=0; i<${#check_systemd_conf[@]}; i++)); do
    ((counter++))
    echo "[ WARNING ] ${check_systemd_conf[i]}의 소유자 및 권한이 잘못되었습니다."
done

[ ${counter} -eq 0 ] && echo "[ SAFE ] 점검 결과 : 안전"


# [U-21] /etc/(r)syslog.conf 파일 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-21 ] /etc/(r)syslog.conf 파일 소유자 및 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

temp=$(find /etc/rsyslog.conf \( \( ! -user root -a ! -user bin \) -o -perm /137 \) 2>/dev/null)

if [[ -n ${temp} ]]; then
    echo "[ WARNING ] /etc/rsyslog.conf의 소유자 및 권한이 잘못되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-22] /etc/services 파일 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-22 ] /etc/services 파일 소유자 및 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

# check /etc/services
temp=$(find /etc/services \( \( ! -user root -a ! -user bin \) -o -perm /133 \))

if [[ -n ${temp} ]]; then
    echo "[ WARNING ] /etc/services의 소유자 및 권한이 잘못되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-23] SUID, SGID, Sticky Bit 설정 파일 점검
echo ""
echo "--------------------------------------------------"
echo "[ U-23 ] SUID, SGID, Sticky Bit 설정 파일 점검 (중요도: 상)"
echo "--------------------------------------------------"

counter=0

mapfile -t check_special < <(find / -xdev -user root -type f \( -perm -04000 -o -perm -02000 \) 2>/dev/null)

for ((i=0; i<${#check_special[@]}; i++)); do
    ((counter++))
    echo "[ WARNING ] ${check_special[i]}에 특수권한이 설정되어 있습니다."
done

[ ${counter} -eq 0 ] && echo "[ SAFE ] 점검 결과 : 안전"


# [U-24] 사용자 및 시스템 환경변수 파일 소유자·권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-24 ] 사용자 및 시스템 환경변수 파일 소유자·권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

counter=0

check_user=$(awk -F: '$3 == 0 || $3 >= 1000 {print $1 ":" $6}' /etc/passwd | grep -v "/$")
check_env=(".bash_profile" ".bashrc")

for user in ${check_user}; do
    user_name=$(echo ${user} | cut -d: -f1)
    user_home=$(echo ${user} | cut -d: -f2)

    if [[ -d "${user_home}" ]]; then
        for file in "${check_env[@]}"; do
            path="${user_home}/${file}"

            if [[ -f "$path" ]]; then
                temp=$(find "${path}" -maxdepth 0 \( \( ! -user root -a ! -user "${user_name}" \) -o -perm /022 \))

                if [[ -n ${temp} ]]; then
                    ((counter++))
                    echo "[ WARNING ] ${path}의 소유자 및 권한이 잘못되었습니다."
                fi
            fi
        done
    fi
done

[ ${counter} -eq 0 ] && echo "[ SAFE ] 점검 결과 : 안전"


# [U-25] 사용자 및 시스템 환경변수 파일 소유자·권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-25 ] World Writable 파일 점검 (중요도: 상)"
echo "--------------------------------------------------"

counter=0

mapfile -t check_ww < <(find / -xdev \( -path "/proc" -o -path "/sys" -o -path "/run" \) -prune -o -type f -perm -2 -print 2>/dev/null)
for ((i=0; i<${#check_ww[@]}; i++)); do
    if [[ -f "${check_ww[i]}" ]]; then
        ((counter++))
        echo "[ WARNING ] ${check_ww[i]}에 World Writable 설정이 있습니다."
    fi
done

[ ${counter} -eq 0 ] && echo "[ SAFE ] 점검 결과 : 안전"


# [U-26] 사용자 및 시스템 환경변수 파일 소유자·권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-26 ] /dev 내 불필요한 Device 파일 점검 (중요도: 상)"
echo "--------------------------------------------------"

counter=0

mapfile -t check_dev < <(find /dev -type f 2>/dev/null)
for ((i=0; i<${#check_dev[@]}; i++)); do
    ((counter++))
    echo "[ WARNING ] ${check_dev[i]} 일반 파일이 발견되었습니다."
done

[ ${counter} -eq 0 ] && echo "[ SAFE ] 점검 결과 : 안전"


# [U-27] $HOME/.rhosts, hosts.equiv 사용 금지
echo ""
echo "--------------------------------------------------"
echo "[ U-27 ] \$HOME/.rhosts, hosts.equiv 사용 금지 (중요도: 상)"
echo "--------------------------------------------------"

counter=0

check_user=$(awk -F: '$3 == 0 || $3 >= 1000 {print $1 ":" $6}' /etc/passwd | grep -v "/$")

if [[ -f "/etc/hosts.equiv" ]]; then
    bad_perm_equiv=$(find /etc/hosts.equiv \( ! -user root -o -perm /177 \) 2>/dev/null)
    
    bad_content_equiv=$(grep "+" /etc/hosts.equiv 2>/dev/null)

    if [[ -n "${bad_perm_equiv}" || -n "${bad_content_equiv}" ]]; then
        ((counter++))
        echo "[ WARNING ] /etc/hosts.equiv 파일이 취약하게 설정되어 있습니다."
        [[ -n "${bad_content_equiv}" ]] && echo " >> 사유: '+' 설정(모든 접속 허용) 발견"
        ls -l /etc/hosts.equiv
    fi
fi

for user in ${check_user}; do
    u_name=$(echo ${user} | cut -d: -f1)
    u_home=$(echo ${user} | cut -d: -f2)

    if [[ -d "${u_home}" ]]; then
        rhosts_path="${u_home}/.rhosts"

        if [[ -f "${rhosts_path}" ]]; then
            bad_perm_rhosts=$(find "${rhosts_path}" -maxdepth 0 \( \( ! -user root -a ! -user "${u_name}" \) -o -perm /177 \) 2>/dev/null)
            bad_content_rhosts=$(grep "+" "${rhosts_path}" 2>/dev/null)

            if [[ -n "${bad_perm_rhosts}" || -n "${bad_content_rhosts}" ]]; then
                ((counter++))
                echo "[ WARNING ] ${u_name} 계정의 .rhosts 파일이 취약합니다."
                [[ -n "${bad_content_rhosts}" ]] && echo " >> 사유: 소유자/권한 부적절 또는 '+' 설정 발견"
                ls -l "${rhosts_path}"
            fi
        fi
    fi
done

if [[ ${counter} -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-28] 접속 IP 및 포트 접근 제한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-28 ] 접속 IP 및 포트 접근 제한 설정 (중요도: 상)"
echo "--------------------------------------------------"
echo "[ SAFE ] 점검 결과 : 사용자 정의"


# [U-29] hosts.lpd 파일 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-29 ] hosts.lpd 파일 소유자 및 권한 설정 (중요도: 하)"
echo "--------------------------------------------------"

counter=0

if [[ -f "/etc/hosts.lpd" ]]; then
    temp=$(find /etc/hosts.lpd \( ! -user root -o -perm /177 \) 2>/dev/null)

    if [[ -n "${temp}" ]]; then
        ((counter++))
        echo "[ WARNING ] /etc/hosts.lpd 파일의 소유자 또는 권한 설정이 취약합니다."
        ls -l /etc/hosts.lpd
    fi
fi

if [[ ${counter} -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-30] UMASK 설정 관리
echo ""
echo "--------------------------------------------------"
echo "[ U-30 ] UMASK 설정 관리 (중요도: 중)"
echo "--------------------------------------------------"

counter=0

global_files=("/etc/profile" "/etc/bashrc" "/etc/login.defs")

check_user=$(awk -F: '$3 == 0 || $3 >= 1000 {print $1 ":" $6}' /etc/passwd | grep -v "/$")
user_env_files=(".bash_profile" ".bashrc" ".profile" ".login" ".cshrc")

for file in "${global_files[@]}"; do
    if [[ -f "${file}" ]]; then
        umask_val=$(grep -iE "^\s*umask\s+" "${file}" | awk '{print $2}' | tail -n 1 | xargs)

        if [[ -n "${umask_val}" ]]; then
            if [[ $((8#${umask_val})) -lt $((8#022)) ]]; then
                ((counter++))
                echo "[ WARNING ] ${file}의 UMASK 설정이 취약합니다. (현재: ${umask_val})"
            fi
        fi
    fi
done


for user in ${check_user}; do
    u_name=$(echo ${user} | cut -d: -f1)
    u_home=$(echo ${user} | cut -d: -f2)

    if [[ -d "${u_home}" ]]; then
        for env_file in "${user_env_files[@]}"; do
            path="${u_home}/${env_file}"
            if [[ -f "${path}" ]]; then
                u_umask=$(grep -iE "^\s*umask\s+" "${path}" | awk '{print $2}' | tail -n 1 | xargs)
                
                if [[ -n "${u_umask}" ]]; then
                    if [[ $((8#${u_umask})) -lt $((8#022)) ]]; then
                        ((counter++))
                        echo "[ WARNING ] ${u_name} 계정의 ${env_file} UMASK 설정이 취약합니다. (현재: ${u_umask})"
                    fi
                fi
            fi
        done
    fi
done

if [[ ${counter} -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-31] 홈 디렉터리 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-31 ] 홈 디렉터리 소유자 및 권한 설정 (중요도: 중)"
echo "--------------------------------------------------"

counter=0

check_user=$(awk -F: '$3 == 0 || $3 >= 1000 {print $1 ":" $6}' /etc/passwd | grep -v "/$")

for user in ${check_user}; do
    user_name=$(echo ${user} | cut -d: -f1)
    user_home=$(echo ${user} | cut -d: -f2)

    if [[ -d "${user_home}" ]]; then
        vulnerable=$(find "${user_home}" -maxdepth 0 \( ! -user "${user_name}" -o -perm /002 \) 2>/dev/null)

        if [[ -n "${vulnerable}" ]]; then
            ((counter++))
            
            current_owner=$(stat -c "%U" "${user_home}")
            current_perm=$(stat -c "%a" "${user_home}")
            
            echo "[ WARNING ] 계정: ${user_name} | 홈 디렉터리: ${user_home}"
            echo " >> 현 소유자: ${current_owner} / 현 권한: ${current_perm}"
            
            if [[ "${current_owner}" != "${user_name}" ]]; then
                echo " >> 사유: 소유자가 계정 주인과 일치하지 않습니다."
            fi
            if [[ "${current_perm:2:1}" -ge 2 ]]; then
                echo " >> 사유: 타 사용자(Other)에게 쓰기 권한이 있습니다."
            fi
        fi
    fi
done

if [[ ${counter} -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-32] 홈 디렉터리로 지정된 디렉터리 존재 여부 관리
echo ""
echo "--------------------------------------------------"
echo "[ U-32 ] 홈 디렉터리로 지정된 디렉터리 존재 여부 관리 (중요도: 중)"
echo "--------------------------------------------------"

counter=0

check_user=$(awk -F: '$3 == 0 || $3 >= 1000 {print $1 ":" $6}' /etc/passwd | grep -v "/$")

for user in ${check_user}; do
    user_name=$(echo ${user} | cut -d: -f1)
    user_home=$(echo ${user} | cut -d: -f2)

    if [[ ! -d "${user_home}" ]]; then
        ((counter++))
        echo "[ WARNING ] 계정: ${user_name} | 설정된 홈 디렉터리(${user_home})가 존재하지 않습니다."
    fi
done

if [[ ${counter} -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-33] 숨겨진 파일 및 디렉터리 검색 및 제거
echo ""
echo "--------------------------------------------------"
echo "[ U-33 ] 숨겨진 파일 및 디렉터리 검색 및 제거 (중요도: 하)"
echo "--------------------------------------------------"
echo "[ SAFE ] 점검 결과 : 사용자 정의"