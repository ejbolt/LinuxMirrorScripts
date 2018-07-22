#!/usr/bin/env bash

cd /home/archvsync/log/ubuntu
ls -t | tail -n +101 | xargs rm --

cd /home/archvsync/log/ubuntu-cdimage
ls -t | tail -n +21 | xargs rm --

cd /home/archvsync/log/ubuntu-releases
ls -t | tail -n +21 | xargs rm --

