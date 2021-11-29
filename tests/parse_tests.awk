BEGIN {
    printf "["
    previous=""
}
match($0, /@test "(.*)" \{/, arr) {
    if ( previous != "" ) {
	printf "%s, ",previous
    }
    previous = sprintf("\"%s\"", arr[1])
}
END {
    printf "%s",previous
    print "]"
}
