#!/bin/bash

# [U-14] root 홈 및 PATH 디렉터리 권한·환경변수 설정
echo "--------------------------------------------------"
echo "[ U-14 ] root 홈 및 PATH 디렉터리 권한·환경변수 설정 (중요도: 상)"
echo "--------------------------------------------------"

# error counter
counter=0

# check $PATH
temp=$(echo $PATH | grep -iEc "(^|:)(\.|\s*)(:|$)|::")
if [[ ${temp} -eq 1 ]]; then
    ((counter++))
    echo "[ WARNING ] PATH 환경변수에서 취약점이 발견되었습니다."
fi

# check path files
file_key=("/etc/profile" "${HOME}/.bash_profile" "${HOME}/.bashrc" "/etc/bash.bashrc")

for ((i=0; i<${#file_key[@]}; i++)); do
    temp=$(grep -iE "^\s*(export\s+)?PATH\s*=" /etc/profile | grep -iEc "(^|:)(\.|\s*)(:|$)|::")

    if [[ ${temp} -ne 0 ]]; then
        ((counter++))
        echo -e "[ WARNING ] ${file_key[i]}에서 PATH 환경변수에서 취약점이 발견되었습니다."
    fi
done

if [ ${counter} -eq 0 ]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-15] 파일 및 디렉터리 소유자 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-15 ] 파일 및 디렉터리 소유자 설정 (중요도: 상)"
echo "--------------------------------------------------"

# check files
temp=$(find / \( -nouser -o -nogroup \) -xdev -ls 2>/dev/null | awk '{print $NF}')

if [[ -n ${#temp[@]} ]]; then
    for file in ${temp[@]}; do
        echo "[WARNING] ${file}의 소유자 및 권한이 잘못되었습니다."
    done
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-16] /etc/passwd 파일 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-16 ] /etc/passwd 파일 소유자 및 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

# check /etc/passwd
check=$(find /etc/passwd \( ! -user root -o -perm /111 -o -perm /022 \))

if [[ -n ${check} ]]; then
    echo -e "[ WARNING ] /etc/passwd의 소유자 및 권한이 잘못되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-17] 시스템 시작 스크립트 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-17 ] 시스템 시작 스크립트 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

# error counter
counter=0

# check /usr/lib/systemd/system
mapfile -t check_systemd < <(find /usr/lib/systemd/system -type f -name "*.service" -perm /002)

for ((i=0; i<${#check_systemd[@]}; i++)); do
    ((counter++))
    echo -e "[ WARNING ] ${check_systemd[i]}의 소유자 및 권한이 잘못되었습니다."
done

if [ ${counter} -eq 0 ]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-18] /etc/shadow 파일 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-18 ] /etc/shadow 파일 소유자 및 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

# check /etc/shadow
check_shadow=$(find /etc/shadow \( ! -user root -o -perm /377 \))

if [[ -n ${check_shadow} ]]; then
    echo -e "[ WARNING ] /etc/shadow의 소유자 및 권한이 잘못되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi


# [U-19] /etc/shadow 파일 소유자 및 권한 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-19 ] /etc/hosts 파일 소유자 및 권한 설정 (중요도: 상)"
echo "--------------------------------------------------"

# check /etc/shadow
check_hosts=$(find /etc/hosts \( ! -user root -o -perm /133 \))

if [[ -n ${check_hosts} ]]; then
    echo -e "[ WARNING ] /etc/hosts의 소유자 및 권한이 잘못되었습니다."
else
    echo "[ SAFE ] 점검 결과 : 안전"
fi

