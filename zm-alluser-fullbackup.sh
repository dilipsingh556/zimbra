#!/bin/bash
# Name          : zmallusr_fullbackup.sh.sh
# Author        : Dilip Singh
# Email         : cinghdelete@gmail.com
# Date          : 10-June-2019
# Description   : This script is used to backup zimbra email users (Inbox, Trash, Junk, user Settings, 
#               : Directly store the file in mounted dir i.e. /mnt/mail-mount/
# Use           : Please change the path of TEMPDIR folders
#		: zm-users-altBak-mail.accessworld.net-DilipAWT.sh @   		   #for backup all user accounts
#		: zm-users-altBak-mail.accessworld.net-DilipAWT.sh <domain>	   #for backup users accounts of particular <domain>
#		: zm-users-altBak-mail.accessworld.net-DilipAWT.sh <"-v domain">   #for backup users accounts of other than particular <domain>
#		: zm-users-altBak-mail.accessworld.net-DilipAWT.sh <email@domain>  #for backup user <email@domain>
# Edit note     :
#Last Modified 10th June, 2019 by Dilip

# Email notification options
EMAILFROM="admin@mail.dilipsingh.com.np"
EMAILTO="cinghdelete@gmail.com"
DOMAIN=$1
DATE=`date '+%Y-%m-%d_%H-%M'`
DATE1=`date '+%Y-%m-%d'`

# Email account NOT to backup
EXCEPTIONS="spam.8qvgjgjj@dilipsingh.com.np virus-quarantine.p8dkamez@dilipsingh.com.np ham.ooqbquwc1m@dilipsingh.com.np"

# Paths and file defs, probably nothing for you to change
TEMPDIR="/mnt/mail_mount/MAIL-zmusers"
LOGDIR="${TEMPDIR}/logs"
LOGFILE="${LOGDIR}/zm-user-backup_$DATE1.log"
SOURCEDIR="/opt/zimbra"
BACKUPDIR="zmusers"
TARGETDIR="${TEMPDIR}/${BACKUPDIR}"
ARCHIVEFILE="`date +%Y-%m-%d_%H-%M`_zmusers.tar.gz"
MAILFILE="${TEMPDIR}/zm-user-backup-mail.$$"
MAILLOG="${TEMPDIR}/zm-user-backup-mail-log.$$"

# Nothing to change here, move along
HOSTNAME=$(hostname -f)
SCRIPTNAME=${0}
RETURNVALUE=0
UCOUNT=0
ERRORFLAG=0

#######################################
##            FUNCTIONS              ##
#######################################

function f_sendmail()
{
  echo "From: ${EMAILFROM}" > ${MAILFILE}
  echo "To: ${EMAILTO}" >> ${MAILFILE}
  echo "Subject: ${1}" >> ${MAILFILE}
  echo "" >> ${MAILFILE}
  echo ${2} >> ${MAILFILE}
  echo "" >> ${MAILFILE}
  cat ${MAILLOG} >> ${MAILFILE}
  echo "" >> ${MAILFILE}
  echo "" >> ${MAILFILE}
  echo "Server: ${HOSTNAME}, Script Name: ${SCRIPTNAME}" >> ${MAILFILE}
  ${SOURCEDIR}/common/sbin/sendmail -t < ${MAILFILE}
}

function f_cleanup()
{
  rm ${MAILFILE}
  rm ${MAILLOG}
  
  # Remove backup's older then 3 days
  #find ${TEMPDIR}/*.tar.gz -mtime +3 -exec rm {} \;
}

function f_log()
{
  # Handles logging of messages
  # Parameter #1 = Log Message
  STAMP=`date '+%Y-%m-%d %H:%M:%S'`
  echo "${STAMP} ${1}"
  echo "${STAMP} ${1}" >> ${LOGFILE}
  echo "${STAMP} ${1}" >> ${MAILLOG}
}


#######################################
##           MAIN PROGRAM            ##
#######################################

echo "---------------------------------------------------" >> ${LOGFILE}
f_log "- zm user backup started."
if [ -d "${TARGETDIR}" ]; then
  # Purge existing archives.
  #rm ${TARGETDIR}/*.tgz 1>/dev/null 2>&1
 f_log "-Old Files are being replaced" 1>/dev/null 2>&1
else
  # Make the folder if it does not exist.
  mkdir -p ${TARGETDIR} 1>/dev/null 2>&1
fi

if [ -d "${LOGDIR}" ]; then
f_log "- Creating log file ${LOGFILE}" 1>/dev/null 2>&1
else
  # Make the folder if it does not exist.
f_log "- Creating log dir and log file ${LOGFILE}" 1>/dev/null 2>&1
  mkdir -p ${LOGDIR} 1>/dev/null 2>&1
fi

f_log "-- Getting list of user accounts"
for ACCT in `su - zimbra -c "zmprov -l gaa |grep ${DOMAIN}"`
#for ACCT in `cat /home/dilip/user_list_2_delete.txt`
do
  # Check to see if current account should be skipped.
  if echo "${EXCEPTIONS}" | grep -q ${ACCT}
  then
    # Exception found, skip this account.
    echo "" > /dev/null
  else
    # Backup user account.
    UCOUNT=$((UCOUNT+1))
    f_log "--- Backing up user ${ACCT}"
        if  [ -f "${TARGETDIR}/${ACCT}.tgz" ] || [ -f "${TARGETDIR}/${ACCT}-junk.tgz" ] || [ -f "${TARGETDIR}/${ACCT}-trash.tgz" ] || [ -f "${TARGETDIR}/${ACCT}-settings.txt" ]; then
                mv ${TARGETDIR}/${ACCT}.tgz ${TARGETDIR}/${ACCT}.tgz.old
                mv ${TARGETDIR}/${ACCT}-junk.tgz ${TARGETDIR}/${ACCT}-junk.tgz.old
                mv ${TARGETDIR}/${ACCT}-trash.tgz ${TARGETDIR}/${ACCT}-trash.tgz.old
                mv ${TARGETDIR}/${ACCT}-settings.txt ${TARGETDIR}/${ACCT}-settings.txt.old
        else
                echo"" > /dev/null
        fi

    ${SOURCEDIR}/bin/zmmailbox -z -m ${ACCT} getRestURL "//?fmt=tgz" > ${TARGETDIR}/${ACCT}.tgz
#comment out the below two lines if you dont need to backup junk and trash folder
    ${SOURCEDIR}/bin/zmmailbox -z -m ${ACCT} getRestURL '/junk?fmt=tgz' > ${TARGETDIR}/${ACCT}-junk.tgz
    ${SOURCEDIR}/bin/zmmailbox -z -m ${ACCT} getRestURL '/trash?fmt=tgz' > ${TARGETDIR}/${ACCT}-trash.tgz
    ${SOURCEDIR}/bin/zmprov getAccount ${ACCT} > ${TARGETDIR}/${ACCT}-settings.txt

    RETURNVALUE=$?
    if [ ! ${RETURNVALUE} -eq 0 ]; then
      # Something went wrong.
      f_log "---- Error on ${ACCT}, exit code ${RETURNVALUE}"
      ERRORFLAG=$((ERRORFLAG+1))
    else
      rm -f ${TARGETDIR}/${ACCT}.tgz.old
      rm -f ${TARGETDIR}/${ACCT}-junk.tgz.old
      rm -f ${TARGETDIR}/${ACCT}-trash.tgz.old
      rm -f ${TARGETDIR}/${ACCT}-settings.txt.old
    fi
  fi
done
f_log "-- ${UCOUNT} accounts processed."

#Backing up ldap database

#chmod 777 ${TARGETDIR}
f_log "- Backing up ldap database."
    #`su - zimbra -c "libexec/zmslapcat ${TARGETDIR}/"`;
    `su - zimbra -c "libexec/zmslapcat /tmp/"`;
#Backing up ldap-config
    #`su - zimbra -c "libexec/zmslapcat -c ${TARGETDIR}/"`;
    `su - zimbra -c "libexec/zmslapcat -c /tmp/"`;
rm -f ${TARGETDIR}/ldap*
mv /tmp/ldap* ${TARGETDIR}


# Comment out the below line if you do not want to receive statistic emails.
#f_sendmail "Zimbra User Mailbox Backup" "${UCOUNT} accounts backed up."

#f_log "--- Setting file permissions on ${TARGETDIR}/*.tgz"
#chmod -R 755 ${TARGETDIR}/
#f_log "--- Creating a single archive ${TEMPDIR}/${ARCHIVEFILE}"
#tar -zcvf ${TEMPDIR}/${ARCHIVEFILE} -C ${TEMPDIR}/ ./${BACKUPDIR} 1>/dev/null 2>&1
RETURNVALUE=$?
if [ ! "${RETURNVALUE}" -eq "0" ]; then
  # Something went wrong.
  f_log "--- Error creating ${TEMPDIR}/${ARCHIVEFILE}, Return Value: ${RETURNVALUE}"
  ERRORFLAG=$((ERRORFLAG+1))
fi



f_log "- zm user backup complete. exit code: ${ERRORFLAG}"

if [ "${ERRORFLAG}" -ne "0" ]; then
  f_sendmail "Zimbra Mailbox Backup Error - ${HOSTNAME}" "${ERRORFLAG} errors detected in ${HOSTNAME} ${SCRIPTNAME}"<${MAILLOG}
else
  f_sendmail "Zimbra User Mailbox Backup - ${HOSTNAME}" "${UCOUNT} accounts backed up."<${MAILLOG}
  f_log "- Sending Email to :: ${EMAILTO}"
fi

# Perform cleanup routine.
f_cleanup
# Exit with the combined return code value.
exit ${ERRORFLAG}