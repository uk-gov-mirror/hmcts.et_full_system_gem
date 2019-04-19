#!/bin/sh
# `/sbin/setuser memcache` runs the given command as the user `memcache`.
# If you omit that part, the command will be run as root.
export executable=blob
exec /sbin/setuser app azurite -l /home/app/azure_storage_data  >>/var/log/azure_storage.log 2>&1
