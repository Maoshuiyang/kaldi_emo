#!/bin/bash

cd `pwd`/../berlin_wav
filenames='ls *.wav'

for file in $filenames;do
    echo ${file} >> filelist
    #echo ${file} | awk '{FS="."} {$1 >> wavname}'
done
