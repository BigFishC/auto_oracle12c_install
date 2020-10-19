#!/bin/bash
#################### Install oracle software ####################
#script_name: install_oracle_software.sh                        #
#Author: Liu                                                    #
#Email:507886080@qq.com                                         #
#install_oracle12c_shell version=12.2.0.1                       #
#################################################################
#上传12c软件安装包至随意路径下,脚本提示路径是 /opt                 #
#                                                               # 
#数据库安装文件名为：linuxx64_12201_database.zip                 #
#                                                               #
#预设oracle用户的密码为  oracle                                  #
#################### Install oracle software ####################

export PATH=$PATH
#Source function library.
. /etc/init.d/functions

#Require root to run this script.
uid=`id | cut -d\( -f1 | cut -d= -f2`
if [ $uid -ne 0 ];then
    action "Please run this script as root." /bin/false
    exit 1
fi

##set oracle password
ORACLE_OS_PWD=
if [ "$ORACLE_OS_PWD" = "" ]; then
    ORACLE_OS_PWD="oracle"
fi

###install require packages
echo -e "\033[34mInstallNotice >>\033[0m \033[32moracle install dependency \033[05m...\033[0m"
yum -y install binutils compat-libcap1 compat-libstdc++-33 compat-libstdc++-33*i686 compat-libstdc++-33*.devel \
compat-libstdc++-33 compat-libstdc++-33*.devel elfutils-libelf elfutils-libelf-devel gcc gcc-c++ \
glibc glibc*.i686 glibc-devel glibc-devel*.i686 ksh libaio libaio*.i686 libaio-devel libaio-devel*.devel \
libgcc libgcc*.i686 libstdc++ libstdc++*.i686 libstdc++-devel libstdc++-devel*.devel libXi libXi*.i686 \
libXtst libXtst*.i686 make sysstat unixODBC unixODBC*.i686 unixODBC-devel unixODBC-devel*.i686 zip unzip tree \
vim lrzsz epel-release net-tools wget ntpdate ntp
if [[ $? == 0 ]];then
    echo -e "\033[34mInstallNotice >>\033[0m \033[32myum install dependency successed\033[0m"
else
    echo -e "\033[34mInstallNotice >>\033[0m \033[32myum install dependency faild, pls check your network\033[0m"
exit
fi

###set firewalld & optimize the os system & set selinux
echo "################# Optimize system parameters ##########################"

SELINUX=`cat /etc/selinux/config |grep ^SELINUX=|awk -F '=' '{print $2}'`
if [ ${SELINUX} == "enforcing" ];then
    sed -i "s@SELINUX=enforcing@SELINUX=disabled@g" /etc/selinux/config
else
    if [ ${SELINUX} == "permissive" ];then
        sed -i "s@SELINUX=permissive@SELINUX=disabled@g" /etc/selinux/config
    fi
fi
setenforce 0

echo "================更改为英文字符集================="
\cp /etc/locale.conf /etc/locale.conf.$(date +%F)
cat >/etc/locale.conf<<EOF
#LANG="zh_CN.UTF-8"
LANG="en_US.UTF-8"
EOF
source /etc/locale.conf
grep LANG /etc/locale.conf
action "更改字符集en_US.UTF-8完成" /bin/true
echo "================================================="

###set the ip in hosts
echo "############################ Ip&Hosts Configuration #######################################"
hostname=`hostname`
HostIP=`ip a|grep 'inet '|grep -v '127.0.0.1'|awk '{print $2}'|awk -F '/' '{print $1}'`
for i in ${HostIP}
do
    A=`grep "${i}" /etc/hosts`
    if [ ! -n "${A}" ];then
        echo "${i} ${hostname}" >> /etc/hosts
    else
        break
    fi
done

###create group&user
echo "############################ Create Group&User #######################################"
ora_user=oracle
ora_group=('oinstall' 'dba' 'oper')
for i in ${ora_group[@]}
do
    B=`grep '${i}' /etc/group`
    if [ ! -n ${B} ];then
        groupdel ${i} && groupadd ${i}
    else
    groupadd ${i}
    fi
done
C=`grep 'oracle' /etc/passwd`
if [ ! -n ${C} ];then
    userdel -r ${ora_user} && useradd -u 501 -g ${ora_group[0]} -G ${ora_group[1]},${ora_group[2]} ${ora_user}
else
    useradd -u 501 -g ${ora_group[0]} -G ${ora_group[1]},${ora_group[2]} ${ora_user}
fi
echo "${ORACLE_OS_PWD}" | passwd --stdin ${ora_user}

###create directory and grant priv
echo "############################ Create DIR & set privileges & set OracleSid ##################"
echo "############################ Create OracleBaseDir #######################################"
echo "############################ Create OracleHomeDir #######################################"
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the ORACLE_SID(e.g:orcl):" S1
    read -p "Please input the ORACLE_SID again(e.g:orcl):" S2
    if [ "${S1}" == "${S2}" ];then
        export ORACLE_SID=${S1}
        break
    else
        echo "You input ORACLE_SID not same."
        count=$[${count}+1]
    fi
done
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the ORACLE_BASE(e.g:/u01/app/oracle):" S1
    read -p "Please input the ORACLE_BASE again(e.g:/u01/app/oracle):" S2
    if [ "${S1}" == "${S2}" ];then
        export ORACLE_BASE=${S1}
        break
    else
        echo "You input ORACLE_BASE not same."
        count=$[${count}+1]
    fi
done
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the ORACLE_HOME(e.g:/u01/app/oracle/product/12.2.0.1/db_1):" S1
    read -p "Please input the ORACLE_HOME again(e.g:/u01/app/oracle/product/12.2.0.1/db_1):" S2
    if [ "${S1}" == "${S2}" ];then
        export ORACLE_HOME=${S1}
        break
    else
        echo "You input ORACLE_HOME not same."
        count=$[${count}+1]
    fi
done
if [ ! -d ${ORACLE_HOME} ];then
    mkdir -p ${ORACLE_HOME}
fi
if [ ! -d ${ORACLE_BASE}/oradata ];then
    mkdir -p ${ORACLE_BASE}/oradata
fi
if [ ! -d ${ORACLE_BASE}/oradata_back ];then
    mkdir -p ${ORACLE_BASE}/oradata_back
fi
ora_dir=`echo ${ORACLE_BASE}|awk -F '/' '{print $2}'`

###set the sysctl,limits and profile
echo "############################ Configure environment variables #######################################"
D=`grep 'fs.aio-max-nr' /etc/sysctl.conf`
if [ ! -n "${D}" ];then
cat << EOF >> /etc/sysctl.conf
kernel.shmmax = 68719476736
kernel.shmmni = 4096
kernel.shmall = 16777216
kernel.sem = 1010 129280 1010 128
net.ipv4.ip_local_port_range = 9000 65500
net.core.rmem_default = 4194304
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
fs.file-max = 6815744
EOF
/sbin/sysctl -p
else
continue
fi
E=`grep 'oracle' /etc/security/limits.conf`
if [ ! -n "${E}" ];then
cat << EOF >> /etc/security/limits.conf
oracle soft nproc 2047
oracle hard nproc 16384
oracle soft nofile 1024
oracle hard nofile 65536
oracle soft stack 10240
EOF
else
continue
fi
F=`grep 'ORACLE_SID' /home/${ora_user}/.bash_profile`
if [ ! -n "${F}" ];then
cat << EOF >> /home/${ora_user}/.bash_profile
export ORACLE_BASE=${ORACLE_BASE}
export ORACLE_HOME=${ORACLE_HOME}
export ORACLE_SID=${ORACLE_SID}
export PATH=.:${PATH}:$ORACLE_HOME/bin:/bin:/usr/bin:/usr/sbin:/usr/local/bin
export LD_LIBRARY_PATH=$ORACLE_HOME/lib:${LD_LIBRARY_PATH}

export LC_ALL=C
export LANG=en_US.UTF-8
export NLS_DATE_FORMAT="mm/dd/yyyy hh24:mi:ss"
export NLS_LANG=american_america.AL32UTF8
EOF
else
continue
fi
G=`grep 'oracle' /etc/profile`
if [ ! -n "${G}" ];then
cat << EOF >> /etc/profile
if [ \$USER = "oracle" ];then
if [ \$SHELL = "/bin/ksh" ];then
ulimit -p 16384
ulimit -n 65536
else
ulimit -u 16384 -n 65536
fi
fi
EOF
else
continue
fi

###unzip the install package and set response file
echo "############################ unzip the install package #######################################"
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the zip file location(e.g:/opt/linuxx64_12201_database.zip):" zfile
    if [ ! -f ${zfile} ];then
        echo "You input location not found zip file."
        count=$[${count}+1]
    else
        export zfile=${zfile}
        break
    fi
done
unzip ${zfile} -d /${ora_dir} && chown -R ${ora_user}:${ora_group[0]} /${ora_dir} && chmod -R 775 /${ora_dir}

###set Oracle install.db.starterdb SysPassword
echo "############################ set SysPassword #######################################"
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the SysPassword(e.g:orcl20200202):" S1
    read -p "Please input the SysPassword again(orcl20200202):" S2
    if [ "${S1}" == "${S2}" ];then
        export SysPassword=${S1}
        break
    else
        echo "You input SysPassword not same."
        count=$[${count}+1]
    fi
done

###set Oracle install.db.starterdb SystemPassword
echo "############################ set SystemPassword #######################################"
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the SystemPassword(e.g:orcl20200202):" S1
    read -p "Please input the SystemPassword again(orcl20200202):" S2
    if [ "${S1}" == "${S2}" ];then
        export SystemPassword=${S1}
        break
    else
        echo "You input SystemPassword not same."
        count=$[${count}+1]
    fi
done

###set Oracle install.db.starterdb PDBadminPassword
echo "############################ set PDBadminPassword #######################################"
count=0
while [ $count -lt 3 ]
do
    read -p "Please input the PDBadminPassword(e.g:orcl20200202):" S1
    read -p "Please input the PDBadminPassword again(orcl20200202):" S2
    if [ "${S1}" == "${S2}" ];then
        export PDBadminPassword=${S1}
        break
    else
        echo "You input PDBadminPassword not same."
        count=$[${count}+1]
    fi
done

###set Response File
echo "############################ set db_install ResponseFile #######################################"
db_response_file=`find /${ora_dir}/database -type f -name db_install.rsp`
free_m=`free -m | grep 'Mem:'|awk '{print $2}'`
if [[ $?==0 ]];then
cat << EOF > ${db_response_file}
oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.2.0
oracle.install.option=INSTALL_DB_SWONLY
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION=${ORACLE_BASE}/oraInventory
ORACLE_HOME=${ORACLE_HOME}
ORACLE_BASE=${ORACLE_BASE}
oracle.install.db.InstallEdition=EE
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=dba
oracle.install.db.OSBACKUPDBA_GROUP=dba
oracle.install.db.OSDGDBA_GROUP=dba
oracle.install.db.OSKMDBA_GROUP=dba
oracle.install.db.OSRACDBA_GROUP=dba
oracle.install.db.config.starterdb.type=GENERAL_PURPOSE
oracle.install.db.config.starterdb.globalDBName=${ORACLE_SID}
oracle.install.db.config.starterdb.SID=${ORACLE_SID}
oracle.install.db.config.starterdb.characterSet=AL32UTF8
oracle.install.db.config.starterdb.memoryLimit=$[${free_m}*8/10]
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
EOF
else
continue
fi

###starting to install oracle software
echo "############################ Oracle Installing #######################################"
intall_dir=`find /${ora_dir}/database -type f -name runInstaller`
oracle_out='/tmp/oracle.out'
su - oracle -c "${intall_dir} -silent -noconfig -responseFile ${db_response_file}" > ${oracle_out} 2>&1
echo -e "\033[34mInstallNotice >>\033[0m \033[32moracle install starting \033[05m...\033[0m"
sleep 60
installActionslog=`find /tmp -name installActions*`
echo "You cat check the oracle install log command: tail -100f ${installActionslog}"
while true; do
    grep '[FATAL] [INS-10101]' ${oracle_out} &> /dev/null
    if [[ $? == 0 ]];then
        echo -e "\033[34mInstallNotice >>\033[0m \033[31moracle start install has [ERROR]\033[0m"
        cat ${oracle_out}
        exit
    fi
    sleep 120
    cat /tmp/oracle.out | grep sh
    if [[ $? == 0 ]];then
        `cat /tmp/oracle.out | grep sh | awk -F ' ' '{print $2}' | head -1`
        if [[ $? == 0 ]]; then
            echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript orainstRoot.sh run successed\033[0m"
            `cat /tmp/oracle.out | grep sh | awk -F ' ' '{print $2}' | tail -1`
            if [[ $? == 0 ]];then
                echo -e "\033[34mInstallNotice >>\033[0m \033[32mScript root.sh run successed\033[0m"
                break
            else
                echo -e "\033[34mInstallNotice >>\033[0m \033[31mScript root.sh run faild\033[0m"
            fi
        else
            echo -e "\033[34mInstallNotice >>\033[0m \033[31mScript orainstRoot.sh run faild\033[0m"
        fi
    fi
done

echo "####################### Oracle software 安装完成 ##############################"

echo "############################ set ResponseFile #######################################"
dbca_file=`find /${ora_dir}/database -type f -name dbca.rsp`
if [[ $?==0 ]];then
cat<< EOF > ${dbca_file}
responseFileVersion=/oracle/assistants/rspfmt_dbca_response_schema_v12.2.0
gdbName=${ORACLE_SID}
sid=${ORACLE_SID}
databaseConfigType=SI
policyManaged=false
createServerPool=false
force=false
createAsContainerDatabase=true
numberOfPDBs=1
pdbName=acloud1
useLocalUndoForPDBs=true
templateName=${ORACLE_HOME}/assistants/dbca/templates/General_Purpose.dbc
emExpressPort=5500
runCVUChecks=false
omsPort=0
dvConfiguration=false
olsConfiguration=false
datafileJarLocation=${ORACLE_HOME}/assistants/dbca/templates/
datafileDestination=${ORACLE_BASE}/oradata/${DB_UNIQUE_NAME}/
recoveryAreaDestination=${ORACLE_BASE}/fast_recovery_area/${DB_UNIQUE_NAME}
storageType=FS
characterSet=AL32UTF8
nationalCharacterSet=UTF8
registerWithDirService=false
listeners=LISTENER
variables=DB_UNIQUE_NAME=${ORACLE_SID},ORACLE_BASE=${ORACLE_BASE},PDB_NAME=,DB_NAME=${ORACLE_SID},ORACLE_HOME=${ORACLE_HOME},SID=${ORACLE_SID}
sampleSchema=false
memoryPercentage=40
databaseType=MULTIPURPOSE
automaticMemoryManagement=false
totalMemory=0
EOF
else
continue
fi


###set listener&tnsnames
echo "############################ Oracle listener && dbca #######################################"
NETCA=`find /${ora_dir}/database -type f -name netca.rsp`
su - oracle << EOF
source ~/.bash_profile
${ORACLE_HOME}/bin/netca -silent -responsefile ${NETCA} >/tmp/oracle.out 2>&1
sleep 10
dbca -silent -createDatabase -sysPassword ${SysPassword} -systemPassword ${SystemPassword} -pdbadminPassword ${PDBadminPassword} -responseFile ${dbca_file} >/tmp/oracle.out 2>&1
EOF
echo "####################### oracle listener && dbca 安装完成 请记录数据库信息 ##############################"
