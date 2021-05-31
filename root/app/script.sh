#!/bin/bash

## Genericized version for Docker packaging
## Credits
# catapultam_habeo - Initial script
# Tomr - Modified version with SNAPSHOT_TYPE

## License
# MIT License
# See included LICENSE document or https://opensource.org/licenses/MIT


#If you change the type you'll have to delete the old snapshots manually
#valid values are: hourly, daily, weekly, monthly
#SNAPSHOT_TYPE=hourly
#How many snapshots should be kept. 
#MAX_SNAPS=24
#Name of the shares to snapshot, can be comma separated like "medias,valuables"
#EXCLUDE=CommunityApplicationsAppdataBackup
#name of the snapshot folder and delimeter. Do not change.
#https://www.samba.org/samba/docs/current/man-html/vfs_shadow_copy2.8.html
SNAPSHOT_DELIMETER="_UTC_"
SNAPSHOT_FORMAT="$(TZ=UTC date +${SNAPSHOT_TYPE}${SNAPSHOT_DELIMETER}%Y.%m.%d-%H.%M.%S)"


shopt -s nullglob #make empty directories not freak out

is_btrfs_subvolume() {
    local dir=$1
    [ "$(stat -f --format="%T" "$dir")" == "btrfs" ] || return 1
    inode="$(stat --format="%i" "$dir")"
    case "$inode" in
        2|256)
            return 0;;
        *)
            return 1;;
    esac
}

#ADJUST MAX_SNAPS to prevent off-by-1
MAX_SNAPS=$((MAX_SNAPS+1))

#Tokenize exclude list
declare -A excludes
for token in ${EXCLUDE//,/ }; do
	excludes[$token]=1
done


#iterate over all disks on array
for disk in /mnt/disk*[0-30]* ; do
#examine disk for btrfs-formatting (MOSTLY UNTESTED)
    if is_btrfs_subvolume $disk ; then 
    #iterate over shares present on disk
        for share in ${disk}/* ; do
            declare baseShare=$(basename $share)
            #test for exclusion
            if [ -n "${excludes[$baseShare]}" ]; then
                echo "$share is on the exclusion list. Skipping..."
            else
                #check for .snapshots directory prior to generating snapshot
                #only before we make the actual snapshot 
                #so we don't create empty folders 
                if [ -d "$disk" ]; then
                    if [ ! -d "$disk/.snapshots/$SNAPSHOT_FORMAT/" ] ; then
                        #echo "new"
                        mkdir -v -p $disk/.snapshots/$SNAPSHOT_FORMAT
                    fi
                fi
            
                #echo "Examining $share on $disk"
                is_btrfs_subvolume $share
                if [ ! "$?" -eq 0 ]; then
                    echo "$share is likely not a subvolume"
                    mv -v ${share} ${share}_TEMP
                    btrfs subvolume create $share
                    cp -avT --reflink=always ${share}_TEMP $share
                    rm -vrf ${share}_TEMP
                fi
                #make new snap
                btrfs subvolume snap -r ${share} $disk/.snapshots/${SNAPSHOT_FORMAT}/$baseShare
            fi
        done
        #find old snaps
        echo "Found $(find ${disk}/.snapshots/${SNAPSHOT_TYPE}${SNAPSHOT_DELIMETER}*/ -maxdepth 0 -mindepth 0 | sort -nr | tail -n +$MAX_SNAPS | wc -l) old snaps"
        for snap in $(find ${disk}/.snapshots/${SNAPSHOT_TYPE}${SNAPSHOT_DELIMETER}*/ -maxdepth 0 -mindepth 0 | sort -nr | tail -n +$MAX_SNAPS); do
            for share_snap in ${snap}/*; do
                btrfs subvolume delete $share_snap
            done
            rmdir $snap --ignore-fail-on-non-empty
        done

    fi
 done
