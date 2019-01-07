#!/usr/bin/expect

cur_date=`date +%Y-%m-%d`




guanxifiledir=/usr/tomcat_process_import/${cur_date}/
logdir=/usr/tomcat_process_import/${cur_date}_log/
merge_dir=/usr/merge_files/
if [ ! -d "${guanxifiledir}" ];then
        mkdir -p ${guanxifiledir}
fi
if [ ! -d "${logdir}" ];then
	mkdir -p ${logdir}
fi
if [ ! -d "${merge_dir}" ];then
	mkdir -p ${merge_dir}
fi

#要发送的机器ip:端口号(多个用,分割)
if [ x"$1" = x ]; then 
targetip=
else
targetip=$1
fi



#用户名
if [ x"$3" = x ]; then 
user_name=root
else
user_name=$3
fi

#密码
if [ x"$4" = x ]; then 
passw=
else
passw=$4
fi

#本机脚本路径
if [ x"$5" = x ]; then 
self_location=/usr/get_relationship.sh
else
self_location=$5
fi

#脚本发送位置及文件名
if [ x"$6" = x ]; then 
remote_location=/usr/get_relationship.sh
else
remote_location=$6
fi

OLD_IFS="$IFS"
IFS=","
remote_ips=($targetip)
IFS="$OLD_IFS"
for remote_info in ${remote_ips[@]}
do
remote_ip=`echo ${remote_info} | cut -d ':' -f 1`
remote_port=`echo ${remote_info} | cut -d ':' -f 2`

expect -c "
	set timeout 1200; ##设置拷贝的时间，根据目录大小决定，因为服务器可能比较多,暂时设置为1200秒。
	spawn script -q -a /tmp/${cur_date}.log -c \"/usr/bin/scp -P ${remote_port} ${self_location}  ${user_name}@${remote_ip}:/usr/\"
	expect {
	\"*yes/no*\" {send \"yes\r\"; exp_continue}
	\"*password:\" {send \"${passw}\r\"; exp_continue}
	\"*password*\" {send \"${passw}\r\";} ##远程IP的密码。
	}"

expect <<-END
	set timeout 1200
	spawn ssh -p ${remote_port} ${user_name}@${remote_ip}
	expect {
		"*yes/no*"  {send "yes\r"; exp_continue}
		"*password*" {send ${passw}\r";}
	}
	sleep 1
	send "sh ${remote_location}\r"
	sleep 3
	send "exit\n"
	expect eof
	exit
END

done
