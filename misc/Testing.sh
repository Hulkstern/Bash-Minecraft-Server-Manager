#!/bin/bash
readonly Starters=("startServer.sh" "StartServer.sh" "ServerStart.sh" "launch.sh" "ServerStartLinux.sh")
function ListArray {
    local tmp=("$@")
    printf '%s\n' "${tmp[@]}"
}
#ListArray "${Starters[@]}"

function F2
{
    local  retval='Using BASH Function'
    echo "$retval"
}

#getval=$(F2)  
#echo $getval

#printf "How the actual F*** did you manage to start a server with a negative\nindex??? Either you royally f****d up or you managed to find one\nhell of an edge case I hadn't accounted for.\n"

FullName=("firstName" "middleName" "lastName")
echo "Hello ${FullName[2]}!"
