#!/bin/bash

set -o pipefail

env=${1:-prod}
shift

profiles='https://cube.link/ref/main/shape/profile-visualize'
mkdir -p metadata
mkdir -p html_reports
rm -f metadata/${env}.*.txt metadata/${env}.*.ttl metadata/${env}.*.ttl*.log
rm -f html_reports/${env}.*.metadata.html

echo "+++ env: ${env} +++ profiles: ${profiles} +++"

_checkmetadata() {
    barnard59="barnard59"
    cube=${1}
    shift
    env=${1:-prod}.
    datasource=`echo ${env} | sed -re "s~^([a-z]+)(\.?)~\u\1~"`
    endpoint=https://${env//prod./}ld.admin.ch/query
    shift
    profiles=${*:-https://cube.link/ref/main/shape/profile-visualize}
    [[ ${CI} == true ]] && echo === endpoint: ${endpoint} === profiles: ${profiles} === cube: ${cube} ===
    cubename_base="${env}${cube//[^A-Za-z0-9 ]/_}"
    metadata=metadata/${cubename_base}.ttl
    txtreport=metadata/${cubename_base}.txt
    htmlreport=html_reports/${cubename_base}.metadata.html
    unset cmd
    for profile in $profiles ; do
        cmd="${cmd}npx barnard59 cube fetch-metadata --endpoint ${endpoint} --cube ${cube} | npx barnard59 cube check-metadata --profile ${profile} | npx barnard59 shacl report-summary<br />"
    done

    until `[ -s ${metadata} ]` ; do ${barnard59} cube fetch-metadata --endpoint ${endpoint} --cube ${cube} 2> ${metadata}.fetch.log > ${metadata} || sleep `shuf -i 5-20 -n 1` ; done
    for profile in $profiles ; do
        cat ${metadata} | ${barnard59} cube check-metadata --profile ${profile} 2> ${metadata}.check.log | ${barnard59} shacl report-summary 2> ${metadata}.report.log >> ${txtreport}
        tail -1 ${txtreport} | grep success > /dev/null && grep Error ${metadata}.*.log > /dev/null && ( echo "VALIDATION_FAILED" ; cat ${metadata}.*.log ) > ${txtreport} # double check for Errors
    done
    status=`cat ${metadata} | grep -oP "<http://schema.org/creativeWorkStatus> <https://ld.admin.ch/vocabulary/CreativeWorkStatus/\K[A-Za-z]+"` || status=Error
    modified=`cat ${metadata} | grep -oP "<http://schema.org/dateModified> \"\K[0-9:\.\-\+TZ]+"` || modified=undefined
    visualize="<a href=\"https://${env//prod./}visualize.admin.ch/create/new?cube=${cube}&dataSource=${datasource}\" target=_blank>visualize</a>"
    validator="<a href=\"https://cube-validator.lindas.admin.ch/validate/$(echo -n ${endpoint} | jq -sRr @uri)/$(echo -n ${cube} | jq -sRr @uri)?tab=cube&profile=$(echo -n https://cube.link/ref/main/shape/profile-visualize | jq -sRr @uri)\" target=_blank>validated</a>"
    echo "<h2 class=${status}><a href=#${cube//[^A-Za-z0-9 ]/_} name=${cube//[^A-Za-z0-9 ]/_} class=a>#</a> ${cube}</h2>" >> ${htmlreport}
    echo "<div class=main><div class='c c1'>endpoint: ${endpoint}<br />" >> ${htmlreport}
    echo "status: ${status}<br />" >> ${htmlreport}
    echo "profiles: " >> ${htmlreport}
    for profile in $profiles ; do
        echo "<a href=${profile} target=_blank>$(basename ${profile} | sed "s+profile-++")</a>" >> ${htmlreport}
    done
    echo "<br />" >> ${htmlreport}
    echo "modified: `echo ${modified} | sed -e "s~\.[0-9]*~~" | sed -e "s~\+00:00~Z~"`<br />" >> ${htmlreport}
    echo "${visualize}<br />" >> ${htmlreport}
    echo "${validator}: `date -u +"%Y-%m-%dT%H:%M:%SZ"`</div>" >> ${htmlreport}
    echo "<div class='c c2'>" >> ${htmlreport}
    if [ `grep success ${txtreport} | wc -l` -eq `echo $profiles | wc -w` ] ; then
        echo "<span class=success>success</span></div><div class=cmax><div class='report silver'>" >> ${htmlreport}
    elif `grep "VALIDATION_FAILED" ${txtreport} > /dev/null` ; then
        echo "<span class=failed>FAILED</span></div><div class=cmax><div class='report failed'>" >> ${htmlreport}
        echo "`cat ${txtreport} | jq -Rr @html | sed 's/$/<br \/>/'`" >> ${htmlreport}
    else
        violation=`grep Violation ${txtreport} | sort | uniq | wc -l`
        [ ${violation} -gt 0 ] && echo "<span class=violation>${violation} violations</span><br />" >> ${htmlreport}
        warning=`grep Warning ${txtreport} | sort | uniq | wc -l`
        [ ${warning} -gt 0 ] && echo "<span class=warning>${warning} warnings</span><br />" >> ${htmlreport}
        info=`grep Info ${txtreport} | sort | uniq | wc -l`
        [ ${info} -gt 0 ] && echo "<span class=info>${info} infos</span>" >> ${htmlreport}
        echo "</div><div class=cmax><div class=report><span class=violation>" >> ${htmlreport}
        grep Violation ${txtreport} | sort | uniq | jq -Rr @html | sed 's/$/<br \/>/' >> ${htmlreport}
        echo "</span><span class=warning>" >> ${htmlreport}
        grep Warning ${txtreport} | sort | uniq | jq -Rr @html | sed 's/$/<br \/>/' >> ${htmlreport}
        echo "</span><span class=info>" >> ${htmlreport}
        grep Info ${txtreport} | sort | uniq | jq -Rr @html | sed 's/$/<br \/>/' >> ${htmlreport}
        echo "</span><br />" >> ${htmlreport}
    fi
    echo "<span class=cmd>${cmd}</span></div></div></div>" >> ${htmlreport}
}
export -f _checkmetadata

[[ ${CI} == true ]] || bar="--bar"
parallel ${bar} _checkmetadata :::: ${env}.cubes.txt ::: ${env} ::: "${profiles}"

echo "<style>body { font-family: sans-serif; background-color: #eee; } .a { text-decoration:none; color:lightgrey; } .main { display: flex; } .c { min-width:max-content; margin: 0 1em 0 0; } .c1 { width: 350px; } .c2 { width: 130px; } .cmax { width: 100%; overflow: hidden; } .report { font-family: monospace; background-color: #1c1c1c; overflow: auto; white-space: nowrap; padding: 0.4em; font-size:0.8em; border: 1px solid #999; border-radius: 0.4em; } .silver { background-color: silver !important; } .failed { background-color: orange !important; } .violation { color: red; } .warning { color: orangered; } .info { color: orange; } .success { color: darkgreen; } .cmd { color: #eee; font-size: 0.6em; } .Published { color: black; } .Draft { color: grey; } .Error { color: red; }</style>" > html_reports/${env}.summary.metadata.html
echo "<script>document.addEventListener('click', e => { if (e.target.matches('.cmd')) { navigator.clipboard.writeText(e.target.textContent).then(() => console.log('copied text'), error => console.error('failed to copy', error)); } });</script>" >> html_reports/${env}.summary.metadata.html
echo "<h1><a href=.>Cube Monitor</a> ${env} metadata</h1>" >> html_reports/${env}.summary.metadata.html
cat html_reports/${env}.http*.metadata.html >> html_reports/${env}.summary.metadata.html
