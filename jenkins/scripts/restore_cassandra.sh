#!/bin/bash

# Remove old entries from the tables data dirs
rm -f /var/lib/cassandra/data/dox/*/*
rm -f /var/lib/cassandra/data/zusammen_dox/*/*
rm -f /var/lib/cassandra/data/sdcrepository/*/*
rm -f /var/lib/cassandra/data/sdcartifact/*/*
rm -f /var/lib/cassandra/data/sdcaudit/*/*
rm -f /var/lib/cassandra/data/sdctitan/*/*
rm -f /var/lib/cassandra/data/policy/*/*

# Create cqlsh command file for truncating tables
rm -rf /tmp/cqlshcommands.sh
for KEYSPACE in dox zusammen_dox sdcrepository sdcartifact sdcaudit sdctitan policy
do
  for TABLE in $(ls /var/lib/cassandra/data/$KEYSPACE | awk -F'[-]' '{print $1}')
  do
    echo TRUNCATE $KEYSPACE.$TABLE";" >> /tmp/cqlshcommands.sh
  done
done

# Truncate the tables
cqlsh -f /tmp/cqlshcommands.sh

# Copy the snapshot files to the tables data dirs
for KEYSPACE in dox zusammen_dox sdcrepository sdcartifact sdcaudit sdctitan policy
do
  for TABLE_DIR in $(ls /var/lib/cassandra/data/$KEYSPACE)
  do
    cp /var/lib/cassandra/data/$KEYSPACE/$TABLE_DIR/snapshots/afterDeploy/* /var/lib/cassandra/data/$KEYSPACE/$TABLE_DIR/.
  done
done

# Load the snapshots
echo Load the snapshots
for KEYSPACE in dox zusammen_dox sdcrepository sdcartifact sdcaudit sdctitan policy
do
  for TABLE in $(ls /var/lib/cassandra/data/$KEYSPACE | awk -F'[-]' '{print $1}')
  do
    nodetool refresh $KEYSPACE $TABLE
  done
done

# Synch with all instance
echo Nodetool Repair
nodetool repair
echo restore completed successfully.....
