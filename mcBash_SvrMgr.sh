#!/bin/bash

#Importing external scripts
source slog.sh

#Constants
readonly Starters=("startServer.sh" "StartServer.sh" "ServerStart.sh" "launch.sh" "ServerStartLinux.sh") #If you would like to specify more or different valid server start scripts, specify them here.
readonly serverDir=""
readonly startingDir=$PWD #This stores the working directory that the script starts from for future reference
readonly LOG_LEVEL_STDOUT=DEBUG
readonly LOG_LEVEL_LOG=DEBUG
readonly lineArt='-+=========================+-' #I'm lazy and don't feel like copy/pasting this everytime I need it, if you want to change the style of the seperators used when listing servers, do that here

#Global Variables and Arrays (not constant)
ServersLoc=()
ServersName=()
ServersPort=()
OnlineServers=()
starterFileReturn=""
testFileBoolReturn=""

#Functions... so many functions
function ScanServerFiles { #Scans the working directory of the script for relevant server files and info
    #currently this function just treats any directory as a valid server, and then stores the directory location and name in the appropriate arrays
    local scanResult=( $(find . -maxdepth 1 -type d | sort) )
    local portTmp=()
    nameTmp[0]="--JunkEntry"

    ServersLoc=( ${scanResult[@]} )
    ServersName=( $(ListArray "${scanResult[@]}" | cut -c3-)  )
    ServersPort=( ${portTmp[@]} )

    #This is for debug, to see what is being detected
    log_debug "Directories found: $(ListArray "${ServersLoc[@]}")"
    log_debug "Names Generated: $(ListArray "${ServersName[@]}")"
    log_debug "Ports detected: $(ListArray "${ServersPort[@]}")"
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
    log_debug "Detected Servers: $(ListArray "${OnlineServers[@]}")"
}
function SendServerCommand { #Send a string of input to a specified server
    #This is how commands are sent to the server, though it can be used to send any string to the server console. Any string passed to this function is sent to the specified server's screen session with a return character.
    screen -S "$1" -X stuff "$2^M" && log_success "$2 command sent to $1 server" || log_error "$2 command did not get sent to $1 server"

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
        log_debug "$1 did exist"
    else
        #echo "$1 does not exist" #This is for debug, uncomment if you are experiencing issues with the starter/launch file for a server(s) being detected 
        testFileBoolReturn="0"
        log_debug "$1 didnt exist"
    fi
}
function FindStarter { #This function determines which of the accepted starterfiles a server uses
    local i=""
    testFileBoolReturn="0"
    for i in "${!Starters[@]}"; do
        TestFile "${ServersLoc[$1]}/${Starters[$i]}"
        if [ $testFileBoolReturn == 1 ]; then
            starterFileReturn=${Starters[$i]}
        fi
    done
}
function StartServers { #This function starts all the selected servers passed to it
    #This function takes a string of numbers seperated by spaces and turns it into an array. Those numbers are the index numbers of detected servers. It iterates through the array and starts the matching server for each entry.
    local tmp=($1)
    local i=""
    for i in "${!tmp[@]}"; do
        local starter=""
        FindStarter "${tmp[i]}"
        starter="$starterFileReturn"
        cd "${ServersLoc[${tmp[i]}]}" || log_error "cd into '${ServersLoc[${tmp[i]}]}' failed" && exit #It is required to cd into a server's directory before starting so that the launch file of the server starts the server from the correct working directory
        screen -d -m -S "${ServersName[${tmp[i]}]}" "./$starter" && log_success "${ServersName[${tmp[i]}]} server's screen session started successfully" || log_error "${ServersName[${tmp[i]}]} server's screen session did not start" #This starts a new detached screen session, names it with the server name, and that it should execute the specified bash script
        cd .. || log_error "cd '..' failed" && exit
        #Before finsihing the loop the script returns to the scripts original working directory so that it is ready to start the launch next server
    done
}
function StopServers { #This function attempts to stop all the selected servers passed to it
    #This Stop servers function wors similarly to the start servers
    local tmp=($1)
    local i=""
    for i in "${!tmp[@]}"; do
        local tempName="${ServersName[${tmp[i]}]}" #The specified server's name is stored here temporarily as to make it easier to give as function arguments.
        SendServerCommand "$tempName" "save-all" #This should force the specified mc server to perform a world save
        #echo "$tempName" #This is for debug, uncomment if you are having issues with screen reporting that no matching screen session was found
        echo "Saving Server Files..."
        sleep 5 #This delay is to allow some time for the server to finish saving, in theory this isn't needed but it's better to be safe
        echo "Stopping $tempName"
        SendServerCommand "$tempName" "stop" #This should trigger the specified mc server to shut down
    done
}
function MainMenu { #Displays the main menu and processes user selections
    while true; do
        echo "Welcome to MCBash Server Manager"
        echo "1 - Start Server(s): Choose from a list of detected servers to start"
        echo "2 - Stop Server(s):  Stop Already Running servers"
        read -r -p "Please make your selection: " pl && log_debug "Selection: $pl"
        case $pl in
            [1]* ) StartServerMenu; break;;
            [2]*  ) StopServerMenu; break;;
            * ) echo "Please answer Start or Stop.";;
        esac
    done
}
function StartServerMenu { #Displays all detected servers with the option to start any number of them
    #The logic for this goes, for all the elements within the array ServerssName display the index, name, and port then collect user input. The last step is to call the StartServers function and pass along the User's Selections
    local UserSelections=""
    local loopState=true
    while [ "$loopState" == true ]; do
        echo ""
        echo "Which servers would you like to start? [separate choices with a space]"
        echo "$lineArt"
        for i in "${!ServersName[@]}"; do
            #This if statement exists becuase the values at index 0 for all the server information arrays is a junk entry. This will make sure that the "server" at index 0 is not listed
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
    log_debug "User Selections: $UserSelections"
    StartServers "$UserSelections"
}
function StopServerMenu { #Displays all servers that have an active screen session with the option to stop any number of them
    #This function works similarly to the StartServerMenu function. However, instead of listing all detected servers only the ones that have an active screen session are listed, and the User's Selections are passed to the StopServers function
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
    log_debug "User Selections: $UserSelections"
    StopServers "$UserSelections"
}
function ValidateUserInput { #Verifies that all the selections made by the user are valid servers.
    #Currently this function is not completed nor implemented, you can find where it would be called in the (Stop/Start)ServerMenu functions where it is commented out.
    local tmp="$(echo "$1" | sed 's/ //g' | tr -d '0-9')"
    if [ $tmp != "" ]; then
        echo ""
    fi
    #Validation comes in two steps. First it is checked to make sure that the string contains only numbers and spaces. If that passes, a second check is performed to make sure that all selections are in range. As in, no selection is of greater value than the the highest index number server. If both checks pass then the function returns true, if either check fails, then the function returns false.
}
function LogToFile { #Will set all logs to log to file if run
    #This takes two arguments, the first being the folder where you would like to store logs, the second being how you would like logs to named. If you choose a static name then logs will just append to the same file every time the script is run
    local dirScan=""
    dirScan="$(find . -not -path '*/\.*' -type d -name "$1" | cut -c3-)"
    if [ "$dirScan" != "$1" ]; then
        log_warning "'./$1' directory doesn't exist, creating..."
        #echo "logs directory doesn't exist, creating..."
        mkdir ./"$1"
    fi
    LOG_PATH="./$1/$2"
    log "Logging to file at ./$1/$2"
}
function WSL-compat { #Due to some funkiness with how WSL inits, this function makes sure that the directories needed for screen to function exist and that they are created if not
    if [ ! -d "/run/screen" ]; then
        log_warning "'/run/screen' Does not exist, attempting to create"
        echo "Screen requires the '/run/screen' directory to exist in order to work properly,"
        echo "Please enter your root password to allow the creation of that directory"
        sudo mkdir /run/screen || log_error "Failed to create '/run/screen' directory, exiting..." && exit
        sudo chmod 777 /run/screen || log_error "Failed to set permssions of '/run/screen' directory, exiting..." && exit
        log_
    else
        log_debug "/run/screen exists, did not attempt to create or set permissions for '/run/screen'"
    fi
}

WSL-compat
LogToFile "logs" "$(date +"%Y-%m-%d_%T").log" #This is to enable logging to a file, uncomment if you would like log output to be written to a log file within the logs folder.
echo ""
ScanServerFiles
MainMenu


#cd "${ServersLoc[2]}" || exit #This works!
#TestFile "${ServersLoc[3]}/server.pproperties"


#echo ""
#echo "Program ran fine (I think), at least no errors were thrown (I think)"