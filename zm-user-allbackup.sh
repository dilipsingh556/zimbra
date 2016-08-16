#!/bin/bash
#zm-user-allbackup.sh
#Created by Dilip
#Last Modified 8th Aug, 2016 by Dilip

# bash zm-user-allbackup.sh "@domain.com" ## to backup the mailbox from domain.com
# bash zm-user-allbackup.sh "-v @domain.com" ## to backup the mailbox except from domain.com
# bash zm-user-allbackup.sh "@" ## to backup the all mailboxes of entire domain from mailserver.




# Email notification options
EMAILFROM="admin@mail.accessworld.net"
EMAILTO="cinghdelete@gmail.com"

DOMAIN=$1
DATE=`date '+%Y-%m-%d_%H-%M'`

# Email account NOT to backup
EXCEPTIONS="spam.lfyqd1sb@mail.accessworld.net;ham.nywi62ot@mail.accessworld.net;virus-quarantine.hfnv_gvpio@mail.accessworld.net"

# Paths and file defs, probably nothing for you to change
TEMPDIR="/backup"
LOGFILE="${TEMPDIR}/zm-user-backup.log"
SOURCEDIR="/opt/zimbra"
BACKUPDIR="zmusers"
TARGETDIR="${TEMPDIR}/${BACKUPDIR}"
ARCHIVEFILE="`date +%Y-%m-%d_%H-%M`_zmusers.tar.gz"
MAILFILE="${TEMPDIR}/zm-user-backup-mail.$$"
MAILLOG="${TEMPDIR}/zm-user-backup-mail-log.$$"
#FTPLOG="${TEMPDIR}/zm-user-backup-ftp-log.$$"

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
  # Purpose: Send email message.
  # Parameter #1 = Subject
  # Parameter #2 = Body
  echo "From: ${EMAILFROM}" > ${MAILFILE}
  echo "To: ${EMAILTO}" >> ${MAILFILE}
  echo "Subject: ${1}" >> ${MAILFILE}
  echo "" >> ${MAILFILE}
  echo ${2} >> ${MAILFILE}
  echo "" >> ${MAILFILE}
  cat ${MAILLOG} >> ${MAILFILE}
  echo "" >> ${MAILFILE}
  #cat ${FTPLOG} >> ${MAILFILE}
  echo "" >> ${MAILFILE}
  echo "Server: ${HOSTNAME}, Program: ${SCRIPTNAME}" >> ${MAILFILE}
  ${SOURCEDIR}/postfix/sbin/sendmail -t < ${MAILFILE}
}

function f_cleanup()
{
  rm ${MAILFILE}
  rm ${MAILLOG}
  #rm ${FTPLOG}
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
 f_log "-Old Files will be replaced" 1>/dev/null 2>&1
else
  # Make the folder if it does not exist.
  mkdir -p ${TARGETDIR} 1>/dev/null 2>&1
fi
f_log "-- Getting list of user accounts"
for ACCT in `su - zimbra -c "zmprov -l gaa |grep ${DOMAIN}"`
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

f_log "--- Setting file permissions on ${TARGETDIR}/*.tgz"
chmod 0600 ${TARGETDIR}/*.tgz
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
fi

# Perform cleanup routine.
f_cleanup
# Exit with the combined return code value.
exit ${ERRORFLAG}
