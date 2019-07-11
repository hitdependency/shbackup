#!/bin/bash

#######################################################
#
# Bash script that provides sending any folder to sftp
# server with telegram notifications. 10/07/2019
#
# Requirements : curl, sshfs
#
#######################################################

#######################################################
# Set ENVS
#######################################################

TG_BOT_TOKEN=
TG_CHAT_ID=

MNT_SRC=user@ftp:/bitrix/
MNT_DST=/shbackup/mnt/
MNT_PWD=

#######################################################
# Mounts ftp server with sshfs < password
#######################################################

Umount () {
  umount ${MNT_DST} > /dev/null 2>&1 || {
    echo "already mounted ${MNT_DST}"
  }
}

Mount () {
  Umount
  echo "${MNT_PWD}" | sshfs -o cache_timeout=115200 \
                            -o attr_timeout=115200 \
                            -o password_stdin \
                            -o allow_other \
                            -o max_readahead=90000 \
                            -o big_writes \
                            -o no_remote_lock \
                            ${MNT_SRC} ${MNT_DST}
}

#######################################################
# Usage: SendNotification "text everything"
#######################################################

SendNotification () {
  MESSAGE_TEXT=$1
  if [ $# -ne 1 ]
  then
    echo "usage: $0 {MESSAGE_TEXT}"
    exit $WRONG_ARGS
  fi
  ping -c 1 -w 2 api.telegram.org > /dev/null || {
    echo "api.telegram.org is not available"
    exit 1
  }
  curl --silent -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
                -d "chat_id=${TG_CHAT_ID}&text=${MESSAGE_TEXT}" >> tg.logs
}

#######################################################
# Backing up commands, edit for every project
#######################################################

Backup () {
  rm -rf /bitrix/*
  mysqldump -u root --databases sitemanager > /bitrix/sitemanager-$(date +%Y%m%d-%H%M%S).sql
  GZIP=-9 tar cvzf /bitrix/bitrix-$(date +%Y%m%d-%H%M%S).tar.gz /home/bitrix /bitrix/*.sql

  cp -R  /bitrix/*.tar.gz ${MNT_DST} || {
    echo "something went wrong with cp -R command, exiting..."
    exit 1
  }
  # deletes files older than 4 days
  find ${MNT_DST} -type f -mtime +4 -name '*.tar.gz' -execdir rm -- '{}' \;
  # gets last filename with human readable size
  last_filename=$(ls -Atrs --block-size=M ${MNT_DST}*.tar.gz | tail -n1)
  msg="$(echo "Bitrix Backup Passed successfully with the size of ${last_filename}")"
  SendNotification "${msg}"
}

#######################################################
# Entrypoint
#######################################################

Mount
Backup
Umount
