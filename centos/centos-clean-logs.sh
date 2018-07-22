#!/usr/bin/env bash

cd <Path to Log directory>/centos
ls -t | tail -n +101 | xargs rm --
