#!/bin/bash
#
# This is a script to exercise the CS137 hello FUSE assignment.
#    It mounts the specified FUSE module, checks that it contains
#    the expected file with the expected contents (the basic hello
#    example) and then tests to see if file writes work, and update
#    the file to have the expected size and new contents.
#
x_name="hello"
x_contents="Hello World!"
x_plus_newline=1
x_modes="-rw-rw-rw-"
new_short="short"
new_long="And now, for something completely different"

# keeping track of tests and failures
errors=0
total=0

usage () {
    echo "Usage: $0 fuse-module [expected string]" >& 2
    exit 1
}

# block_test file string
#	determine whether or not block write of string works
block_test() {
	file="$1"
	string="$2"

	# get length of the string
	len=`echo "$2" | wc -c`

	# rewrite the file
	echo -n "   overwrite file w/$len bytes ... "
	echo "$string" > "$file"
	if [ $? -ne 0 ]
	then
	    echo "ERROR: overwrite returns $?" >& 2
	    let "errors++"
	else
	    echo "OK"
	fi
	let "total++"

	# check new contents
	contents=`cat "$file"`
	if [ "$contents" == "$string" ]
	then
	    echo "   contents = \"$string\" ... OK" >& 2
	else
	    echo "ERROR: contents \"$contents\", expected \"$string\"" >& 2
	    let "errors++"
	fi
	let "total++"

	# check new size
	output=`ls -l $target | grep -v total`
	size=`echo $output | cut -d' ' -f5`
	if [ $size -eq $len ]
	then
	    echo "   size = $len ... OK" >& 2
	else
	    echo "ERROR: size $size, expected $len" >& 2
	    let "errors++"
	fi
	let "total++"
}

# trunc_test file
#	determine whether or not a truncate operation works
trunc_test() {
	file="$1"

	# force file truncation
	echo -n > "$file"
	if [ $? -eq 0 ]
	then
	    echo "   truncate $file ... OK" >& 2
	else
	    echo "ERROR: truncate $file fails" >& 2
	    let "errors++"
	fi
	let "total++"

	# check the reported length = 0
	output=`ls -l $file | grep -v total`
	size=`echo $output | cut -d' ' -f5`
	if [ $size -eq 0 ]
	then
	    echo "   size = 0 ... OK" >& 2
	else
	    echo "ERROR: size $size, expected 0" >& 2
	    let "errors++"
	fi
	let "total++"

	# check the contents empty
	len=`cat "$file" | wc -c`
	if [ $len -eq 0 ]
	then
	    echo "   contents none ... OK" >& 2
	else
	    echo "ERROR: file not empty, contains $len bytes" >& 2
	    let "errors++"
	fi
	let "total++"
}

# char_test file string
#	determine whether or not char-at-a-time write of string works
#	(this is a test of read/write offset handling)
char_test() {
	file="$1"
	string="$2"

	# get length of the string
	len=`echo "$2" | wc -c`

	# rewrite the file
	echo -n "   overwrite $file (character-at-a-time) w/$len bytes ... "
	echo "$2" | dd "of=$file" bs=1 2> /dev/null
	if [ $? -ne 0 ]
	then
	    echo "ERROR: overwrite returns $?" >& 2
	    let "errors++"
	else
	    echo "OK"
	fi
	let "total++"

	# check new contents
        echo -n "   re-read $file (character-at-a-time) ... "
	contents=`dd "if=$file" bs=1 2>/dev/null`
	if [ $? -ne 0 ]
	then
	    echo "ERROR" >& 2
	    let "errors++"
	else
	    echo "OK" >& 2
	fi
	let "total++"

	if [ "$contents" == "$string" ]
	then
	    echo "   contents ... OK" >& 2
	else
	    echo "ERROR: contents \"$contents\", expected \"$string\"" >& 2
	    let "errors++"
	fi
	let "total++"

	# check new size
	output=`ls -l $target | grep -v total`
	size=`echo $output | cut -d' ' -f5`
	if [ $size -eq $len ]
	then
	    echo "   size = $len ... OK" >& 2
	else
	    echo "ERROR: size $size, expected $len" >& 2
	    let "errors++"
	fi
	let "total++"
}

# random_test file
#	determine whether or not random access writes work
random_test() {
	file="$1"
	orig="0123456"
	upd="01XYZ56"

	echo -n "   write initial pattern ... "
	echo "$orig" > "$file"
	contents=`cat "$file"`
	if [ "$contents" != "$orig" ]
	then
	    echo "ERROR: initial pattern write unsuccessful" >& 2
	    let "errors++"
	else
	    echo "OK"
	fi
	let "total++"
	
	echo -n "   change third byte from 234->XYZ ... "
	echo -n "XYZ" | dd "of=$file" bs=1 seek=2 conv=notrunc,nocreat 2>/dev/null
	contents=`cat "$file"`
	if [ "$contents" != "$upd" ]
	then
	    echo "ERROR: $contents != $upd" >& 2
	    let "errors++"
	else
	    echo "OK"
	fi
	let "total++"
}

# check_access filename expected
#	determine whether or not access(file) returns expected rwx
check_access() {
    result=`./access $1`
    if [ $? -eq 0 ]
    then
    	if [ "$result"=="$2" ]
	then
	    echo "   access($1) == $2 ... OK" >&  2
	else
	    echo "ERROR: access($1) $result != $2" >& 2
	    let "errors++"
	fi
	let "total++"
    elif [ $? -eq 1 ]
    then
        echo "    ... access not implemented" >& 2
    fi
}

# validate the fuse module
if [ -z "$1" ]
then
    usage
elif [ ! -f "$1" ]
then
    echo "$1: no such file" >& 2
    exit 1
elif [ ! -x "$1" ]
then
    echo "$1: not an executable program" >& 2
    exit 1
else
    fuse="$1"
fi

# see if an expected string was specified
if [ -n "$2" ]
then
    x_contents="$2"
fi

# see if a non-default file name was specified
if [ -n "$3" ]
then
    x_name="$3"
fi

# create a mount target and do the mount
target="/tmp/$$"
mkdir $target
echo -n "1. Mounting $fuse on $target ... "
$fuse $target
if [ $? -ne 0 ]
then
    echo "ERROR: $?" >& 2
    exit 1
else
    echo "OK"
fi
let "total++"

# verify correct directory access()->755 ... entry-point no longer used
# check_access $target "r-x"

# verify file type and modes
output=`ls -l $target | grep -v total`
modes=`echo $output | cut -d' ' -f1`
if [ "$modes" == "$x_modes" ]
then
    echo "   modes = $x_modes ... OK" >& 2
else
    echo "ERROR: modes $modes, expected $x_modes" >& 2
    let "errors++"
fi
let "total++"

# verify expected file name
name=`echo $output | cut -d' ' -f9`
if [ "$name" == "$x_name" ]
then
    echo "   name = $x_name ... OK" >& 2
else
    echo "ERROR: name $name, expected $x_name" >& 2
    let "errors++"
fi
let "total++"

# verify correct file access()->666 ... entry-point no longer used
# check_access $target/$name "rw-"

# verify expected file contents
contents=`cat "$target/$name"`
if [ "$contents" == "$x_contents" ]
then
    echo "   contents = \"$x_contents\" ... OK" >& 2
else
    echo "ERROR: contents \"$contents\", expected \"$x_contents\"" >& 2
    let "errors++"
fi
let "total++"

# verify expected file size
size=`echo $output | cut -d' ' -f5`
x_size=${#contents}
if [[ $x_plus_newline > 0 ]]
then
    let "x_size = x_size + x_plus_newline"
fi
if [ $size -eq $x_size ]
then
    echo "   size = $x_size ... OK" >& 2
else
    echo "ERROR: size $size, expected $x_size" >& 2
    let "errors++"
fi
let "total++"

# test update with short line
echo "2. overwrite file with short string" >& 2
block_test "$target/$x_name" "$new_short"

# test update with long line
echo "3. overwrite file with long string" >& 2
block_test "$target/$x_name" "$new_long"

# truncate it to zero length
echo "4. truncate file to length zero" >& 2
trunc_test "$target/$x_name"

# test character-at-a-time read/write
echo "5. test read/write offset handling" >& 2
char_test "$target/$x_name" "$new_short"

# test random-access-writes
echo "6. test random access writes" >& 2
random_test "$target/$x_name"

# unmount the file system, remove the target
echo -n "7. unmounting $target ... "
fusermount -u $target
if [ $? -ne 0 ]
then
    echo "ERROR: $?" >& 2
    let "errors++"
else
    echo "OK" >& 2
    rmdir $target
fi
let "total++"

# see if we passed
if [ $errors -eq 0 ]
then
    echo "$total/$total $fuse tests passed" >& 2
    exit 0
else
    echo "$fuse test failed $errors/$total tests" >& 2
    exit 1
fi
