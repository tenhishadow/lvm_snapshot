#!/bin/bash

# This script manage lvm snapshot on your system
# author Stanislav Cherkaspv
# version 0.1

# Utils
LVS=$( which lvs )
GRP=$( which grep )
BLKID=$( which blkid )
SED=$(which sed)
AWK=$( which awk )
LVREMOVE=$(which lvremove)
LVCREATE=$(which lvcreate)
DATE=$(`which date` +%Y%m%d%H%M)

# Variables
VG="rootvg"
LVSOPT="--noheadings -o lv_name,lv_attr,lv_path"

### Functions #######################################################################################
function help {
echo \
"
Hi, seems like you need to take a look at help
please use -o or -s to define Origins or Snapshots
"
}

function define_origins {
 # Function for defining original lvs
 # Changed 20170927

 # Defining swap lv to exclude it        !~/^s = no snapshots
 for i in $( $LVS $LVSOPT $VG | $AWK '$2 !~ /^s/ { print $3 }' )
 do
  if [[ $( $BLKID $i | $AWK '{print $NF}' | $SED 's/TYPE=//' | $SED 's/"//g' ) = swap ]]
   then
    SWAP=$i
   else
    test
  fi
 done
 #                      exclude snapshots               exclude swap
 $LVS $LVSOPT $VG  | $AWK '$2 !~ /^s/ { print $0 }' | $AWK -v SWAP="$SWAP" '$3 !~ SWAP {print $1,$3}'
}

function define_snapshots {
 # Function for defining snapshots
 # Changed 20170926

 # Defining swap lv to exclude it           ^s=only snapshots
 for i in $( $LVS $LVSOPT $VG | $AWK '$2 ~ /^s/ { print $3 }' )
 do
  if [[ $( $BLKID $i | $AWK '{print $NF}' | $SED 's/TYPE=//' | $SED 's/"//g' ) = swap ]]
   then
    SWAP=$i
   else
    test
  fi
 done
 #                        only snapshots               exclude swap
 $LVS $LVSOPT $VG  | $AWK '$2 ~ /^s/ { print $0 }' | $AWK -v SWAP="$SWAP" '$3 !~ SWAP {print $3}'

}

function create_snapshots {
 # Function for creating snapshots
 # for lv like lvdata it will be lvdata_snap_$DATE
 # Changed 20170927
 A=$( define_origins | awk '{print $1"#separator#"$2}')
 for i in $(echo $A)
 do
  LVM_PATH=$( echo $i | awk -F "#separator#" '{ print $2 }' )
  LVM_NAME=$( echo $i | awk -F "#separator#" '{ print $1 }' )

#  echo "path=" $LVM_PATH
#  echo "name=" $LVM_NAME

  $LVCREATE -s $LVM_PATH -n $LVM_NAME"_"$DATE -L1G
 done
}

function remove_snapshots {
 # Function for removing snapshots
 # Changed 20170927
 for SNAPSHOT in $(define_snapshots )
 do
   $LVREMOVE -f $SNAPSHOT
 done
}

### End Functions ##########################################################################################


### Start Execution ########################################################################################

case "$1" in
 -o)
  define_origins
  ;;
 -s)
  define_snapshots
  ;;
 -c)
  create_snapshots
  ;;
 -r)
  remove_snapshots
  ;;
 *)
  help
  ;;
esac
