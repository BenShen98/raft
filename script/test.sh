#!/bin/bash
no_servers=5
no_clients=5

function get_nclient(){
  cat "$1" | grep -zoPm 1 '"n_clients":\s*\K[^\s,]*' | tr -d '\0'
}

function get_nserver(){
  cat "$1" | grep -zoPm 1 '"n_servers":\s*\K[^\s,]*' | tr -d '\0'
}

WKDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." >/dev/null 2>&1 && pwd )"
# WKDIR=.
TSTDIR=$WKDIR/testplan
OUTDIR=$WKDIR/output

mkdir -p $OUTDIR

for tpath in $TSTDIR/*.json; do
  n_clients=$(get_nclient "$tpath")
  [ -z "$n_clients" ] && n_clients=$no_clients

  n_servers=$(get_nserver "$tpath")
  [ -z "$n_servers" ] && n_servers=$no_servers


  tname="${tpath##*/}"
  tname="${tname%.json}"
  echo "run test on $tname, output to $OUTDIR/$tname.log with $n_clients client, $n_servers server"

  (cd $WKDIR; make run SERVERS=$n_servers CLIENTS=$n_clients CONFIGJSON=$tpath) > $OUTDIR/$tname.log

done

