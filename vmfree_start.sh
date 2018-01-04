#!/bin/bash

MAINPROJECT="vital-future-191123"
SNAPSHOT="miner"
MTYPE="n1-highcpu-8"
DISK_SIZE="10"

central=("us-central1-a" "us-central1-b" "us-central1-c" "us-central1-f")
east=("us-east1-b" "us-east1-c" "us-east1-d")
west=("us-west1-a" "us-west1-b" "us-west1-c")
config=("b")

echo > list
gcloud projects list | awk '{ print $1 }' | tail -n +2 | while read project
do
echo $project ${central[$RANDOM % ${#central[@]}]} ${config[$RANDOM % ${#config[@]}]} >> list
echo $project ${east[$RANDOM % ${#east[@]}]} ${config[$RANDOM % ${#config[@]}]} >> list
echo $project ${west[$RANDOM % ${#west[@]}]} ${config[$RANDOM % ${#config[@]}]} >> list
done

i=0
echo > vm_proclist.txt
cat list | tail -n +2 | while read PROJECT ZONE CONFIG ; do
((i++))
id=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 5 | head -n 1)
echo vm-$id-$i $PROJECT $ZONE $CONFIG >> vm_proclist.txt
done
cat vm_proclist.txt

cat vm_proclist.txt | tail -n +2| while read INSTANCE PROJECT ZONE CONFIG
do {
  echo Creating $INSTANCE  
  gcloud compute --project $PROJECT disks create $INSTANCE --size $DISK_SIZE --zone $ZONE --type "pd-standard" --source-snapshot https://www.googleapis.com/compute/v1/projects/$MAINPROJECT/global/snapshots/$SNAPSHOT
  gcloud beta compute --project $PROJECT instances create $INSTANCE --zone $ZONE --machine-type $MTYPE --subnet "default" --maintenance-policy "MIGRATE" --no-service-account --no-scopes --min-cpu-platform "Automatic" --disk "name=${INSTANCE},device-name=${INSTANCE},mode=rw,boot=yes,auto-delete=yes"
  for tt in `seq 1 5`
	  do
	  [ "`gcloud compute --project $PROJECT ssh --zone $ZONE $INSTANCE --command "echo ok && exit"`" = "ok" ] && break
	  echo "Waiting for server startup script to finish"
	  sleep 2
	  done
  gcloud compute --project $PROJECT ssh --zone $ZONE $INSTANCE --command "cpulimit -l 600 gcloud-cryptomine/bin/xmr-stak-cpu gcloud-cryptomine/pools/itns_8cpu_$CONFIG & " &
} < /dev/null; done


exit