#!/bin/bash

set -euxo pipefail

trap 'mysqladmin --socket=./mysql.sock -u root shutdown || true; rm -rf ./data ./mysql.sock ./mysql.pid' EXIT

echo "===DATABASE TEST START==="
echo "---INITIALIZING DATABASE---"
mysqld --initialize-insecure --datadir=$(pwd)/data --socket=$(pwd)/mysql.sock
echo "---STARTING SERVER---"
mysqld --user=root --datadir=$(pwd)/data --socket=$(pwd)/mysql.sock --pid-file=$(pwd)/mysql.pid --port=33071 &
echo "---WAITING FOR SERVER---"
for i in {1..10}; do
    if mysqladmin --socket=$(pwd)/mysql.sock -u root ping &> /dev/null; then
        break
    fi
    sleep 1
done
echo "---TRYING A QUERY---"
mysql --socket=$(pwd)/mysql.sock -u root -e "SHOW DATABASES;"
echo "===DATABASE TEST END==="
