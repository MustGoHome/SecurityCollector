#!/bin/bash

# [U-01] root 계정 원격 접속 제한
echo "--------------------------------------------------"
echo "[ U-01 ] root 계정 원격 접속 제한 (중요도: 상)"
echo "--------------------------------------------------"

# check /etc/ssh/sshd_config(verify)
temp=$(grep -iEc "^\s*PermitRootLogin\s+no\s*" /etc/ssh/sshd_config)

if [[ ${temp} -eq 0 ]]; then
    echo "[ WARNING ] /etc/ssh/sshd_config에서 PermitRootLogin no 설정이 누락되었습니다."
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
counter=0

# check /etc/login.defs(verify)
login_key=("PASS_MAX_DAYS" "PASS_MIN_DAYS")
login_value=("90" "1")

for ((i=0; i<${#login_key[@]}; i++)); do
    temp=$(grep -Ei "^\s*${login_key[i]}" /etc/login.defs | awk '{print $2}' | xargs)

    if [[ -z ${temp} || ${temp} != ${login_value[i]} ]]; then
        ((counter++))
        echo "[ WARNING ] /etc/login.defs에서 ${login_key[i]} = ${login_value[i]} 설정이 누락되었습니다."
    fi
done

# check /etc/security/pwquality.conf(verify)
pwquality_key=("minlen" "dcredit" "ucredit" "lcredit" "ocredit")
pwquality_value=("8" "-1" "-1" "-1" "-1")

for ((i=0; i<${#pwquality_key[@]}; i++)); do
    temp=$(grep -iE "^\s*${pwquality_key[i]}\s*=" /etc/security/pwquality.conf | awk -F'=' '{print $2}' | xargs)

    if [[ -z ${temp} || ${temp} != ${pwquality_value[i]} ]]; then
        ((counter++))
        echo "[ WARNING ] /etc/security/pwquality.conf에서 ${pwquality_key[i]} = ${pwquality_value[i]} 설정이 누락되었습니다."
    fi
done

temp=$(grep -iEc "^\s*enforce_for_root" /etc/security/pwquality.conf)

if [[ ${temp} -eq 0 ]]; then
    ((counter++))
    echo "[ WARNING ] /etc/security/pwquality.conf에서 enforce_for_root 설정이 누락되었습니다."
fi

# check /etc/pam.d/system-auth(verify)
pam_pwquality_line=$(grep -iEn "^\s*password" /etc/pam.d/system-auth | grep -i "pam_pwquality.so" | awk -F':' '{print $1}' | xargs)
pam_pwhistory_line=$(grep -iEn "^\s*password" /etc/pam.d/system-auth | grep -i "pam_pwhistory.so" | awk -F':' '{print $1}' | xargs)
pam_unix_line=$(grep -iEn "^\s*password" /etc/pam.d/system-auth | grep -i "pam_unix.so" | awk -F':' '{print $1}' | xargs)

if [[ -z ${pam_pwquality_line} || -z ${pam_pwhistory_line} || -z ${pam_unix_line} ]]; then
    ((counter++))
    echo "[ WARNING ] /etc/pam.d/system-auth에서 일부 모듈이 누락되었습니다."
elif [[ ${pam_pwquality_line} -gt ${pam_unix_line} ]] || [[ ${pam_pwhistory_line} -gt ${pam_unix_line} ]]; then
    ((counter++))
    echo "[ WARNING ] /etc/pam.d/system-auth에서 모듈 순서가 잘못되었습니다."
fi

# check /etc/security/pwhistory.conf(verify)
temp=$(grep -iEc "^\s*enforce_for_root" /etc/security/pwhistory.conf)

if [ ${temp} -eq 0 ]; then
    ((counter++))
    echo "[ WARNING ] /etc/security/pwhistory.conf에서 enforce_for_root 설정이 누락되었습니다."
fi

pwhistory_key=("remember" "file")
pwhistory_value=("4" "/etc/security/opasswd")

for ((i=0; i<${#pwhistory_key[@]}; i++)); do
    temp=$(grep -iE "^\s*${pwhistory_key[i]}\s*=" /etc/security/pwhistory.conf | awk -F'=' '{print $2}' | xargs)

    if [[ -z ${temp} ]] || [[ ${temp} != ${pwhistory_value[i]} ]]; then
        ((counter++))
        echo "[ WARNING ] /etc/security/pwhistory.conf에서 ${pwhistory_key[i]} = ${pwhistory_value[i]} 설정이 누락되었습니다."
    fi
done

if [ ${counter} -eq 0 ]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-03] 계정 잠금 임계값 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-03 ] 계정 잠금 임계값 설정 (중요도: 상)"
echo "--------------------------------------------------"

# error counter
counter=0

# check authselect(verify)
temp=$(authselect current | grep -iEc "^\s*- with-faillock")

if [[ ${temp} -eq 0 ]]; then
    ((counter++))
    echo "[ WARNING ] with-faillock 모듈이 누락되었습니다."
fi

# check /etc/security/faillock.conf(verify)
temp=$(grep -iEc "^\s*silent" /etc/security/faillock.conf)

if [[ ${temp} -eq 0 ]]; then
    ((counter++))
    echo "[ WARNING ] /etc/security/faillock.conf에서 silent 설정이 누락되었습니다."
fi

faillock_key=("deny" "unlock_time")
faillock_value=("10" "120")

for ((i=0; i<${#faillock_key[@]}; i++)); do
    temp=$(grep -iE "^\s*${faillock_key[i]}\s*=" /etc/security/faillock.conf | awk -F'=' '{print $2}' | xargs)

    if [[ -z ${temp} ]] || [[ ${temp} != ${faillock_value[i]} ]]; then
        ((counter++))
        echo "[ WARNING ] /etc/security/faillock.conf에서 ${faillock_key[i]} = ${faillock_value[i]} 설정이 누락되었습니다."
    fi
done

if [ ${counter} -eq 0 ]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-04] 비밀번호 파일 보호
echo ""
echo "--------------------------------------------------"
echo "[ U-04 ] 비밀번호 파일 보호 (중요도: 상)"
echo "--------------------------------------------------"

# check /etc/passwd(verify)
temp=$(awk -F':' '{print $2}' /etc/passwd | grep -vic "x")

if [[ ${temp} -ne 0 ]]; then
    echo "[ WARNING ] /etc/passwd에서 패스워드 필드 암호화 설정이 누락되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-05] root 이외의 UID가 '0' 금지
echo ""
echo "--------------------------------------------------"
echo "[ U-05 ] root 이외의 UID가 '0' 금지 (중요도: 상)"
echo "--------------------------------------------------"

# check /etc/passwd(verify)
temp=$(awk -F":" '{print $3}' /etc/passwd | grep -ic "^0$")

if [[ ${temp} -ne 1 ]]; then
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

if [[ ${perm} != "4750" || ${group} != "wheel" ]]; then
    echo "[ WARNING ] /usr/bin/su 파일의 권한 및 소유자 설정이 누락되었습니다."
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

# check /etc/passwd(verify)
temp=$(awk -F":" '{print $3}' /etc/passwd | sort | uniq -d)

if [[ -n ${temp} ]]; then
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
counter=0

# check /etc/passwd(verify)
user_key=("daemon" "bin" "sys" "adm" "listen" "nobody" "nobody4" "noaccess" "diag" "operator" "games" "gopher")

for ((i=0; i<${#user_key[@]}; i++)); do
    temp=$(grep -Ei "^\s*${user_key[i]}" /etc/passwd)

    if [[ -n ${temp} ]]; then
        temp=$(echo ${temp} | awk -F':' '{print $7}' | xargs)
        if [[ ${temp} != "/sbin/nologin" ]]; then
            ((counter++))
            echo "[ WARNING ] /etc/passwd에서 ${user_key[i]} 계정의 쉘 필드가 /sbin/nologin이 아닙니다."
        fi
    fi
done

if [ ${counter} -eq 0 ]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-12] 세션 종료 시간 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-12 ] 세션 종료 시간 설정 (중요도: 하)"
echo "--------------------------------------------------"

# check /etc/profile(verify)
check_tmout=$(grep -iE '^\s*TMOUT\s*=' /etc/profile | awk -F'=' '{print $2}' | xargs)

if [[ -z "$check_tmout" ]]; then
    temp=$(grep -iE "^\s*export\s+TMOUT\s*=" /etc/profile | awk -F'=' '{print $2}' | xargs)

    if [[ ${temp} == "600" ]]; then
      echo "[ SAFE ] 점검 결과 : 안전"
    else
      echo "[ WARNING ] /etc/profile에서 TMOUT 설정이 누락되었습니다."
    fi
else
    temp=$(grep -iE "^\s*export\s*TMOUT\s*$" /etc/profile)
    if [[ ${check_tmout} == "600" && -n ${temp} ]]; then
        echo "[ SAFE ] 점검 결과 : 안전"
    else
        echo "[ WARNING ] /etc/profile에서 TMOUT 설정이 누락되었습니다."
    fi
fi


# [U-13] 안전한 비밀번호 암호화 알고리즘 사용
echo ""
echo "--------------------------------------------------"
echo "[ U-13 ] 안전한 비밀번호 암호화 알고리즘 사용 (중요도: 중)"
echo "--------------------------------------------------"

# check /etc/login.defs(verify)
check_login=$(grep -iE "^\s*ENCRYPT_METHOD" /etc/login.defs | awk '{print $2}')
check_pam=$(grep -iE "^\s*password" /etc/pam.d/system-auth | grep "pam_unix.so" | grep -Ei "sha512|sha256" | xargs)

if [[ ${check_login} == "SHA512" || ${check_login} == "SHA256" ]] && [[ -n ${check_pam} ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
else
    echo "[ WARNING ] /etc/login.defs에서 암호화 알고리즘 설정이 누락되었습니다."
fi
