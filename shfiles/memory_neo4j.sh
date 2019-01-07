#!/bin/bash

cur_date=`date +%Y-%m-%d`  
echo "当天日期:"$cur_date

#ifdirec
DIRECTORY=/usr/tomcat_process_import/${cur_date}/
#判断目录内是否有文件。
if [ "`ls -A $DIRECTORY`" = "" ]; then
  echo "$DIRECTORY is empty"
else
	cat /usr/tomcat_process_import/${cur_date}/*.ys >> /usr/merge_files/yuansu_merge_${cur_date}
	cat /usr/tomcat_process_import/${cur_date}/*.gx >> /usr/merge_files/guanxi_merge_${cur_date}
	sort -n /usr/merge_files/yuansu_merge_${cur_date} | uniq > /usr/merge_files/yuansu_merge_${cur_date}.csv
	sort -n /usr/merge_files/guanxi_merge_${cur_date} | uniq > /usr/merge_files/guanxi_merge_${cur_date}.csv
	sed -i '1 i\name,type' /usr/merge_files/yuansu_merge_${cur_date}.csv
	sed -i '1 i\from,guanxi,to' /usr/merge_files/guanxi_merge_${cur_date}.csv
	cp -R /usr/merge_files/yuansu_merge_${cur_date}.csv /usr/soft/neo4j-community-3.4.10/import/
	cp -R /usr/merge_files/guanxi_merge_${cur_date}.csv /usr/soft/neo4j-community-3.4.10/import/
	rm -rf /usr/merge_files/yuansu_merge_${cur_date}
	rm -rf /usr/merge_files/guanxi_merge_${cur_date}
	cd /usr/soft/neo4j-community-3.4.10/bin
expect <<EOF
set timeout 60 
spawn ./cypher-shell
expect { 
"*username*"  {send "neo4j\r"; exp_continue}
"*password*"  {send "123123\r";}
}
expect "neo4j>" { send "LOAD CSV WITH HEADERS FROM \"file:///yuansu_merge_${cur_date}.csv\" AS line MERGE (c:component{name:line.name,type:line.type});\n" } 
expect "neo4j>" { send "LOAD CSV WITH HEADERS FROM \"file:///guanxi_merge_${cur_date}.csv\" AS line match (from:component{name:line.from}),(to:component{name:line.to}) MERGE (from)-\[r:属于{guanxi:line.guanxi}\]->(to);\n" }
expect "neo4j>" { send ":exit\n" } 
EOF
fi