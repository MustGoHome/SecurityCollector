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

# error counter
count=0

# check authselect
result=$(authselect current | grep -ic "with-faillock")
if [ "$result" -eq 0 ]; then
    ((count++))
    echo "[ WARNING ] with-faillock 모듈이 누락되어 있습니다."
fi

# check /etc/security/faillock.conf
result=$(grep -ic "^silent" /etc/security/faillock.conf)
if [ "$result" -eq 0 ]; then
    ((count++))
    echo "[ WARNING ] /etc/security/faillock.conf에서 silent 설정이 되어 있지 않습니다."
fi

faillock_keys=("deny" "unlock_time")
faillock_values=(10 120)

for ((i=0; i<${#faillock_keys[@]}; i++)); do
    result=$(grep -i "^${faillock_keys[i]}" /etc/security/faillock.conf | awk -F'=' '{print $2}' | xargs)

    if [ -z "$result" ] || [ "$result" != ${faillock_values[i]} ]; then
        ((count++))
        echo "[ WARNING ] /etc/security/faillock.conf에서 ${faillock_keys[i]} 값이 ${faillock_values[i]} 가 아닙니다."
    fi
done

if [ "$count" -eq 0 ]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi

# [U-04] 비밀번호 파일 보호
echo ""
echo "--------------------------------------------------"
echo "[ U-04 ] 비밀번호 파일 보호 (중요도: 상)"
echo "--------------------------------------------------"

# check /etc/passwd
result=$(cat /etc/passwd | awk -F':' '{print $2}' | grep -vic "x")
if [ "$result" -ne 0 ]; then
    echo "[ WARNING ] /etc/passwd에서 패스워드 필드 암호화 설정이 되어 있지 않습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-05] root 이외의 UID가 '0' 금지
echo ""
echo "--------------------------------------------------"
echo "[ U-05 ] root 이외의 UID가 '0' 금지 (중요도: 상)"
echo "--------------------------------------------------"

result=$(cat /etc/passwd | awk -F":" '{print $3}' | grep -ic "^0$")
if [ "$result" -ne 1 ]; then
    echo "[ WARNING ] /etc/passwd에서 루트 이외에 UID가 0인 계정이 존재합니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-06] 사용자 계정 su 기능 제한
echo ""
echo "--------------------------------------------------"
echo "[ U-06 ] 사용자 계정 su 기능 제한 (중요도: 상)"
echo "--------------------------------------------------"

perm=$(stat -c "%a" /usr/bin/su)
group=$(stat -c "%G" /usr/bin/su)

if [ "$perm" == "4750" ] && [ "$group" == "wheel" ]; then
    echo "[ WARNING ] /usr/bin/su 파일의 권한이 잘못되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-07] 불필요한 계정 제거
echo ""
echo "--------------------------------------------------"
echo "[ U-07 ] 불필요한 계정 제거 (중요도: 하)"
echo "--------------------------------------------------"
echo "[ SAFE ] 점검 결과 : 사용자 정의"


# [U-08] 관리자 그룹에 최소한의 계정 포함
echo ""
echo "--------------------------------------------------"
echo "[ U-08 ] 관리자 그룹에 최소한의 계정 포함 (중요도: 중)"
echo "--------------------------------------------------"
echo "[ SAFE ] 점검 결과 : 사용자 정의"


# [U-09] 계정이 존재하지 않는 GID 금지
echo ""
echo "--------------------------------------------------"
echo "[ U-09 ] 계정이 존재하지 않는 GID 금지 (중요도: 하)"
echo "--------------------------------------------------"
echo "[ SAFE ] 점검 결과 : 사용자 정의"


# [U-10] 동일한 UID 금지
echo ""
echo "--------------------------------------------------"
echo "[ U-10 ] 동일한 UID 금지 (중요도: 중)"
echo "--------------------------------------------------"

# check /etc/passwd
result=$(cat /etc/passwd | awk -F":" '{print $3}' | sort | uniq -d)
if [ -n "$result" ]; then
    echo "[ WARNING ] /etc/passwd에서 계정의 UID 중복이 발견되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi

# [U-11] 사용자 Shell 점검
echo ""
echo "--------------------------------------------------"
echo "[ U-11 ] 사용자 Shell 점검 (중요도: 하)"
echo "--------------------------------------------------"

# error counter
count=0

# check /etc/passwd
user_keys=("daemon" "bin" "sys" "adm" "listen" "nobody" "nobody4" "noaccess" "diag" "operator" "games" "gopher")
for ((i=0; i<${#user_keys[@]}; i++)); do
    result=$(grep -i "^${user_keys[i]}" /etc/passwd | awk -F':' '{print $7}' | xargs)

    if [ -z "$result" ] || [ "$result" != "/sbin/nologin" ]; then
        ((count++))
        echo "[ WARNING ] /etc/passwd에서 ${user_keys[i]} 계정의 쉘이 /sbin/nologin 가 아닙니다."
    fi
done

if [ "$count" -eq 0 ]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-12] 세션 종료 시간 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-12 ] 세션 종료 시간 설정 (중요도: 하)"
echo "--------------------------------------------------"

# check /etc/profile
check_tmout=$(cat /etc/profile | grep -i "^TMOUT" | awk -F"=" '{print $2}')
check_export=$(cat /etc/profile | grep -ic "^export TMOUT")
if [ -z "$check_tmout" ] || [ "$check_tmout" != "600" ] && [ "$check_export" -ne 1 ]; then
    echo "[ WARNING ] /etc/profile에서 TMOUT 설정이 되어 있지 않습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-13] 안전한 비밀번호 암호화 알고리즘 사용
echo ""
echo "--------------------------------------------------"
echo "[ U-13 ] 안전한 비밀번호 암호화 알고리즘 사용 (중요도: 중)"
echo "--------------------------------------------------"

# check /etc/login.defs
check_login=$(grep -i "^ENCRYPT_METHOD" /etc/login.defs | awk '{print $2}')
check_pam=$(grep "^password" /etc/pam.d/system-auth | grep "pam_unix.so" | awk '{print $4}' | xargs)
if [[ "$check_login" == "SHA512" || "$check_login" == "SHA256" || "$check_pam" == "sha512" || "$check_pam" == "sha256" ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo "[ WARNING ] /etc/login.defs에서 암호화 알고리즘 설정이 되어 있지 않습니다."
fi
