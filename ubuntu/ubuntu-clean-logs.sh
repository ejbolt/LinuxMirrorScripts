#!/usr/bin/env bash

cd <Path to Log Directory>/ubuntu
ls -t | tail -n +101 | xargs rm --

cd <Path to Log Directory>/ubuntu-cdimage
ls -t | tail -n +21 | xargs rm --

cd <Path to Log Directory>/ubuntu-releases
ls -t | tail -n +21 | xargs rm --

