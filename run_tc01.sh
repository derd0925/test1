#!/bin/bash

echo "Running TC01 - No arguments"

#Run the script and capture the output
actual=$(./assembler.sh)
#echo "$actual"

#Capture the exit code
status=$?
#echo $status

#Expected output
expected="usage: no arg is provided."

#check exit code
if [ "$status" -ne 1 ]; then
    echo "[FAIL] Expected exit code: 1"
    exit 1
fi

#check output contains desired message
if [ "$actual" != "$expected" ]; then
    echo "[FAIL] Expected output: $expected"
    exit 1
fi

echo "[PASS] TC01"
exit 0


