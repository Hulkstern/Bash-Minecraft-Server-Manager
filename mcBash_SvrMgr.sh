#!/bin/bash

#Constants
#If you would like to specify more or different valid server start scripts, specify them here.
readonly Starters=("startServer.sh" "StartServer.sh" "ServerStart.sh" "launch.sh" "ServerStartLinux.sh")
#I'm lazy and don't feel like copy/pasting this everytime I need it
readonly lineArt='-+=========================+-'

#Global Variables and Arrays (not constant)
ServersLoc=()
ServersName=()
ServersPort=()
OnlineServers=()
starterFileReturn=""
testFileBoolReturn=""

#Functions... so many functions
function ScanServerFiles {
    local locTmp=( $(find . -maxdepth 1 -type d | sort) )
    local nameTmp=( $(find . -maxdepth 1 -type d | sort) )
    local portTmp=()
    nameTmp[0]="--GoFuckYourself"

    ServersLoc=( ${locTmp[@]} )
    ServersName=( $(ListArray "${nameTmp[@]}" | cut -c3-)  )
    ServersPort=( ${portTmp[@]} )
}
function FindServerPorts { #(Not Yet Implemented)
    #This functionality has not yet been added, eventually this will read the server.properties file of each server detected and store it in the "ServersPort" array
    echo ""
}
function CheckOnlineServers { #Checks to see whether the screen session for each detected server exists
    #Because bash is terrible and has no clean way to return data from a function (that I could get working) some functions like this one simply write to a global variable/arry which is immediately checked after calling this function. Also just for it to run cleanly, the global array is cleared before running and of the function code.
    OnlineServers=()
    #This takes all the output of the command "screen -list" and throws it into a variable. This makes it so the command does not have to be run multiple times a second while checking for online servers.
    local screenListOutput=""
    screenListOutput="$(screen -list)"
    #echo "$screenlistOutput" #This is for debug, uncomment if you are not seeing any servers being displayed as running when servers are running (within screen sessions). It prints the raw output of "screen -list"
    #The logic for this loop is that it iterates through all the possible server names detected before and checks if the output of "screen -list" contains the name of that server, if it does the server is considered online.
    for i in "${!ServersName[@]}"; do
        if [[ "$screenListOutput" == *"${ServersName[i]}"* ]]; then
            #For any server that is considered online, append the index of that server to the array "OnlineServers"
            OnlineServers+=("$i")
        fi
        #ListArray "${OnlineServers[@]}" #This is for debug, uncomment if you are not seeing any servers being displayed when servers are running (within screen sessions). It prints the raw output of "screen -list"
    done
}
function SendServerCommand { #Send a string of input to a specified server
    #This is how commands are sent to the server, though it can be used to send any string to the server console. Any string passed to this function is sent to the specified server's screen session with a return character.
    screen -S "$1" -X stuff "$2^M"

    #How to use:
    #ServerCommand "{ScreenName}" "{Command}"
}
function ListArray { #This is a debug tool, can be used to print all values of an array without having to use a loop
    local tmp=("$@")
    printf '%s\n' "${tmp[@]}"
}
function TestFile { #This function test to see if a specified file exists, then "returns" a 1(true) or 0(false) for if it does or does not exist. This function is also victime to bash's seeming inability to cleanly return values in a function. So instead it writes to a global variable instead.
    testFileBoolReturn=""
    if test -f "$1"; then
        #echo "$1 exists." #This is for debug, uncomment if you are experiencing issues with the starter/launch file for a server(s) being detected
        testFileBoolReturn="1"
    else
        #echo "$1 does not exist" #This is for debug, uncomment if you are experiencing issues with the starter/launch file for a server(s) being detected 
        testFileBoolReturn="0"
    fi
}
function FindStarter {
    local i=""
    testFileBoolReturn="0"
    for i in "${!Starters[@]}"; do
        TestFile "${ServersLoc[$1]}/${Starters[$i]}"
        if [ $testFileBoolReturn == 1 ]; then
            starterFileReturn=${Starters[$i]}
        fi
    done
}
function StartServers {
    local tmp=($1)
    local i=""
    for i in "${!tmp[@]}"; do
        local starter=""
        FindStarter "${tmp[i]}"
        starter="$starterFileReturn"
        cd "${ServersLoc[${tmp[i]}]}" || exit
        screen -d -m -S "${ServersName[${tmp[i]}]}" "./$starter"
        cd .. || exit
    done
}
function StopServers {
    local tmp=($1)
    local i=""
    for i in "${!tmp[@]}"; do
        local tempName="${ServersName[${tmp[i]}]}"
        SendServerCommand "$tempName" "save-all"
        #echo "$tempName"
        echo "Saving Server Files..."
        sleep 5
        echo "Stopping $tempName"
        SendServerCommand "$tempName" "stop"
    done
}
function MainMenu {
    while true; do
        echo "Welcome to MCBash Server Manager"
        echo "1 - Start Server(s): Choose from a list of detected servers to start"
        echo "2 - Stop Server(s):  Stop Already Running servers"
        read -p "Please make your selection: " pl
        case $pl in
            [1]* ) StartServerMenu; break;;
            [2]*  ) StopServerMenu; break;;
            * ) echo "Please answer Start or Stop.";;
        esac
    done
}
function StartServerMenu {
    local UserSelections=""
    local loopState=true
    while [ "$loopState" == true ]; do
        echo ""
        echo "Which servers would you like to start? [separate choices with a space]"
        echo "$lineArt"
        for i in "${!ServersName[@]}"; do
            if [ "$i" -gt 0 ]; then
        	    echo "${i} ${ServersName[i]}";
                echo "On port: ${ServersPort[i]}"
                echo "$lineArt"
            fi
	    done
        read -r -p "Enter Selections: " UserSelections
        #ValidateUserInput "$UserSelections"
        loopState=false
    done
    StartServers "$UserSelections"
}
function StopServerMenu {
    CheckOnlineServers
    local UserSelections=""
    local loopState=true
    while [ "$loopState" == true ]; do
        echo ""
        echo "Which servers would you like to stop? [separate choices with a space]"
        echo "$lineArt"
        for i in "${!OnlineServers[@]}"; do
            local tmp="${OnlineServers[i]}"
        	echo "$tmp ${ServersName[$tmp]}"
            echo "On port: ${ServersPort[$tmp]}"
            echo "$lineArt"
        done
        read -r -p "Enter Selections: " UserSelections
        #ValidateUserInput "$UserSelections"
        loopState=false
    done
    StopServers "$UserSelections"
}
function ValidateUserInput {
    #Currently this function is not completed nor implemented, you can find where it would be called in the (Stop/Start)ServerMenu functions where it is commented out.
    local tmp="$(echo "$1" | sed 's/ //g' | tr -d '0-9')"
    if [ $tmp != "" ]; then
        echo ""
    fi
    #Validation comes in two steps. First it is checked to make sure that the string contains only numbers and spaces. If that passes, a second check is performed to make sure that all selections are in range. As in, no selection is of greater value than the the highest index number server. If both checks pass then the function returns true, if either check fails, then the function returns false.
}

ScanServerFiles
MainMenu

#cd "${ServersLoc[2]}" || exit #This works!
#TestFile "${ServersLoc[3]}/server.pproperties"


#echo ""
#echo "Program ran fine (I think), at least no errors were thrown (I think)"