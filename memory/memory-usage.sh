#!/bin/sh

grep -E 'MemTotal|MemAvailable' /proc/meminfo | xargs | awk '{printf "%.2f", 1-$5/$2}'
