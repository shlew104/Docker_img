#!/bin/bash
echo "Script started at $(date)" >> /tmp/drop_member.log

source ~/.bashrc
set -euxo pipefail
GOLDILOCKS_HOME=/home/sunje/goldilocks_home
GLOBAL_MASTER=GOLDILOCKS-0

c=`echo $HOSTNAME | awk -F'-' '{print $2}'`

case $c in
0)
GROUP_NAME=G1

gsql sys gliese --as sysdba <<EOF
shutdown abort;
\q
EOF
;;

1)
GROUP_NAME=G2

gsqlnet sys gliese --as sysdba --dsn=$GLOBAL_MASTER <<EOF
ALTER DATABASE REBALANCE EXCLUDE CLUSTER GROUP $GROUP_NAME;
\q
EOF

sleep 1;

gsql sys gliese --as sysdba <<EOF
shutdown abort;
\q
EOF

gsqlnet sys gliese --as sysdba --dsn=$GLOBAL_MASTER <<EOF
DROP CLUSTER GROUP $GROUP_NAME;
\q
EOF

sleep 1;
;;

2)
GROUP_NAME=G3

gsqlnet sys gliese --as sysdba --dsn=$GLOBAL_MASTER << EOF
ALTER DATABASE REBALANCE EXCLUDE CLUSTER GROUP $GROUP_NAME;
\q
EOF

sleep 1;

gsql sys gliese --as sysdba <<EOF
shutdown abort;
\q
EOF

gsqlnet sys gliese --as sysdba --dsn=$GLOBAL_MASTER << EOF
DROP CLUSTER GROUP $GROUP_NAME;
\q
EOF

sleep 1;
;;

3)
GROUP_NAME=G4

gsqlnet sys gliese --as sysdba --dsn=$GLOBAL_MASTER << EOF
ALTER DATABASE REBALANCE EXCLUDE CLUSTER GROUP $GROUP_NAME;
\q
EOF

sleep 1;

gsql sys gliese --as sysdba <<EOF
shutdown abort;
\q
EOF

gsqlnet sys gliese --as sysdba --dsn=$GLOBAL_MASTER << EOF
DROP CLUSTER GROUP $GROUP_NAME;
\q
EOF

sleep 1;
;;

4)
GROUP_NAME=G5

gsqlnet sys gliese --as sysdba --dsn=$GLOBAL_MASTER << EOF
ALTER DATABASE REBALANCE EXCLUDE CLUSTER GROUP $GROUP_NAME;
\q
EOF

sleep 1;

gsql sys gliese --as sysdba <<EOF
shutdown abort;
\q
EOF

gsqlnet sys gliese --as sysdba --dsn=$GLOBAL_MASTER << EOF
DROP CLUSTER GROUP $GROUP_NAME;
\q
EOF

sleep 1;
;;

esac

echo "Script ended at $(date)" >> /tmp/drop_member.log
