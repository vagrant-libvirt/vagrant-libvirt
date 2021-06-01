BEGIN {
    print "["
    previous=""
}
match($0, /@test "(.*)" \{/, arr) {
    if ( previous != "" ) {
	print previous","
    }
    previous = sprintf("  \"%s\"", arr[1])
}
END {
    print previous
    print "]"
}
