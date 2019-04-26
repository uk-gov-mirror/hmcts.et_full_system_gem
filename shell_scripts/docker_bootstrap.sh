#!/bin/bash
mkdir /home/app/public
sudo chown app:app /home/app/full_system/systems/et1/public/apply/assets
sudo chown app:app /home/app/full_system/systems/et3/public/assets
sudo chown app:app /home/app/full_system/systems/admin/public/assets
sudo chown app:app /home/app/full_system/systems/et1/node_modules
sudo chown app:app /home/app/full_system/systems/et1/log
sudo chown app:app /home/app/full_system/systems/et3/log
sudo chown app:app /home/app/full_system/systems/admin/log
sudo chown app:app /home/app/full_system/systems/api/log
sudo chown app:app /home/app/full_system/systems/atos/lib/rails_container/log
sudo chown app:app /home/app/full_system/systems/et3/node_modules
sudo chown app:app /home/app/full_system/systems/admin/node_modules
sudo chown app:app /home/app/full_system/systems/et1/.bundle
sudo chown app:app /home/app/full_system/systems/et3/.bundle
sudo chown app:app /home/app/full_system/systems/api/.bundle
sudo chown app:app /home/app/full_system/systems/admin/.bundle
sudo chown app:app /home/app/full_system/systems/atos/.bundle
sudo chown app:app /home/app/minio_data
sudo chown app:app /home/app/azure_storage_data
