#!/bin/bash
echo "============ entry point init.sh ==============="
# 현재 사용자의 홈 디렉토리 내용을 나열합니다.
ls -al /home/sunje

# 기존 .bashrc 파일 삭제 및 새로 복사
rm ~/.bashrc
cp /home/sunje/goldilocks_home/bashrc-init ~/.bashrc
cp /home/sunje/goldilocks_home/gsql.ini ~/.gsql.ini

# 새로 복사한 .bashrc 파일 적용
source ~/.bashrc

# Bash 옵션 설정: -e (오류 발생 시 종료), -u (정의되지 않은 변수 사용 시 종료), -x (명령어 출력), -o pipefail (파이프라인 명령어의 오류를 전파)
#set -euxo pipefail

# DB Cluster property Setting
## c = 몇번째 pod 인지 
c=$(echo $HOSTNAME | awk -F'-' '{print $2}')   
MY_NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
MY_POD_NAME=${HOSTNAME}
lower_pod_name=$MY_POD_NAME
MEMBER_NAME=${lower_pod_name^^}
## ??????
MY_MEMBER_NO=$((c+1))
DB_HOST=$MY_POD_NAME.$MY_POD_SERVICE_NAME
GLOBAL_MASTER=GOLDILOCKS-0
GLOBAL_MASTER_DB_HOST=goldilocks-0.$MY_POD_SERVICE_NAME
CLUSTER_PORT=${CLUSTER_PORT:-10101}

# DB server property setting 
#TABLE_SPACE_SIZE=${TABLE_SPACE_SIZE:-824M}
TABLE_UNDO_SIZE=${TABLE_UNDO_SIZE:-224M}
TABLE_SPACE_NAME=${TABLE_SPACE_NAME:-MEM_DATA_TBS}
TABLE_UNDO_NAME=${TABLE_UNDO_NAME:-MEM_UNDO_TBS}
TABLE_SPACE_FILE_NAME=${TABLE_SPACE_FILE_NAME:-data_01.dbf}
TABLE_UNDO_FILE_NAME=${TABLE_UNDO_FILE_NAME:-undo_01.dbf}
#TEMP_TABLESPACE_SIZE=${TEMP_TABLESPACE_SIZE:-824M}
TEMP_TABLESPACE_NAME=${TEMP_TABLESPACE_NAME:-MEM_TEMP_TBS}
TEMP_TABLESPACE_FILE_NAME=${TEMP_TABLESPACE_FILE_NAME:-temp_01}
SERVICE_ACCOUNT_NAME=${SERVICE_ACCOUNT_NAME:-tt}
SERVICE_ACCOUNT_PASSWD=${SERVICE_ACCOUNT_PASSWD:-tt}
GOLDILOCKS_HOME=/home/sunje/goldilocks_home
# export ODBCINI=/home/sunje/goldilocks_data/$MY_NAMESPACE/$MY_POD_NAME/conf/odbc.ini

## 삭제하는게 맞는지 의문 
rm -rf /home/sunje/goldilocks_data/$MY_NAMESPACE/$MY_POD_NAME

# 새 데이터 디렉토리 생성 및 초기화 데이터 복사
mkdir -p /home/sunje/goldilocks_data/$MY_NAMESPACE/$MY_POD_NAME
export GOLDILOCKS_DATA=/home/sunje/goldilocks_data/$MY_NAMESPACE/$MY_POD_NAME
cp /home/sunje/goldilocks_data_create/init-data/* /home/sunje/goldilocks_data/$MY_NAMESPACE/$MY_POD_NAME -R
echo $GOLDILOCKS_DATA

# 클러스터 그룹 및 마스터 설정

case $c in
0)
    GROUP_NAME=G1
    DOMAIN_MASTER_DB_HOST=goldilocks-0.$MY_POD_SERVICE_NAME
    MASTER=$APP_NAME'-0';;
1)
    GROUP_NAME=G2
    DOMAIN_MASTER_DB_HOST=goldilocks-1.$MY_POD_SERVICE_NAME
    MASTER=$APP_NAME'-1'
    MASTER_OG=$APP_NAME'-0';;
2)
    GROUP_NAME=G3
    DOMAIN_MASTER_DB_HOST=goldilocks-2.$MY_POD_SERVICE_NAME
    MASTER=$APP_NAME'-2'
    MASTER_OG=$APP_NAME'-0';;
3)
    GROUP_NAME=G4
    DOMAIN_MASTER_DB_HOST=goldilocks-3.$MY_POD_SERVICE_NAME
    MASTER=$APP_NAME'-3'
    MASTER_OG=$APP_NAME'-0';;
esac

# 클러스터 초기화 함수 정의
function init_cluster(){


    # GOLDILOCKS-0
    if [ $MEMBER_NAME == $MASTER ]; then
        echo "-------------------------start master-------------------"
        # lower_name=$MY_POD_NAME
        # MASTER_NAME=${lower_name^^}
        MASTER_NAME=$MEMBER_NAME

        if [ $GROUP_NAME == "G1" ]; then
            # HOST는 goldilocks-0.svc-memdb
            gcreatedb --cluster --member "$MEMBER_NAME" --host $DB_HOST --port $CLUSTER_PORT

            gsql sys gliese --as sysdba <<EOF
STARTUP
ALTER SYSTEM OPEN GLOBAL DATABASE;
\q
EOF

            gsql sys gliese --as sysdba <<EOF
CREATE CLUSTER GROUP $GROUP_NAME CLUSTER MEMBER "$MASTER_NAME" HOST '$DB_HOST' PORT $CLUSTER_PORT;
#ALTER TABLESPACE $TABLE_SPACE_NAME ADD DATAFILE '$TABLE_SPACE_FILE_NAME' SIZE 824M;
#ALTER TABLESPACE $TEMP_TABLESPACE_NAME ADD MEMORY '$TEMP_TABLESPACE_FILE_NAME' SIZE 1080M;
#ALTER TABLESPACE $TABLE_UNDO_NAME ADD DATAFILE '$TABLE_UNDO_FILE_NAME' SIZE $TABLE_UNDO_SIZE;
CREATE USER $SERVICE_ACCOUNT_NAME IDENTIFIED BY $SERVICE_ACCOUNT_PASSWD DEFAULT TABLESPACE $TABLE_SPACE_NAME TEMPORARY TABLESPACE $TEMP_TABLESPACE_NAME;
GRANT ALL ON DATABASE TO $SERVICE_ACCOUNT_NAME;
#ALTER DATABASE REBALANCE;
\q
EOF

            gsql sys gliese --as sysdba -i $GOLDILOCKS_HOME/admin/cluster/DictionarySchema.sql --silent
            gsql sys gliese --as sysdba -i $GOLDILOCKS_HOME/admin/cluster/InformationSchema.sql --silent
            gsql sys gliese --as sysdba -i $GOLDILOCKS_HOME/admin/cluster/PerformanceViewSchema.sql --silent

            # # glocator 생성 및 시작
            # glocator --create
            # glocator --start

#             gloctl <<EOF
# ADD MEMBER '$MEMBER_NAME' 'HOST=$MY_POD_IP;PORT=22581';
# QUIT;
# EOF

            # 마스터 DNS 설정
            # MASTER_DNS=$(env | grep MASTER | grep 22581 | grep ADDR | cut -d '=' -f2)
            # cat > /home/sunje/goldilocks_data/$MY_NAMESPACE/$MY_POD_NAME/conf/odbc.ini <<EOF
            cat > /home/sunje/.odbc.ini <<EOF
[GOLDILOCKS]
HOST=127.0.0.1
PORT=22581

[$GLOBAL_MASTER]
HOST=$GLOBAL_MASTER_DB_HOST
PORT=22581
EOF

        # if [ $GROUP_NAME == "G1" ] 
        else
            # 슬레이브 초기화
            gcreatedb --cluster --member "$MEMBER_NAME" --host $DB_HOST --port $CLUSTER_PORT
            gsql sys gliese --as sysdba <<EOF
STARTUP
ALTER SYSTEM OPEN GLOBAL DATABASE;
#ALTER TABLESPACE $TABLE_SPACE_NAME ADD DATAFILE '$TABLE_SPACE_FILE_NAME' SIZE 824M;
#ALTER TABLESPACE $TEMP_TABLESPACE_NAME ADD MEMORY '$TEMP_TABLESPACE_FILE_NAME' SIZE 1080M;
#ALTER TABLESPACE $TABLE_UNDO_NAME ADD DATAFILE '$TABLE_UNDO_FILE_NAME' SIZE $TABLE_UNDO_SIZE;
COMMIT;
\q
EOF

            # MASTER_DNS=$(env | grep MASTER | grep 22581 | grep ADDR | cut -d '=' -f2)
            # cat > /home/sunje/goldilocks_data/$MY_NAMESPACE/$MY_POD_NAME/conf/odbc.ini <<EOF
            cat > /home/sunje/.odbc.ini <<EOF
[GOLDILOCKS]
HOST=127.0.0.1
PORT=22581

[$GLOBAL_MASTER]
HOST=$GLOBAL_MASTER_DB_HOST
PORT=22581
EOF

echo $GLOBAL_MASTER_DB_HOST
echo CREATE CLUSTER GROUP $GROUP_NAME CLUSTER MEMBER "$MEMBER_NAME" HOST '$DB_HOST' PORT $CLUSTER_PORT 

#tail -f

            gsqlnet sys gliese --as sysdba --dsn=$GLOBAL_MASTER <<EOF
CREATE CLUSTER GROUP $GROUP_NAME CLUSTER MEMBER "$MEMBER_NAME" HOST '$DB_HOST' PORT $CLUSTER_PORT;
#ALTER DATABASE REBALANCE;
COMMIT;
EOF
        fi

        echo "-------------------------end master-------------------"

    # if [ $MEMBER_NAME == $MASTER ]
    else
        echo "-------------------------start slave-------------------"
#         MASTER_DNS=$(env | grep MASTER | grep 22581 | grep ADDR | cut -d '=' -f2)

#         cat > /home/sunje/goldilocks_data/$MY_NAMESPACE/$MY_POD_NAME/conf/odbc.ini <<EOF
# [$MASTER]
# HOST=$MASTER_DNS
# PORT=22581
# EOF

        gcreatedb --cluster --member $MEMBER_NAME --host $DB_HOST --port $CLUSTER_PORT
        gsql sys gliese --as sysdba <<EOF
STARTUP
ALTER SYSTEM OPEN GLOBAL DATABASE;
#ALTER TABLESPACE $TABLE_SPACE_NAME ADD DATAFILE '$TABLE_SPACE_FILE_NAME' SIZE 824M;
#ALTER TABLESPACE $TEMP_TABLESPACE_NAME ADD MEMORY '$TEMP_TABLESPACE_FILE_NAME' SIZE 1080M;
#ALTER TABLESPACE $TABLE_UNDO_NAME ADD DATAFILE '$TABLE_UNDO_FILE_NAME' SIZE $TABLE_UNDO_SIZE;
COMMIT;
\q
EOF

            # cat > /home/sunje/goldilocks_data/$MY_NAMESPACE/$MY_POD_NAME/conf/odbc.ini <<EOF

            cat > /home/sunje/.odbc.ini <<EOF
[$GLOBAL_MASTER]
HOST=$GLOBAL_MASTER_DB_HOST
PORT=22581
EOF


#echo $GLOBAL_MASTER
#echo $GLOBAL_MASTER_DB_HOST
#echo ALTER CLUSTER GROUP $GROUP_NAME ADD CLUSTER MEMBER "$MEMBER_NAME" HOST '$DB_HOST' PORT $CLUSTER_PORT 
#tail -f
#            gsqlnet sys gliese --as sysdba --dsn=$GLOBAL_MASTER <<EOF
#ALTER CLUSTER GROUP $GROUP_NAME ADD CLUSTER MEMBER "$MEMBER_NAME" HOST '$DB_HOST' PORT $CLUSTER_PORT;
#ALTER DATABASE REBALANCE;
#COMMIT;
#EOF

        echo "-------------------------end slave-------------------"
    fi

    # 리스너 시작 및 상태 확인
    glsnr --start
    glsnr --status
}

# 클러스터 초기화 및 glocator 클러스터 설정
function glocator_cluster(){
# MASTER
MASTER_NAME=$APP_NAME'-0'
MEMBER_NAME=${lower_name^^}

# glocator add member
#MASTER_DNS=`cat /home/sunje/nfs_volumn/$MY_NAMESPACE/$MASTER_NAME`
MASTER_DNS=$(env | grep MASTER | grep 22581 | grep ADDR | cut -d '=' -f2)
gloctl -i $MASTER_DNS -p 42581 <<EOF
ADD MEMBER '$MEMBER_NAME' 'HOST=$MY_POD_IP;PORT=22581';
QUIT;
EOF

gsql sys gliese --as sysdba <<EOF
ALTER SYSTEM RECONNECT GLOBAL CONNECTION;
QUIT;
EOF
}


# DB CREATE START

init_cluster
# glocator_cluster

touch /home/sunje/db_create_complete.txt

echo $c > /home/sunje/db_create_complete.txt

tail -f $GOLDILOCKS_DATA/trc/system.trc &

wait


