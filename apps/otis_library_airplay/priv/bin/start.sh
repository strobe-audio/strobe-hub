#!/usr/bin/env sh

port=$1
msg=$2

echo "$msg" | nc -u 127.0.0.1 $port
