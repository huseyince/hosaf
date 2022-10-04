#!/bin/sh

USER_AGENT="User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/99.0.4844.74 Safari/537.36"

TARGET=${1:-Some}
echo "[!] TARGET: $TARGET"
ADDITIONAL_HEADER="X-Hacker: ${2:-hello}"
echo "[!] ADDITIONAL HEADER: $ADDITIONAL_HEADER"
THREAD=${3:-10}
echo "[!] THREAD: $THREAD"

FAST_WEB_PORTS="80,81,443,3128,5000,8080,8081,8443,8834,9000,9001,9090"
ADDITIONAL_WEB_PORTS="66,300,445,457,591,593,832,981,1010,1080,1099,1100,1241,1311,1352,1433,1434,1521,1944,2082,2095,2096,2301,2480,3000,3306,3333,4000,4001,4002,4100,4243,4567,4711,4712,4993,5104,5108,5280,5281,5432,5601,5800,5801,5802,6346,6347,6543,7000,7001,7002,7396,7474,8000,8001,8008,8014,8042,8060,8069,8083,8088,8090,8091,8095,8118,8123,8172,8181,8222,8243,8280,8281,8333,8337,8500,8880,8888,8983,9043,9060,9080,9091,9200,9443,9502,9800,9981,10000,10250,11371,12443,15672,16080,17778,18091,18092,20720,30821,32000,55440,55672"

generate_host_urls_fast () {
    echo "[!] Nmap generate IPs"
    nmap -sL -n -iL hosts | awk '/Nmap scan report/{print $NF}' > hosts_list

    echo "[!] Httpx started for Host"
    cat hosts_list | httpx -silent -p $FAST_WEB_PORTS -o urls_fast
}

generate_host_urls_additional () {
    echo "[!] Httpx started for Host"
    cat hosts_list | httpx -silent -p $ADDITIONAL_WEB_PORTS -o urls_additional
}

generate_domain_urls_fast () {
    echo "[!] Subfinder and httpx started for domains"
    subfinder -silent -dL domains -all -o subdomains
    cat domains subdomains | sort -u | httpx -silent -p $FAST_WEB_PORTS -o urls_fast
}

generate_domain_urls_additional () {
    echo "[!] Httpx started for domains"
    cat domains subdomains | sort -u | httpx -silent -p $ADDITIONAL_WEB_PORTS -o urls_additional
}

run_gowitness_fast () {
    gowitness file -f urls_fast
}

run_gowitness_additional () {
    gowitness file -f urls_additional
}

fast_scan () {
    echo "[!] Fast Fuzzing started"
    ffuf -s -t $THREAD -c -H "$ADDITIONAL_HEADER" -H "$USER_AGENT" -u URL/WORD -w urls_fast:URL -w ~/tools/hosaf/wordlists/raft-quick.txt:WORD -o ffuf_raft_quick
    ffuf -s -t $THREAD -c -H "$ADDITIONAL_HEADER" -H "$USER_AGENT" -u URL/WORD -w urls_fast:URL -w ~/tools/SecLists/Fuzzing/fuzz-Bo0oM.txt:WORD -o ffuf_fuzboom_fast
    ffuf -s -t $THREAD -c -H "$ADDITIONAL_HEADER" -H "$USER_AGENT" -u URL/WORD -w urls_fast:URL -w ~/tools/SecLists/Discovery/Web-Content/common.txt:WORD -o ffuf_common_fast

    jq -r '.results | sort_by(.url) | .[] | select(.status==200) | "\(.length),\(.url)"' ffuf_raft_quick ffuf_fuzboom_fast ffuf_common_fast | column -t -s, > f200fast
    jq -r '.results | sort_by(.url) | .[] | select(.status==403) | "\(.length),\(.url)"' ffuf_raft_quick ffuf_fuzboom_fast ffuf_common_fast | column -t -s, > f403fast

    echo "[!] Fast Nuclei started"
    nuclei -m -l urls_fast -es info -rate-limit $THREAD -H "$ADDITIONAL_HEADER" -H "$USER_AGENT" -o nuclei_out_fast
    echo "Finished $TARGET Fast Scan" | notify -silent
}

additional_scan () {
    echo "[!] Additional Fuzzing started"
    ffuf -s -t $THREAD -c -H "$ADDITIONAL_HEADER" -H "$USER_AGENT" -u URL/WORD -w urls_additional:URL -w ~/tools/hosaf/wordlists/raft-quick.txt:WORD -o ffuf_raft_quick_additional
    ffuf -s -t $THREAD -c -H "$ADDITIONAL_HEADER" -H "$USER_AGENT" -u URL/WORD -w urls_additional:URL -w ~/tools/SecLists/Fuzzing/fuzz-Bo0oM.txt:WORD -o ffuf_fuzboom_additional
    ffuf -s -t $THREAD -c -H "$ADDITIONAL_HEADER" -H "$USER_AGENT" -u URL/WORD -w urls_additional:URL -w ~/tools/SecLists/Discovery/Web-Content/common.txt:WORD -o ffuf_common_additional

    jq -r '.results | sort_by(.url) | .[] | select(.status==200) | "\(.length),\(.url)"' ffuf_raft_quick_additional ffuf_fuzboom_additional ffuf_common_additional | column -t -s, > f200additional
    jq -r '.results | sort_by(.url) | .[] | select(.status==403) | "\(.length),\(.url)"' ffuf_raft_quick_additional ffuf_fuzboom_additional ffuf_common_additional | column -t -s, > f403additional

    echo "[!] Additional Nuclei started"
    nuclei -m -l urls_additional -es info -rate-limit $THREAD -H "$ADDITIONAL_HEADER" -H "$USER_AGENT" -o nuclei_out_additional
    echo "Finished $TARGET Additional Scan" | notify -silent
}

if [ -f "hosts" ]; then
    generate_host_urls_fast
fi

if [ -f "domains" ]; then
    generate_domain_urls_fast
fi

if [ -f "urls_fast" ]; then
    fast_scan
    run_gowitness_fast
fi

if [ -f "hosts" ]; then
    generate_host_urls_additional
fi

if [ -f "domains" ]; then
    generate_domain_urls_additional
fi

if [ -f "urls_additional" ]; then
    additional_scan
    run_gowitness_additional
fi
