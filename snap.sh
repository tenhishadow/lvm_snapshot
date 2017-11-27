#!/bin/bash

# This script manage lvm snapshots on your system
# author Stanislav Cherkasov
# version 0.2.1

# Prechecks ###########################################################
[ -z $(which blkid) ] && echo "ERR: no blkid" && exit 1
[ -z $(which lvs) ] && echo "ERR: no lvs" && exit 1
[ -z $(which grep) ] && echo "ERR: no grep" && exit 1
[ -z $(which sed) ] && echo "ERR: no sed" && exit 1
[ -z $(which awk) ] && echo "ERR: no awk" && exit 1
[ -z $(which lvremove) ] && echo "ERR: no lvremove" && exit 1
[ -z $(which lvcreate) ] && echo "ERR: no lvcreate" && exit 1
[ -z $(which date) ] && echo "ERR: no date" && exit 1
(! [ $(whoami) == "root" ]) && echo "ERR: needs to be run from root" && exit 1

# Utils ###############################################################
LVS=$( which lvs )
GRP=$( which grep )
BLKID=$( which blkid )
SED=$(which sed)
AWK=$( which awk )
LVREMOVE=$(which lvremove)
LVCREATE=$(which lvcreate)
LVCONVERT=$(which lvconvert)
DATE=$(`which date` +%Y%m%d%H%M)

# Variables ############################################################
VG="rootvg"
LVSOPT="--noheadings -o lv_name,lv_attr,lv_path"

### Functions ##########################################################

function help {
 # Function for help
echo \
"
Hi, seems like you need to take a look at help
Available options are:
-o      Define origins
-s      Define snapshots
-c      Create snapshots
-r      Remove snapshots
-m      Merge snapshots to origin
"
}

function define_origins {
 # Function for defining original lvs

 # Defining swap lv to exclude it        !~/^s = no snapshots
 for i in $( $LVS $LVSOPT $VG | $AWK '$2 !~ /^s/ { print $3 }' )
 do
  if [[ $( $BLKID $i | $AWK '{print $NF}' | $SED 's/TYPE=//' | $SED 's/"//g' ) = swap ]]
   then
    SWAP=$i
   else
    SWAP="THERE_IS_NO_SWAP_HERE_AT_THE_MOMENT"
  fi
 done
 #                      exclude snapshots               exclude swap
 $LVS $LVSOPT $VG  | $AWK '$2 !~ /^s/ { print $0 }' | $AWK -v SWAP="$SWAP" '$3 !~ SWAP {print $1,$3}'
}

function define_snapshots {
 # Function for defining snapshots

 # Defining swap lv to exclude it           ^s=only snapshots
 for i in $( $LVS $LVSOPT $VG | $AWK '$2 ~ /^s/ { print $3 }' )
 do
  if [[ $( $BLKID $i | $AWK '{print $NF}' | $SED 's/TYPE=//' | $SED 's/"//g' ) = swap ]]
   then
    SWAP=$i
   else
    SWAP="THERE_IS_NO_SWAP_HERE_AT_THE_MOMENT"
  fi
 done
 #                        only snapshots               exclude swap
 $LVS $LVSOPT $VG  | $AWK '$2 ~ /^s/ { print $0 }' | $AWK -v SWAP="$SWAP" '$3 !~ SWAP {print $3}'

}

function create_snapshots {
 # Function for creating snapshots
 # for lv like lvdata it will be lvdata_snap_$DATE

 for i in $( define_origins | awk '{print $1"#separator#"$2}' )
 do
  LVM_PATH=$( echo $i | awk -F "#separator#" '{ print $2 }' )
  LVM_NAME=$( echo $i | awk -F "#separator#" '{ print $1 }' )

  $LVCREATE -s $LVM_PATH -n $LVM_NAME"_"$DATE -L1G
 done
}

function remove_snapshots {
 # Function for removing snapshots

 # avoid action without snapshots
 [ -z $define_snapshots ] && echo "ERR: no snapshots detected" && exit 1

 for SNAPSHOT in $( define_snapshots )
 do
   $LVREMOVE -f $SNAPSHOT
 done
}

function merge_snapshots {
 # Function for simple merging snapshots

 # avoid action without snapshots
 [ -z $define_snapshots ] && echo "ERR: no snapshots detected" && exit 1

 for SNAPSHOT in $( define_snapshots )
 do
   $LVCONVERT --mergesnapshot -f $SNAPSHOT
 done
}

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
 -m)
  merge_snapshots
  ;;
 *)
  help
  ;;
esac
