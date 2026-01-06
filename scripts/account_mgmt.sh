#!/bin/bash

# [U-01] root 계정 원격 접속 제한
echo "--------------------------------------------------"
echo "[ U-01 ] root 계정 원격 접속 제한 (중요도: 상)"
echo "--------------------------------------------------"

# check /etc/ssh/sshd_config
result=$(grep -ic "^PermitRootLogin no" /etc/ssh/sshd_config)
if [ "$result" -eq 0 ]; then
    echo "[ WARNING ] /etc/ssh/sshd_config에서 PermitRootLogin no 설정이 되어 있지 않습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi
echo "--------------------------------------------------"


# [U-02] 비밀번호 관리정책 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-02 ] 비밀번호 관리정책 설정 (중요도: 상)"
echo "--------------------------------------------------"

# error counter
count=0

# check /etc/login.defs
login_keys=("PASS_MAX_DAYS" "PASS_MIN_DAYS")
login_values=(90 1) 

for ((i=0; i<${#login_keys[@]}; i++)); do
    result=$(grep -i "^${login_keys[i]}" /etc/login.defs | awk '{print $2}' | xargs)

    if [[ -z "$result" || "$result" -ne ${login_values[i]} ]]; then
        ((count++))
        echo "[ WARNING ] /etc/login.defs에서 ${login_keys[i]} 값이 ${login_values[i]} 가 아닙니다."
    fi
done

# check /etc/security/pwquality.conf
pwquality_keys=("minlen" "dcredit" "ucredit" "lcredit" "ocredit")
pwquality_values=(8 -1 -1 -1 -1)

for ((i=0; i<${#pwquality_keys[@]}; i++)); do
    result=$(grep -i "^${pwquality_keys[i]}" /etc/security/pwquality.conf | awk -F'=' '{print $2}' | xargs)

    if [[ -z "$result" || "$result" -ne ${pwquality_values[i]} ]]; then
        ((count++))
        echo "[ WARNING ] /etc/security/pwquality.conf에서 ${pwquality_keys[i]} 값이 ${pwquality_values[i]} 가 아닙니다."
    fi
done

result=$(grep -ic "^enforce_for_root" /etc/security/pwquality.conf)
if [ "$result" -eq 0 ]; then
    ((count++))
    echo "[ WARNING ] /etc/security/pwquality.conf에서 enforce_for_root 설정이 되어 있지 않습니다."
fi

# confirm pam module order
pam_pwquality_line=$(grep -in "^password" /etc/pam.d/system-auth | grep -i "pam_pwquality.so" | awk -F':' '{print $1}')
pam_pwhistory_line=$(grep -in "^password" /etc/pam.d/system-auth | grep -i "pam_pwhistory.so" | awk -F':' '{print $1}')
pam_unix_line=$(grep -in "^password" /etc/pam.d/system-auth | grep -i "pam_unix.so" | awk -F':' '{print $1}')
if [ -z "$pam_pwquality_line" ] || [ -z "$pam_pwhistory_line" ] || [ -z "$pam_unix_line" ]; then
    ((count++))
    echo "[ WARNING ] /etc/pam.d/system-auth에서 일부 모듈이 누락되어 있습니다."
elif [ "$pam_pwquality_line" -gt "$pam_unix_line" ] || [ "$pam_pwhistory_line" -gt "$pam_unix_line" ]; then
    ((count++))
    echo "[ WARNING ] /etc/pam.d/system-auth에서 모듈 순서가 잘못되었습니다."
fi

# check /etc/security/pwhistory.conf
result=$(grep -ic "^enforce_for_root" /etc/security/pwhistory.conf)
if [ "$result" -eq 0 ]; then
    ((count++))
    echo "[ WARNING ] /etc/security/pwhistory.conf에서 enforce_for_root 설정이 되어 있지 않습니다."
fi

pwhistory_keys=("remember" "file")
pwhistory_values=("4" "/etc/security/opasswd")

for ((i=0; i<${#pwhistory_keys[@]}; i++)); do
    result=$(grep -i "^${pwhistory_keys[i]}" /etc/security/pwhistory.conf | awk -F'=' '{print $2}' | xargs)

    if [ -z "$result" ] || [ "$result" != ${pwhistory_values[i]} ]; then
        ((count++))
        echo "[ WARNING ] /etc/security/pwhistory.conf에서 ${pwhistory_keys[i]} 값이 ${pwhistory_values[i]} 가 아닙니다."
    fi
done

if [ "$count" -eq 0 ]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-03] 계정 잠금 임계값 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-03 ] 계정 잠금 임계값 설정 (중요도: 상)"
echo "--------------------------------------------------"

# check authselect
result=$(authselect current | grep -ic "with-faillock")