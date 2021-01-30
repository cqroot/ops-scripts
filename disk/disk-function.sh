#!/bin/bash

system_device=$(lsblk | grep part | grep '/$' | awk '{print $1}' | tr -cd 'a-z')
echo $system_device
