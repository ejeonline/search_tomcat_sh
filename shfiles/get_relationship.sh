#!/bin/bash


#拷贝文件方法(不保持目录结构)
function printfile(){
	srcdir=$1
	descdir=$2
	for file in "$srcdir"/*
	do
		if [ -d $file ]
		then
			printfile $file $descdir
		else
			if [ "${file#*.}"x = "yml"x ]||[ "${file##*.}"x = "xml"x ]||[ "${file##*.}"x = "properties"x ];then	
				echo "*****"$file"--->>>"$descdir 
				#cp -R `ls -A | grep -vE "docs|examples|host-manager|manager"` $descdir
				cp -R $file $descdir
			fi
		fi
	done
}

#读取配置文件中的rds路径
function print_jdbc(){
	srcdir=$1
	echo "srcdir:"$srcdir
	for myfile in "$srcdir"/*
	do
		jdbc_url=`grep -v '^#' $myfile | grep -v '^$' | egrep 'jdbc:mysql|jdbc:oracle|jdbc:postgresql|jdbc\\\:mysql|jdbc\\\:postgresql|jdbc\\\:oracle' | awk -F '//' '{print $2}' | awk -F ':' '{print $1}'` #| sed "s|$|,${war_name}|g"     #| tr '\' ' ' | sed 's/^[ \t]*//g'
		if [ -n "$jdbc_url" ]; then 
			#可能结果会有多个RDS地址信息,所以先写入文件后期处理
			echo $jdbc_url >> ${jdbc_dir}/jdbc_p
			#去掉\
			sed -i 's#\\##g' ${jdbc_dir}/jdbc_p 
			#将空格换成行
			sed -i 's/ /\n/g' ${jdbc_dir}/jdbc_p
			#1.3将RDS名称写入元素文件中
			sed "s|$|&,RDS|g" ${jdbc_dir}/jdbc_p >> ${jdbc_dir}/yuansu
			#2.2将RDS和项目关系写入关系文件中
			sed "s|$|&,所属项目,${2}|g" ${jdbc_dir}/jdbc_p >> ${jdbc_dir}/guanxi
		fi
	done
}


#内网IP地址
ipaddr=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d '/')
echo "内网IP:"$ipaddr
#当前日期
cur_date=`date +%Y-%m-%d`  
echo "当天日期:"$cur_date

#用于处理结果的机器ip(neo4j所在ECSIP)
if [ x"$1" = x ]; then 
finalECSIp=
else
finalECSIp=$1
fi
#端口号
if [ x"$2" = x ]; then 
ecsport=
else
ecsport=$2
fi


#用户名
if [ x"$3" = x ]; then 
user_name=root
else
user_name=$3
fi

#密码
if [ x"$4" = x ]; then 
password=
else
password=$4
fi


#使用双引号可以使用变量
#sed -i "s/^/${ipaddr},/"  ${jdbc_dir}/jdbc_p


#文件存放位置
jdbc_dir="/usr/pro_tom_file"
process_files="/usr/pro_tom_file/config_files"
if [ ! -d "${jdbc_dir}" ];then
	mkdir -p ${jdbc_dir}
fi
if [ ! -d "${process_files}" ];then
	mkdir -p ${process_files}
fi

#创建元素文件 命名规则IP+日期.ys
touch ${jdbc_dir}/${ipaddr}_${cur_date}.ys

#创建关系文件 命名规则IP+日期.gx
touch ${jdbc_dir}/${ipaddr}_${cur_date}.gx

#创建日志文件 命名规则IP+日期
touch ${jdbc_dir}/${ipaddr}_${cur_date}.log

#获取tomcat路径
tomcat_process=$(ps aux | grep tomcat | grep -w 'tomcat' | grep -v 'grep' | awk '{print $(NF-3)}' | sed 's/-Dcatalina.home=//g')
echo $tomcat_process
#未发现启动tomcat则运行结束
result=$(echo $tomcat_process | grep "/") 
if [ -z "$result" ]; then
	echo "tomcat 未找到,执行退出"
	echo "${ipaddr},tomcatnotfound" >> ${jdbc_dir}/${ipaddr}_${cur_date}.log
	echo "执行结束,日志生成目录 ${jdbc_dir}/${ipaddr}_${cur_date}.log"	
	cat ${jdbc_dir}/${ipaddr}_${cur_date}.log
	exit
fi


#将tomcat路径设为数组的方式循环输出war包部署的路径
OLD_IFS="$IFS"
IFS=""
tom_paths=($tomcat_process)
IFS="$OLD_IFS"
for tom_path in ${tom_paths[@]}
do
	echo "tom_path:${tom_path}"
    #筛选appBase=所在行 筛选并去掉引号
	appBaseName=`sed 's/<!--.*-->//g' ${tom_path}/conf/server.xml | sed -n '/<!--/,/-->/!p' | grep "appBase=" | awk -F'appBase' -vOFS="appBase" '{$1="";$1=$1}1' | awk '{print $1}' | awk -F= '{print $2}'|sed 's/"//g' | sed "s|^|${tom_path}/|g"`
    echo "${appBaseName}"
	#将信息写入tom.test
    echo "${appBaseName}" >> ${jdbc_dir}/read_xml_war_path
done

if [ ! -f "${jdbc_dir}/read_xml_war_path" ];then
	echo "war包路径 未找到,执行退出"
	echo "${ipaddr},warnotfound" >> ${jdbc_dir}/${ipaddr}_${cur_date}.log	
	cat ${jdbc_dir}/${ipaddr}_${cur_date}.log
	exit
else
	#去重操作每个tomcat保留一个包路径
	sort -n ${jdbc_dir}/read_xml_war_path | uniq > ${jdbc_dir}/sort_xml_war_path
	
	sed -i 's#\r##g' ${jdbc_dir}/sort_xml_war_path
	
	#循环tomcat部署路径  将该路径下的所有文件复制到别的目录去操作
	while read line
	do
		echo "line:"$line
		war_name=`find $line -name *.war |grep -vE "docs|examples|host-manager|manager" | sed "s|${line}/||g" | sed "s/.war//g"`
		if [ ! -n "$war_name" ]; then 
			war_name="ROOT"
		fi
		#1.1将ip写入元素文件中
		echo "${ipaddr},ECS" >> ${jdbc_dir}/yuansu
		#1.2将项目名称写入元素文件中
		echo "${war_name},PROJECT" >> ${jdbc_dir}/yuansu
		#2.1将项目和ECSip关系写入关系文件中
		echo "${war_name},"所属ECS",${ipaddr}" >> ${jdbc_dir}/guanxi
		if [ ! -d "${process_files}/${war_name}" ];then
			mkdir -p ${process_files}/${war_name}
		fi
		#拷贝tomcat中的文件到指定文件
		printfile "${line}/${war_name}" "${process_files}/${war_name}"
		#查找jdbc相关信息
		print_jdbc "${process_files}/${war_name}" "${war_name}"

	done < ${jdbc_dir}/sort_xml_war_path
	
	if [ ! -f "${jdbc_dir}/jdbc_p" ];then
		echo 'tomcat jdbc信息未找到!'
		exit
	else
		sort -n ${jdbc_dir}/yuansu | uniq > ${jdbc_dir}/${ipaddr}_${cur_date}.ys
		sort -n ${jdbc_dir}/guanxi | uniq > ${jdbc_dir}/${ipaddr}_${cur_date}.gx
		#文件传输
		expect -c "
			set timeout 60; ##设置拷贝的时间，根据目录大小决定，我这里是60秒。
			spawn script -q -a ${jdbc_dir}/${ipaddr}_${cur_date}.log -c \"/usr/bin/scp -P ${ecsport} ${jdbc_dir}/${ipaddr}_${cur_date}.ys ${user_name}@${finalECSIp}:/usr/tomcat_process_import/${cur_date}/\"			
			expect {
			\"*yes/no*\" {send \"yes\r\"; exp_continue}
			\"*password:\" {send \"${password}\r\"; exp_continue}
			\"*password*\" {send \"${password}\r\";} 
			}
			spawn script -q -a ${jdbc_dir}/${ipaddr}_${cur_date}.log -c \"/usr/bin/scp -P ${ecsport} ${jdbc_dir}/${ipaddr}_${cur_date}.gx ${user_name}@${finalECSIp}:/usr/tomcat_process_import/${cur_date}/\"			
			expect {
			\"*yes/no*\" {send \"yes\r\"; exp_continue}
			\"*password:\" {send \"${password}\r\"; exp_continue}
			\"*password*\" {send \"${password}\r\";}
			}
			spawn /usr/bin/scp -P ${ecsport} ${jdbc_dir}/${ipaddr}_${cur_date}.log ${user_name}@${finalECSIp}:/usr/tomcat_process_import/${cur_date}_log/
			expect {
			\"*yes/no*\" {send \"yes\r\"; exp_continue}
			\"*password*\" {send \"${password}\r\";}
			}
		expect eof;"
		echo "执行结束,关系结果: "
		cat ${jdbc_dir}/${ipaddr}_${cur_date}.gx
		echo "执行结束,元素结果: "
		cat ${jdbc_dir}/${ipaddr}_${cur_date}.ys
		#删除生成的文件
		rm -rf ${jdbc_dir}
	fi
	
fi

