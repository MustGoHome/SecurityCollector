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
user=$(stat -c "%U" /etc/passwd)
perm=$(stat -c "%a" /etc/passwd)

if [[ ${user} != root || ${perm} != 644 ]]; then
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

# check /etc/rc.d/*/*
check_rc=$(ls -al `readlink -f /etc/rc.d/*/* | sed "s/$/*/"` | awk '{print $NF}')

for ((i=0; i<${#check_rc[@]}; i++)); do
    user=$(stat -c "%U" ${check_rc[i]})
    perm=$(stat -c "%a" ${check_rc[i]})

    other=$((perm % 10))

    if [[ ${user} != root || ${other} -eq 2 || ${other} -eq 3 || ${other} -eq 6 || ${other} -eq 7 ]]; then
        ((counter++))
        echo -e "[ WARNING ] ${check_rc[i]}의 소유자 및 권한이 잘못되었습니다."
    fi
done

if [ ${counter} -eq 0 ]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi

