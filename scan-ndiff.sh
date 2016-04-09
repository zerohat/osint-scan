#!/bin/bash

####
#### (c) tiri GmbH, Gerald Fehringer
####
#
CUSTOMER="${1}"
BASE="/opt/_SCANS/${CUSTOMER}"
BASE_EYE="/opt/_PENTEST/EyeWitness"
BASE_SUB="/opt/_PENTEST/subbrute"
TARGET="${BASE}/hostliste"
MAILTO="tsoc@tiri.li"
INTERVAL="1209600"	#alle 14 Tage
OPTIONS_TCP="-T4 --open -sV -g 53 -sS --top-ports 1000"
OPTIONS_UDP="-T4 -sC -sU --top-ports 10"
EYE_WITNESS="${2}"	# YES
SUB_DNS_BRUTE="${3}"	# YES
EXCLUDE_FILE="${BASE}/excludes"
EYE_URIS="${BASE}/urlliste"
DOMAIN_FILE="${BASE}/domainlist"

if [ "${1}" == "-h" ]; then
   echo
   echo "Usage: "
   echo "$0 {Kundenname} {YES fuer EyeWitness} {YES fuer Subdomain Bruter}"
   echo "Kundenname: das Verzeichnis muss existieren und entsprechende URL-,IP- und Domainliste beinhalten"
   echo
   exit 1
fi

if [ -z "${1}" ]; then
    echo "Customer Name needed (no special character allowed)"
    exit
fi

if [ ! -f "${TARGET}" ]; then
    echo "TARGETS not set (space separated list of servers to scan)"
    exit
fi

if [ -z "${MAILTO}" ]; then
    echo "MAILTO not set (email to send diffs to)"
    exit
fi

# if [ "${INTERVAL:-}" == "" ]; then
if [ -z "${INTERVAL}" ]; then
    echo "INTERVAL not set (second to sleep between runs)"
    exit
fi

if [ -z "${OPTIONS_TCP}" ]; then
    echo "NMAP OPTIONS not set"
    exit
fi

if [ ! -d "${BASE}" ]; then
    echo "CUSTOMER Dir doesnt exist"
    exit
fi

##################################### NO CHANGES BELOW ####################

###
### NMAP TOP Scan
###
cd ${BASE}
LAST_RUN_FILE='.lastrun'

    # If the last run file exists, we should only sleep for the time
    # specified minus the time that's already elapsed.
    if [ -e "${LAST_RUN_FILE}" ]; then
        LAST_RUN_TS=$(date -r ${LAST_RUN_FILE} +%s)
        NOW_TS=$(date +%s)
        LAST_RUN_SECS=$(expr ${NOW_TS} - ${LAST_RUN_TS})
    fi

    START_TIME=$(date +%s)
    echo $(date) '- starting all targets, options: ' ${OPTIONS_TCP}
    echo '=================='

    DATE=`date +%Y-%m-%d_%H-%M-%S`

    CUR_LOG=scan-${CUSTOMER}-${DATE}.xml
    PREV_LOG=scan-${CUSTOMER}-prev.xml
    DIFF_LOG=scan-${CUSTOMER}-diff

    CUR_LOG2=scan-udp-${CUSTOMER}-${DATE}.xml
    PREV_LOG2=scan-udp-${CUSTOMER}-prev.xml
    DIFF_LOG2=scan-udp-${CUSTOMER}-diff

    echo
    echo $(date) "- starting ${CUSTOMER}"
    echo "------------------"

    # Scan the target
    if [ -s "$EXCLUDE_FILE" ]; then
      nmap ${OPTIONS_TCP} -iL ${TARGET} -oA scan-${CUSTOMER}-${DATE} --excludefile ${4}
      nmap ${OPTIONS_UDP} -iL ${TARGET} -oA scan-udp-${CUSTOMER}-${DATE} --excludefile ${4}
    else
      nmap ${OPTIONS_TCP} -iL ${TARGET} -oA scan-${CUSTOMER}-${DATE}
      nmap ${OPTIONS_UDP} -iL ${TARGET} -oA scan-udp-${CUSTOMER}-${DATE}
    fi

    # If there's a previous log, diff it
    if [ -e ${PREV_LOG} ]; then

            # Exclude the Nmap version and current date - the date always changes
            ndiff ${PREV_LOG} ${CUR_LOG} | egrep -v '^(\+|-)Nmap ' > ${DIFF_LOG}

            if [ -s ${DIFF_LOG} ]; then
                # The diff isn't empty, show it on screen for docker logs and email it
                echo 'Emailing diff log:'
                cat ${DIFF_LOG}
                cat ${DIFF_LOG} | mail -s "namp TCP Top 1000 scan diff for ${CUSTOMER}" ${MAILTO}

                # Set the current nmap log file to reflect the last date changed
                ln -sf ${CUR_LOG} ${PREV_LOG}
            else
                # No changes so remove our current log
                rm ${CUR_LOG}
            fi
            rm ${DIFF_LOG}
        else
            # Create the previous scan log
            ln -sf ${CUR_LOG} ${PREV_LOG}
        fi

    if [ -e ${PREV_LOG2} ]; then

            # Exclude the Nmap version and current date - the date always changes
            ndiff ${PREV_LOG2} ${CUR_LOG2} | egrep -v '^(\+|-)Nmap ' > ${DIFF_LOG2}

            if [ -s ${DIFF_LOG2} ]; then
                # The diff isn't empty, show it on screen for docker logs and email it
                echo 'Emailing diff log:'
                cat ${DIFF_LOG2}
                cat ${DIFF_LOG2} | mail -s "namp UDP scan diff for ${CUSTOMER}" ${MAILTO}

                # Set the current nmap log file to reflect the last date changed
                ln -sf ${CUR_LOG2} ${PREV_LOG2}
            else
                # No changes so remove our current log
                rm ${CUR_LOG2}
            fi
            rm ${DIFF_LOG2}
        else
            # Create the previous scan log
            ln -sf ${CUR_LOG2} ${PREV_LOG2}
        fi


    touch ${LAST_RUN_FILE}
    END_TIME=$(date +%s)

    echo
    echo $(date) "- finished all targets in" $(expr ${END_TIME} - ${START_TIME}) "second(s)"

   # rm $BASE/scan-${CUSTOMER}-${DATE}.nmap
   # rm $BASE/scan-${CUSTOMER}-${DATE}.gnmap


##
## WEB SCREENHOTS
##
if [ "${EYE_WITNESS}" == "YES" ]; then
  #erweitere url liste fuer eyewitness
  if [ -f "${BASE}/.tmp-webserver-port80" ]; then
    rm -f ${BASE}/.tmp-webserver-port80
  fi
  egrep "80/open" $(ls -1 ${BASE}/scan-${CUSTOMER}*.gnmap | tail -1) |awk '{print $2,$3}' >>${BASE}/.tmp-webserver-port80
  if [ -s "${BASE}/.tmp-webserver-port80" ]; then
   cat ${BASE}/.tmp-webserver-port80 |cut -d' ' -f1 |sed 's/^/http:\/\//' >${BASE}/urlliste-port80
   cat ${BASE}/.tmp-webserver-port80 |cut -d' ' -f2 |sed -e 's/^(//g' | sed -e 's/)//g' |sed '/^$/d' |sed 's/^/http:\/\//' >>${BASE}/urlliste-port80
  fi

  if [ -f "${BASE}/.tmp-webserver-port8181" ]; then
   rm -f ${BASE}/.tmp-webserver-port8181
  fi

  egrep "8181/open" $(ls -1 ${BASE}/scan-${CUSTOMER}*.gnmap | tail -1) |awk '{print $2,$3}' >>${BASE}/.tmp-webserver-port8181
  if [ -s "${BASE}/.tmp-webserver-port8181" ]; then
   cat ${BASE}/.tmp-webserver-port8181 |cut -d' ' -f1 |sed 's/^/http:\/\//' | sed 's/$/:8181/' >${BASE}/urlliste-port8181
   cat ${BASE}/.tmp-webserver-port8181 |cut -d' ' -f2 |sed -e 's/^(//g' | sed -e 's/)//g' |sed '/^$/d' |sed 's/^/http:\/\//' | sed 's/$/:8181/' >>${BASE}/urlliste-port8181
  fi

  if [ -f "${BASE}/.tmp-webserver-port8080" ]; then
   rm -f ${BASE}/.tmp-webserver-port8080
  fi

  egrep "8080/open" $(ls -1 ${BASE}/scan-${CUSTOMER}*.gnmap | tail -1) |awk '{print $2,$3}' >>${BASE}/.tmp-webserver-port8080
  if [ -s "${BASE}/.tmp-webserver-port8080" ]; then
   cat ${BASE}/.tmp-webserver-port8080 |cut -d' ' -f1 |sed 's/^/http:\/\//' | sed 's/$/:8080/' >${BASE}/urlliste-port8080
   cat ${BASE}/.tmp-webserver-port8080 |cut -d' ' -f2 |sed -e 's/^(//g' | sed -e 's/)//g' |sed '/^$/d' |sed 's/^/http:\/\//' | sed 's/$/:8080/' >>${BASE}/urlliste-port8080
  fi

  if [ -f "${BASE}/.tmp-webserver-port443" ]; then
    rm -f ${BASE}/.tmp-webserver-port443
  fi

  egrep "443/open" $(ls -1 ${BASE}/scan-${CUSTOMER}*.gnmap | tail -1) |awk '{print $2,$3}' >>${BASE}/.tmp-webserver-port443
  if [ -s "${BASE}/.tmp-webserver-port443" ]; then
   cat ${BASE}/.tmp-webserver-port443 |cut -d' ' -f1 |sed 's/^/https:\/\//' >${BASE}/urlliste-port443
   cat ${BASE}/.tmp-webserver-port443 |cut -d' ' -f2 |sed -e 's/^(//g' | sed -e 's/)//g' |sed '/^$/d' |sed 's/^/https:\/\//' >>${BASE}/urlliste-port443
  fi


#start screenshots
if [ -d "${BASE}/EyeWitness" ]; then
 mv ${BASE}/EyeWitness ${BASE}/EyeWitness.prev
fi

if [ -f "${BASE_EYE}/EyeWitness.py" ]; then
cd $BASE
 for tURL in `ls -1 urlliste-*`
  do
   #./EyeWitness.py -f ${EYE_URIS} --threads 8 --headless --prepend-https --no-prompt -d ${BASE}
   mkdir -p ${BASE}/EyeWitness
   cd $BASE_EYE
   ./EyeWitness.py -f  ${BASE}/${tURL} --threads 8 --headless --no-prompt -d ${BASE}/EyeWitness/shoots-${tURL}
 done
fi
#
#
fi


###wordpress scanner
if [ -f "${BASE}/.webserver" ]; then
fi

if [ -s "${BASE}/.tmp-webserver-port80" ]; then
 cd ${BASE}
 cut -d" " -f1 ${BASE}/.tmp-webserver-port80 >.webserver
 cut -d" " -f1 ${BASE}/.tmp-webserver-port443 >>.webserver
 cat ${BASE}/.webserver |sort |uniq > ${BASE}/.webserver
 #if [ -s "$EXCLUDE_FILE" ]; then
 # nmap -p80,443 -sV --script http-wordpress-enum -iL ${BASE}/.webserver -oA scan-webserver-${CUSTOMER}-${DATE} --excludefile ${4}
# else
 # nmap -p80,443 -sV --script http-wordpress-enum -iL ${BASE}/.webserver -oA scan-webserver-${CUSTOMER}-${DATE}
 #fi
#
fi


##
## OSINT ANALYSE
##

### Subdomain Enumeration
if [ "${SUB_DNS_BRUTE}" == "YES" ]; then
 if [ -f "${BASE_SUB}/subbrute.py" ]; then
  cd ${BASE_SUB}
  if [ ! -d "${BASE}/domains" ]; then
     mkdir ${BASE}/domains
  fi
  ./subbrute.py -c 32 -t ${DOMAIN_FILE} -j ${BASE}/domains/sub-domains.json
 fi
fi


###cleanup
find ${BASE}/ -type f -mtime +182 -name 'scan-*' -execdir rm -- {} +

exit 0
