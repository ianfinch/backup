#!/bin/sh

# Create a backup of any directories on my NAS, which I need to keep
# backed up.  Each directory is copied to a tarball, which is then
# PGP-encrypted (using asymmetric encryption).  These are then placed in a
# "Backups" volume, from where they can be copied to long-term archive (e.g.
# AWS Glacier).  This approach means that the directories themselves are
# encrypted locally, transferred encrypted, then stored encrypted.  By doing
# this on a per-directory basis, we should be working at a manageable
# granularity.

# Various settings
volume=/volume1
backupDir=$volume/Backups
archiveDir=${backupDir}/Archives
tempArchive=${backupDir}/temp-archive.tar.gz
dataDir=${backupDir}/data
logDir=${backupDir}/logs
logfile=$logDir/$(date -I).log

# We need a log directory
if [[ ! -e $logDir ]] ; then
    mkdir -p $logDir
fi
echo "[$(date -Ins)] INFO Started backup run" >> $logfile

# If we don't have a data directory, create one
if [[ ! -e $dataDir ]] ; then
	echo "[$(date -Ins)] INFO No data directory, so created it" >> $logfile
    mkdir -p $dataDir
    echo "#!/bin/sh" > $dataDir/folders.sh.template
    echo "folders=(" >> $dataDir/folders.sh.template
    echo "    Photos:3" >> $dataDir/folders.sh.template
    echo "    homes/example/Documents:1" >> $dataDir/folders.sh.template
    echo "    homes/example/Photos:0" >> $dataDir/folders.sh.template
	echo ")" >> $dataDir/folders.sh.template
fi

# The folders we want to backup.  These are in the format of a directory path
# and a number.  The directory path is the folder to be backed up, and the
# depth is the level below that folder, at which we want separate zip files to
# be created.  For example, if we had the files /a/b/c/x, /a/b/c/y, and
# /a/b/c/z, then the expression a/b:2 will create the zip files /a/b/c/x.zip,
# /a/b/c/y.zip, and /a/b/c/z.zip.
#
# Note that the expressions don't take the leading slash.
#
# Example:
#
#     folders=(
#         Photos:3
#         homes/example/Documents:1
#         homes/example/Photos:0
#     )
#
# For separation, we keep this in another file
source $dataDir/folders.sh

# Go through the folders, identifying each of the folders which need to be
# copied to zip files, ready for backup.
for folder in ${folders[*]} ; do

    path=$(echo $folder | cut -d':' -f1)
    depth=$(echo $folder | cut -d':' -f2)
    echo "[$(date -Ins)] INFO Analysing path ${path}, depth ${depth}" >> $logfile

    # Set both max and min depth to be our desired depth, so we only find
    # directories at the desired depth
    find $volume/$path -mindepth $depth -maxdepth $depth -type d | while read line ; do
        sourceDirectory=$(dirname "$line")
        sourceFileset=$(basename "$line")

        # Ignore any NAS-specific directories
        if [[ "$sourceFileset" != "@eaDir" ]] ; then
            echo "[$(date -Ins)] INFO Identified directory for backup: ${line}" >> $logfile

            # Derive a more unix-y name for the archive file, from the directory name
            archive=$(echo "$sourceFileset" | \
                      tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz' | \
                      sed -e 's/[^a-z0-9]/-/g' -e 's/-s-/s-/g' -e 's/-s$/s/' -e 's/---*/-/g').tar.gz

            # If the backup directory doesn't exist, create it
            targetDir=$archiveDir$(echo "$sourceDirectory" | sed -e "s|^$volume||")
            if [[ ! -e $targetDir ]] ; then
                echo "[$(date -Ins)] INFO Creating directory: ${targetDir}" >> $logfile
                mkdir -p ${targetDir} >> $logfile
            fi

            # If the archive file doesn't exist, we will need to create it
            performBackup="no"
            if [[ ! -e $targetDir/$archive ]] ; then
                performBackup="yes"
                echo "[$(date -Ins)] INFO Archive file does not exist: ${targetDir}/${archive}" >> $logfile
            fi

            # Check for changes made since the last backup
            echo "[$(date -Ins)] WARNING Missing code here!" >> $logfile

            # Actually perform the backup (if needed).  To avoid getting
            # partial archives (if the script crashes for some reason, or gets
            # interrupted), we create the archive as a temporary file, then
            # rename it to the proper location when (if) it completes successfully
            if [[ "$performBackup" == "yes" ]] ; then
                echo "[$(date -Ins)] INFO Creating archive: ${targetDir}/${archive}" >> $logfile
                tar zcvf $tempArchive -C "$sourceDirectory" --exclude='@eaDir' "$sourceFileset" >> $logfile
                tarStatus=$?
                if [[ $tarStatus -eq 0 ]] ; then
                    cp $tempArchive "${targetDir}/${archive}"
                    rm $tempArchive
                else
                    echo "[$(date -Ins)] ERROR Could not create archive: ${targetDir}/${archive}, error: $tarStatus" >> $logfile
                fi
            fi
        fi
    done
done

echo "[$(date -Ins)] INFO Finished backup run" >> $logfile
