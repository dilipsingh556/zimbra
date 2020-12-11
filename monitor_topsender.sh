#!/bin/bash

d=`date |awk '{print $3}'`
if [ $d -lt 10 ];
then
today=`date |awk '{print $2"  "$3}'`
else
today=`date |awk '{print $2" "$3}'`
fi


#today=`date |awk '{print $2"  "$3}'`
#to=dilip@accessworld.net
#to=abishek@accessworld.net
to="dilip@accessworld.net,prabin@accessworld.net,abishek@accessworld.net"

#high_vol_list=`less /var/log/maillog |grep "$today" |grep "from=<" |awk '{print $7}' |grep "from=<" |sort |uniq -c |sort -n |tail -10`
less /var/log/maillog |grep "$today" |grep "from=<" |awk '{print $7}' |grep "from=<" |sort |uniq -c |sort -n |egrep -v "root@mail|from=<>" |tail -20 > /tmp/high_vol_list

for i in `cat /tmp/high_vol_list |awk '{print $1"_"$2 }' /tmp/high_vol_list`
do 
#echo $i
count=`echo $i |awk -F\_ '{print $1}'`
email_acct=`echo $i |awk -F\_ '{print $2}'`
#email_acct=`echo $i |awk '{print $2}' |awk -F"[<>]" '{print $2}'`

#echo $count $email_acct	 
#echo > /tmp/acct_log
if [ $count -gt 100 ];
then 
acct=`echo $email_acct |awk -F"[<>]" '{print $2}'`
#su - zimbra -c "zmprov ma $acct zimbraAccountStatus closed"
echo " " >> /tmp/high_vol_list
echo -e "#########################################################################################\n" >> /tmp/high_vol_list
echo "Note:  The email accounts might have been compromised and the status has been changed to "closed".\n       "Kindly change the password to strong one and Change the account status to "Active".">> /tmp/high_vol_list
echo "#########################################################################################" >> /tmp/high_vol_list
#cat /tmp/high_vol_list |tail -15

 cat /tmp/high_vol_list|tail -15 |mail -s "NAC Alert: Account may be compromised" $to 
#echo $count $email_acct
 exit 0
echo
else
sleep 0
fi
done
