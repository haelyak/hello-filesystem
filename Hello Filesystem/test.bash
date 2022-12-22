#!/bin/bash
cd /home/ktsai/courses/cs137/Working
./hello foo 
ls -l foo
cat foo/hello
ls -l .
ls -l ..
ls -l hello
echo "Enter text to write to file"
read text
echo $text > hello.txt
cat hello.txt
# truncate -s 0 hello.txt
umount foo