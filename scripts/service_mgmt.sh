#!/bin/bash


# [U-62] 로그인 시 경고 메시지 설정
echo ""
echo "--------------------------------------------------"
echo "[ U-62 ] 로그인 시 경고 메시지 설정 (중요도: 하)"
echo "--------------------------------------------------"

# error counter 
counter=0

check_service=("SERVER-motd" "SERVER-issue")
check_file=("/etc/motd" "/etc/issue")

for item in "${check_service[@]}"; do
    IFS='|' read -r service file <<< "$item"
    
    if [[ -f "$file" ]]; then
        if ! grep -Ev '^\s*$|^\s*#' "$file" >/dev/null; then
            ((counter++))
            echo "[ WARNING ] $file 파일에 경고 메시지가 정의되어 있지 않습니다."
        fi
    fi
done

# check SSH
ssh_conf="/etc/ssh/sshd_config"
if [[ -f "$ssh_conf" ]]; then 
    banner_path=$(grep -Ei '^\s*Banner\s+' "$ssh_conf" | grep -Ev '^\s*#' | awk '{print $2}')
    
    if [[ -z "$banner_path" || "$banner_path" == "none" ]]; then
        ((counter++))
        echo "[ WARNING ] SSH: $ssh_conf 내에 Banner 설정이 누락되었거나 none입니다."
    elif [[ ! -f "$banner_path" ]]; then
        ((counter++))
        echo "[ WARNING ] SSH: 설정된 배너 파일($banner_path)이 시스템에 존재하지 않습니다."
    else
        if ! grep -Ev '^\s*$|^\s*#' "$banner_path" >/dev/null; then
            ((counter++))
            echo "[ WARNING ] SSH: 배너 파일($banner_path) 내용이 비어있습니다."
        fi
    fi
fi

# check Sendmail
mail_conf="/etc/mail/sendmail.cf"
if [[ -f "$mail_conf" ]]; then
    if ! grep -Ei '^\s*O\s+SmtpGreetingMessage\s*=' "$mail_conf" | grep -Ev '^\s*#' >/dev/null; then
        ((counter++))
        echo "[ WARNING ] Sendmail: SMTP 경고 메시지 설정이 누락되었습니다."
    fi
fi

# check Postfix
postfix_conf="/etc/postfix/main.cf"
if [[ -f "$postfix_conf" ]]; then
    if ! grep -Ei '^\s*smtpd_banner\s*=' "$postfix_conf" | grep -Ev '^\s*#' >/dev/null; then
        ((counter++))
        echo "[ WARNING ] Postfix: smtpd_banner 설정이 누락되었습니다."
    fi
fi

# check FTP (vsftpd, proftpd)
ftp_file=("/etc/vsftpd.conf" "/etc/vsftpd/vsftpd.conf")
for ftp_conf in "${ftp_file[@]}"; do
    if [[ -f "$ftp_conf" ]]; then
        if ! grep -Ei '^\s*ftpd_banner\s*=' "$ftp_conf" | grep -Ev '^\s*#' >/dev/null; then
            ((counter++))
            echo "[ WARNING ] vsFTPd: ftpd_banner 설정이 누락되었습니다. ($ftp_conf)"
        fi
    fi
done

# check DNS 
for dns_conf in "/etc/named.conf" "/etc/bind/named.conf.options"; do
    if [[ -f "$dns_conf" ]]; then
        if ! grep -Ei '^\s*version\s+' "$dns_conf" | grep -Ev '^\s*#' >/dev/null; then
            ((counter++))
            echo "[ WARNING ] DNS: version 정보 은폐 설정이 누락되었습니다. ($dns_conf)"
        fi
    fi
done

# [U-63] sudo 명령어 접근 관리
echo ""
echo "--------------------------------------------------"
echo "[ U-63 ] sudo 명령어 접근 관리 (중요도: 중)"
echo "--------------------------------------------------"

# error counter 
counter=0

# check /etc/sudoers files owner and permission
check_file=$(find /etc/sudoers -type f \( ! -user root -o -perm /022 \))

for file in ${checkk_file}; do
    ((counter++))
    echo "[ WARNING ] ${file}의 소유자 및 권한이 잘못되었습니다."
done 

if [[ ${counter} -eq 0 ]]; then
    echo "[ SAFE ] 점검 결과 : 안전"
fi