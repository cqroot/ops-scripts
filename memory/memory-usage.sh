#!/bin/sh

cat /proc/meminfo | egrep 'MemTotal|MemAvailable' | xargs | awk '{printf "%.2f", 1-$5/$2}'
