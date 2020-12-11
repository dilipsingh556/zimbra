#!/bin/bash
#Use
# ./delete-mailq-bysender-zimbra.sh <user@domain.com>

user=$1
#su - zimbra -c "mailq |grep -B1 "$compromised_user" |grep MAILER-DAEMON |awk '{print $1}' |sed 's/.$//' > /tmp/queue.spam"
#for i in `less /tmp/queue.spam`
for i in `su - zimbra -c "mailq |grep -B1 "$user" |grep MAILER-DAEMON |awk '{print $1}' |sed 's/.$//' > /tmp/queue.spam"`
do 
/opt/zimbra/common/sbin/postsuper -d $i
done