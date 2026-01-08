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

counter=0

# 1. /etc/login.defs 점검 (PASS_MAX_DAYS <= 90, PASS_MIN_DAYS >= 1)
if [[ -f "/etc/login.defs" ]]; then
    # PASS_MAX_DAYS 점검
    max_days=$(grep -iE "^\s*PASS_MAX_DAYS" /etc/login.defs | awk '{print $2}' | xargs)
    if [[ -z "${max_days}" ]]; then
        ((counter++))
        echo "[ WARNING ] /etc/login.defs에 PASS_MAX_DAYS 설정이 누락되었습니다."
    elif [[ "${max_days}" -gt 90 ]]; then
        ((counter++))
        echo "[ WARNING ] PASS_MAX_DAYS가 90일보다 깁니다. (현재: ${max_days}일)"
    fi

    # PASS_MIN_DAYS 점검
    min_days=$(grep -iE "^\s*PASS_MIN_DAYS" /etc/login.defs | awk '{print $2}' | xargs)
    if [[ -z "${min_days}" ]]; then
        ((counter++))
        echo "[ WARNING ] /etc/login.defs에 PASS_MIN_DAYS 설정이 누락되었습니다."
    elif [[ "${min_days}" -lt 1 ]]; then
        ((counter++))
        echo "[ WARNING ] PASS_MIN_DAYS가 1일보다 짧습니다. (현재: ${min_days}일)"
    fi
fi

# 2. /etc/security/pwquality.conf 점검 (복잡성 설정)
if [[ -f "/etc/security/pwquality.conf" ]]; then
    # minlen (최소 길이 8자 이상)
    minlen=$(grep -iE "^\s*minlen\s*=" /etc/security/pwquality.conf | awk -F'=' '{print $2}' | xargs)
    if [[ -z "${minlen}" || "${minlen}" -lt 8 ]]; then
        ((counter++))
        echo "[ WARNING ] pwquality.conf: minlen이 8자 미만입니다. (현재: ${minlen:-누락})"
    fi

    # 크레딧 설정 (dcredit, ucredit, lcredit, ocredit 모두 -1 이하 권장)
    credits=("dcredit" "ucredit" "lcredit" "ocredit")
    for credit in "${credits[@]}"; do
        val=$(grep -iE "^\s*${credit}\s*=" /etc/security/pwquality.conf | awk -F'=' '{print $2}' | xargs)
        if [[ -z "${val}" || "${val}" -gt -1 ]]; then
            ((counter++))
            echo "[ WARNING ] pwquality.conf: ${credit} 설정이 부적절합니다. (-1 이하 권장, 현재: ${val:-누락})"
        fi
    done

    # enforce_for_root 존재 여부
    if ! grep -qiE "^\s*enforce_for_root" /etc/security/pwquality.conf; then
        ((counter++))
        echo "[ WARNING ] pwquality.conf: enforce_for_root 설정이 누락되었습니다."
    fi
fi

# 3. PAM 모듈 순서 점검 (/etc/pam.d/system-auth)
# [논리] pwquality -> pwhistory -> unix 순서로 배치되어야 함
if [[ -f "/etc/pam.d/system-auth" ]]; then
    pam_pwq=$(grep -iEn "^\s*password" /etc/pam.d/system-auth | grep "pam_pwquality.so" | awk -F':' '{print $1}' | head -n 1)
    pam_his=$(grep -iEn "^\s*password" /etc/pam.d/system-auth | grep "pam_pwhistory.so" | awk -F':' '{print $1}' | head -n 1)
    pam_unix=$(grep -iEn "^\s*password" /etc/pam.d/system-auth | grep "pam_unix.so" | awk -F':' '{print $1}' | head -n 1)

    if [[ -z "${pam_pwq}" || -z "${pam_his}" || -z "${pam_unix}" ]]; then
        ((counter++))
        echo "[ WARNING ] system-auth: 필수 PAM 모듈(pwquality, pwhistory, unix) 중 일부가 누락되었습니다."
    elif [[ ${pam_pwq} -gt ${pam_unix} ]] || [[ ${pam_his} -gt ${pam_unix} ]]; then
        ((counter++))
        echo "[ WARNING ] system-auth: PAM 모듈 순서가 잘못되었습니다. (unix 모듈보다 앞에 위치해야 함)"
    fi
fi

# 4. /etc/security/pwhistory.conf 점검 (최근 암호 기억)
if [[ -f "/etc/security/pwhistory.conf" ]]; then
    # remember (최근 4개 기억 권장)
    rem=$(grep -iE "^\s*remember\s*=" /etc/security/pwhistory.conf | awk -F'=' '{print $2}' | xargs)
    if [[ -z "${rem}" || "${rem}" -lt 4 ]]; then
        ((counter++))
        echo "[ WARNING ] pwhistory.conf: remember 값이 4 미만입니다. (현재: ${rem:-누락})"
    fi

    # enforce_for_root 점검
    if ! grep -qiE "^\s*enforce_for_root" /etc/security/pwhistory.conf; then
        ((counter++))
        echo "[ WARNING ] pwhistory.conf: enforce_for_root 설정이 누락되었습니다."
    fi
fi

# 최종 결과 출력
if [[ ${counter} -eq 0 ]]; then
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

tmout_val=$(grep -iE '^\s*(export\s+)?TMOUT\s*=' /etc/profile | awk -F'=' '{print $2}' | xargs)
export_check=$(grep -iE '^\s*export\s+TMOUT(\s*=|(\s*$))' /etc/profile)

if [[ -n "$tmout_val" && -n "$export_check" ]]; then
    if [[ "$tmout_val" -le 600 && "$tmout_val" -gt 0 ]]; then
        echo "[ SAFE ] 점검 결과 : 안전 (현재 설정: ${tmout_val}초)"
    else
        echo "[ WARNING ] TMOUT 설정값이 600초를 초과합니다. (현재: ${tmout_val}초)"
    fi
else
    echo "[ WARNING ] /etc/profile에서 TMOUT 설정 또는 export가 누락되었습니다."
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
