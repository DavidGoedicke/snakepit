#!/usr/bin/env bash

pit_root="/data/rw/pit"
touch ${pit_root}/daemon.log
print_log () {
    echo "[daemon] $1" >>${pit_root}/daemon.log
}

if [ -f "${pit_root}/run" ]; then
    print_log "This pit already ran. Requesting stop..."
    touch "${pit_root}/stop"
fi
touch "${pit_root}/run"

readarray -t interfaces < <(ip l | awk -F ":" '/^[0-9]+:/{dev=$2 ; if ( dev !~ /^ lo$/) {print $2}}')
for i in "${interfaces[@]// /}" ; do
        iface=`echo $i | cut -d'@' -f 1`
        dhclient $iface || true
done

for worker_dir in ${pit_root}/workers/*/ ; do
    worker_dir=${worker_dir%*/}
    touch "${worker_dir}/worker.log"
    chown -R worker:worker "${worker_dir}"
done

tail -F -q ${pit_root}/daemon.log ${pit_root}/workers/**/worker.log | ts '[%Y-%m-%d %H:%M:%S]' >${pit_root}/pit.log &

print_log "Pit daemon started"
while true; do
    for worker_dir in ${pit_root}/workers/*/ ; do
        worker_dir=${worker_dir%*/}
        worker_index=${worker_dir##*/}
        if [ -f "${worker_dir}/stop" ]; then
            print_log "Worker ${worker_index} requested stop. Stopping pit..."
            touch "${pit_root}/stop"
        fi
    done
	sleep 1
done
