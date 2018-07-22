#!/usr/bin/env bash

cd /home/archvsync/log/centos
ls -t | tail -n +101 | xargs rm --
