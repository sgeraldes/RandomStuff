#!/bin/bash
## switchproxy.sh: Switch Proxy v1.2.
## Copyright 2016 Sebastian Geraldes. All rights reserved.

#+ =======================================================
#+ 
#+ Variables here, change the following to your liking: 
#+ 

http_proxy='http://proxy.corp.globant.com'
http_proxy_port=3128

## The following vpn connection must exist
MyVPN="s.geraldes@sslvpn.globant.com"

## Exclude list from proxy (bypass proxy list)
ignore_hosts="\
['localhost', '127.0.0.0/8', '::1', 'globant.com', \
'github.com', 'versionone.humana.com', 'psynch.humana.com', \
'ppqa.globant.com', 'gopods-ng.corp.globant.com', \
'133.27.10.156']\
"

## uses the same proxy for all protocols, change if your's different
#+
#https_proxy='192.168.1.1'
#https_proxy_port=1080
#+
#ftp_proxy='192.168.1.1'
#ftp_proxy_port=1080
#+
## Socks Proxy is not used in Globant, breaks Slack among others if used.
#+ Remove comment if you need it
#socks_proxy='192.168.1.1'
#socks_proxy_port=8080
#+
https_proxy=$http_proxy
https_proxy_port=$http_proxy_port
#
ftp_proxy=https_proxy
ftp_proxy_port=https_proxy_port


#region
## **********************************************
#+ Here be dragons: Do not modify past this line!
#+ ----------------------------------------------
#enregion

## Output color variables here
bold=$(tput bold)
normal=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
down="${red}${bold}down${normal}"
up="${green}${bold}up${normal}"
## Following variables kept for reference, but commented out
#white=$(tput setaf 7) ##not used
#blue=$(tput setaf 4) ##not used
#+
#+ End of Output Color variables

## Replaces specials characters ('[]) from ignored host (for bash export usage)
no_proxy=${ignore_hosts//\'/}
no_proxy=${no_proxy//\[/}
no_proxy=${no_proxy//\]/}
#+

## obtain proxy mode and host
MODE="$(gsettings get org.gnome.system.proxy mode)"
cMODE=${bold}${MODE}${normal} ## colored proxy mode for looks
GETPROXY="$(gsettings get org.gnome.system.proxy.http host)"
#+ 

## obtain filename from bash if sourced (cannot obtain with $0 if sourced)
filename=${BASH_SOURCE[0]##*/}

##
#+ Long text and disclaimers go here
sourced="\
${filename}: script is not sourced!

Don't run '$0', source it instead with:
    [source ./switchproxy.sh] or [. ./switchproxy.sh]

or add an alias to your .bashrc like this:
    alias proxy='. ~/switchproxy.sh'

and use [proxy] to call it.

Bye.-"

usage="\
${filename}: invalid option '${bold}$1${normal}'

Usage:
    ${filename} {manual|none|switch}

or run '${filename}' with no argument to diplay a menu of options"

version="${bold}Switch Proxy v1.2${normal} - Copyright Sebastian Geraldes"

# Functions
disclaimer() {
    echo "${version}"
}

testSourced()
{
## Function: Check if called directly or sourced
#+ Script must be sourced in order to export variables to the current console
    if [[ "$(basename -- "$0")" == "switchproxy.sh" ]]; then
        echo "${sourced}" >&2
        exit 1
    fi
}

manual()
{
## Function: setup proxy in manual mode
    echo -n "proxy currently set to ${cMODE} => "
    echo "Switching to ${bold}'manual'${normal}"

    ## EXPORT ENV VARIABLES
    export HTTP_PROXY="$http_proxy:$http_proxy_port/"
    export HTTPS_PROXY="$https_proxy:$https_proxy_port/"
    export FTP_PROXY="$ftp_proxy:$ftp_proxy_port//"
    export NO_PROXY="$no_proxy"
    #+

    ## Set system wide settings in NetworkManager with gsettings
    gsettings set org.gnome.system.proxy use-same-proxy false

    gsettings set org.gnome.system.proxy.http host $http_proxy
    gsettings set org.gnome.system.proxy.http port $http_proxy_port

    gsettings set org.gnome.system.proxy.https host $https_proxy
    gsettings set org.gnome.system.proxy.https port $https_proxy_port

    gsettings set org.gnome.system.proxy.socks host ''
    gsettings set org.gnome.system.proxy.socks port 0

    gsettings set org.gnome.system.proxy ignore-hosts "$ignore_hosts"

    gsettings set org.gnome.system.proxy mode 'manual'
    #+

    return 0
}

noproxy() {
# Clear proxy settings and set mode to 'none'
    echo -n "proxy currently set to ${cMODE} => "
    echo "Switching to ${bold}'none'${normal}"
    gsettings set org.gnome.system.proxy mode 'none'
    unset HTTP_PROXY
    unset HTTPS_PROXY
    unset FTP_proxy
    unset SOCKS_proxy
    return 0
}

testWebConnectivity() {
## Some firewalls block pings.
#+ Some places have a firewall that blocks all traffic except via web proxy. 
#+ If you want to test web connectivity, you can make an HTTP request.
    case "$(curl -s --max-time 2 -I http://google.com | \
                sed 's/^[^ ]*  *\([0-9]\).*/\1/; 1q')" in

        [23]) echo "HTTP connectivity is ${up}";;

        5) echo "The web ${bold}proxy${normal} won't let us through";;

        *) echo "The web is ${down} or very ${bold}slow${normal}";;
    esac
}

testIPandDNSOnly() {
## If you only want the test to succeed when DNS is also working, use a host name.

    if ping -q -c 1 -W 1 google.com >/dev/null; then
        echo "${bold}DNS${normal} is ${up}"
    else
        echo "${bold}DNS${normal} is ${down}"
    fi
}

testIPv4() {
## If your network lets ping through, try pinging 8.8.8.8 (Google DNS server).
    if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
        echo "${bold}IPv4${normal} is ${up}"
    else
        echo "${bold}IPv4${normal} is ${down}"
    fi
}

testProxyReachable() {
## If you only want the test to succeed when DNS is also working, use a host name.
    if ping -q -c 1 -W 1 proxy.corp.globant.com >/dev/null; then
        echo -n "${bold}Proxy${normal} is ${up} and reachable "
        case ${MODE//\'/} in
            none)
                echo "but it is ${bold}not${normal} setup in the system"
                ;;
            manual)
                echo -n "${bold}Proxy${normal} is ${up} and configured "
                echo "with ${GETPROXY} set for HTTP"
                ;;
            *)
                echo -n "${bold}Proxy${normal} is ${up} "
                echo "with ${MODE} and ${GETPROXY}"
        esac
    else
        echo "Proxy is ${down}"
    fi
}

testHumanaVPN () {
	## Test if network can access Humana IPs (VersionOne.humana.com)
    #+ Alternatively we can use:
    # wget -q --spider --tries=10 --timeout=20 http://133.27.10.156
    #+ but requires wget installed and may not be true in every case

    # Tries to reach the VersionOne server by IP first
    if ping -q -c 1 -W 1 133.27.10.156 >/dev/null; then
        # If successfull, Tries to reach the VersionOne server by URL
        if ping -q -c 1 -W 1 versionone.humana.com >/dev/null; then
            echo -n "${bold}Humana${normal} network is ${up} "
            echo "and hosts are set properly"
        else
            # not succeded, therefore hosts (DNS) are not configured
            echo -n "${bold}Humana${normal} network is ${up} "
            echo "but ${bold}hosts${normal} are ${red}not configured${normal}"
        fi
    else
        echo "Not inside Humana's network or VersionOne.Humana.com is ${down}"
    fi
}

testGlobantConnectivity() {
    ## Some firewalls block pings. 
    #+ Some places have a firewall that blocks all traffic except via a web proxy. 
    #+ If you want to test web connectivity, you can make an HTTP request.
    case "$(curl -s --max-time 3 -I http://glow.corp.globant.com | \
            sed 's/^[^ ]*  *\([0-9]\).*/\1/; 1q')" in
        [23])
            echo "${bold}Globant${normal} Intranet connectivity is ${up}";;
        *)
            echo "${bold}Globant${normal} network ${down} or very slow"
            echo -n "Do you want to start the vpn? [Yes/No]"
            read -n 1 vpnStart
            if [ "${vpnStart}" = "y" ]; then
                echo
                echo "Starting VPN "
                nmcli con up ${MyVPN}
            fi
            ;;
    esac
    testProxyReachable
}

vpnConnection() {
    while true; do
        connection="MyNetworkConnection"
        #vpn_connection="myvpn"
        run_interval="10"

        active_connection=$(nmcli con | grep "${connection}")
        active_vpn=$(nmcli con show --active | grep "vpn")

        if [ "${active_connection}" -a ! "${active_vpn}" ]; then
            echo ## killall firefox
        fi

        sleep $run_interval
    done
}

testInterfaces()
{
    resultEthernet=$(nmcli dev | grep "ethernet" | grep -w "connected")
    resultWifi=$(nmcli dev | grep "wifi" | grep -w "connected")

    if [ -z "$resultEthernet" ] && [ -z "$resultWifi" ]; then
        echo "Ethernet is disconnected and Wifi radio is 'off'."
        echo "Turning Wifi ON Automatically"
        nmcli radio wifi on
        echo "radio is now ${up}"
        echo
    elif [ -n "$resultEthernet" ] && [ -n "$resultWifi" ]; then
        #Ethernet connected and wifi connected
        echo -n "Ethernet is connected and Wifi radio is 'on'."
        echo -n " Do you want to turn wifi off? [recommended] (YES/no) :"
        read -n 1 wifi
        if [ "$wifi" == "y" ] || [ "$wifi" == "" ]; then
            nmcli radio wifi off
        fi
    else
        nmcli con show --active
    fi
}

testNetwork() {
    #setion: tests
    echo "Checking connectivity..."
    testInterfaces
    testIPv4
    testIPandDNSOnly
    testWebConnectivity
    testGlobantConnectivity
    testHumanaVPN
}

## Proxy me up!

testSourced

## Test whether command-line argument is present (non-empty).
if [ $# -eq 0 ]; then
  ## Default, if nothing is specified on command-line, display the menu.
    disclaimer
    testNetwork
    echo "Select Proxy mode:"
    echo "------------------"
    OPTIONS="Manual None Quit"
    select opt in $OPTIONS; do
        if [[ "$opt" = "Quit" ]]; then
            echo "Bye.-"
            return 0
        elif [[ "$opt" = "None" ]]; then
            noproxy
            return 0
        elif [[ "$opt" = "Manual" ]]; then
            manual
            return 0
        else
            echo "Wrong option, try again"
        fi
    done
else ## evaluates what argument was passed as parameter
    case "$1" in
        globant|manual|proxy|on) disclaimer; manual;;
        noproxy|none|off) noproxy;;
        test|tests|check) testNetwork;;
        auto)
            ##TODO: function not implemented
            echo "[TODO]: function not implemented"
            Return 1;;
        switch)
            ## switch to next mode (from manual or no proxy )
            mode=${MODE}
            case $mode in
                \'none\') manual;;
                *) noproxy;;
            esac
            ;;
        *) echo "${usage}" >&2
            return 1
    esac
fi
#enregion
