#!/bin/bash

set -e

# we set gcomm string with cluster_members via ENV by default
CLUSTER_ADDRESS="gcomm://$CLUSTER_MEMBERS?pc.wait_prim=no"

# we use dns service discovery to find other members when in service mode
# and set/override cluster_members provided by ENV
if [ -n "$DB_SERVICE_NAME" ]; then
  
  # we check, if we have to enable bootstrapping, if we are the only/first node live
  if [ `getent hosts tasks.$DB_SERVICE_NAME|wc -l` = 1 ] ;then 
    # bootstrapping gets enabled by empty gcomm string
    CLUSTER_ADDRESS="gcomm://"
  else
    # we fetch IPs of service members
    CLUSTER_MEMBERS=`getent hosts tasks.$DB_SERVICE_NAME|awk '{print $1}'|tr '\n' ','`
    # we set gcomm string with found service members
    CLUSTER_ADDRESS="gcomm://$CLUSTER_MEMBERS?pc.wait_prim=no"
  fi
fi


# we create a galera config
config_file="/etc/mysql/conf.d/galera.cnf"

cat <<EOF > $config_file
# Node specifics 
[mysqld] 
# next 3 params disabled for the moment, since they are not mandatory and get changed with each new instance.
# they also triggered problems when trying to persist data with a backup service, since also the config has to be 
# persisted, but HOSTNAME changes at container startup.
#wsrep-node-name = $HOSTNAME 
#wsrep-sst-receive-address = $HOSTNAME
#wsrep-node-incoming-address = $HOSTNAME

# Cluster settings
wsrep-on=ON
wsrep-cluster-name = "$CLUSTER_NAME" 
wsrep-cluster-address = $CLUSTER_ADDRESS
wsrep-provider = /usr/lib/galera/libgalera_smm.so 
wsrep-provider-options = "gcache.size=256M;gcache.page_size=128M;debug=no" 
wsrep-sst-auth = "$GALERA_USER:$GALERA_PASS" 
wsrep_auto_increment_control=off
wsrep_sst_method = rsync
binlog-format = row 
default-storage-engine = InnoDB 
innodb-doublewrite = 1 
innodb-autoinc-lock-mode = 2 
innodb-flush-log-at-trx-commit = 2 
EOF



# we create a character-set config
config_file2="/etc/mysql/conf.d/character-set.cnf"

cat <<EOF > $config_file2
[client]
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4

[mysqld]
character-set-client-handshake = FALSE
collation-server = utf8mb4_unicode_ci
init-connect = 'SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci'
character-set-server = utf8mb4
EOF
