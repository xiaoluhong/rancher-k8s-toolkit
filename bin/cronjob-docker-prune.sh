#!/bin/bash

MAX_DISK_USAGE=${1:-75}

MAIL_ALERTS=${MAIL_ALERTS:-false}
# 收件箱
MAIL_TO=${MAIL_TO}
# 发件箱
MAIL_FROM=${MAIL_FROM}
MAIL_PASSWORD=${MAIL_PASSWORD}
# smtp 服务器配置
MAIL_SMTP_SERVER=${MAIL_SMTP_SERVER}
MAIL_SMTP_PORT=${MAIL_SMTP_PORT}

MAIL_CACERT=${MAIL_CACERT}
MAIL_TLS_CHECK=${MAIL_TLS_CHECK:-true}

send_mail ()
{
cat << EOF > mail.txt
From: ${MAIL_FROM}
To: ${MAIL_TO}
Subject: "Mail Alerts: High Disk Usage - $( hostname )"
Date: $( date -Iseconds )
Hostname: $( hostname )

Host_IP:
$( ifconfig | grep inet | grep -v -E '127|inet6|10.42' )

Disk_Usage:
$( df -h | sort -u )
EOF

    if [[ ${MAIL_TLS_CHECK} && ${MAIL_TLS_CHECK} == 'true' ]]; then
        curl --silent --ssl --url "smtps://${MAIL_SMTP_SERVER}:${MAIL_SMTP_PORT}" \
        --mail-from "${MAIL_FROM}" --mail-rcpt "${MAIL_TO}" \
        --user "${MAIL_FROM}:${MAIL_PASSWORD}" \
        --upload-file mail.txt

        return
    fi

    if [[ ${MAIL_CACERT} && -n ${MAIL_CACERT} && ${MAIL_TLS_CHECK} == 'true' ]]; then
        touch /root/cacert.pem
        echo ${MAIL_CACERT} > /root/cacert.pem
        curl --silent --ssl --url "smtps://${MAIL_SMTP_SERVER}:${MAIL_SMTP_PORT}" \
        --mail-from "${MAIL_FROM}" --mail-rcpt "${MAIL_TO}" \
        --cacert=/root/cacert.pem \
        --user "${MAIL_FROM}:${MAIL_PASSWORD}" \
        --upload-file mail.txt

        return
    fi

    if [[ ${MAIL_TLS_CHECK} && ${MAIL_TLS_CHECK} == 'false' ]]; then
        curl --silent --url "smtps://${MAIL_SMTP_SERVER}:${MAIL_SMTP_PORT}" \
        --mail-from "${MAIL_FROM}" --mail-rcpt "${MAIL_TO}" \
        --user "${MAIL_FROM}:${MAIL_PASSWORD}" \
        --insecure \
        --upload-file mail.txt

        return
    fi
}


CURRENT_DISK_USAGE=$( df -h | grep '/dev' | awk '{print $5}' | grep -v 'Use%' | tr -d '%' | sort -nr | head -n 1 );

if [[ "${CURRENT_DISK_USAGE}" > "${MAX_DISK_USAGE}" ]]; then

    docker system prune -a -f;
    CHECK_DISK_USAGE=$( df -h | grep '/dev' | awk '{print $5}' | grep -v 'Use%' | tr -d '%' | sort -nr | head -n 1 );

    if [[ "${CHECK_DISK_USAGE}" > "${MAX_DISK_USAGE}" ]]; then
        if [[ ${MAIL_ALERTS} = 'true' && ${MAIL_FROM} != '' && ${MAIL_TO} != '' ]]; then
            send_mail
        fi
    fi
fi

