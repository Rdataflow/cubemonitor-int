#!/bin/bash

set -o pipefail

env=${1:-prod}






mkdir -p observations
mkdir -p html_reports
rm -f observations/${env}.*.txt observations/${env}.*.ttl observations/${env}.*.ttl*.log
rm -f html_reports/${env}.*.observations.html

echo "+++ env: ${env} +++"

_checkobservations() {
    barnard59="barnard59"
    cube=${1}
    shift
    env=${1:-prod}.
    datasource=`echo ${env} | sed -re "s~^([a-z]+)(\.?)~\u\1~"`
    endpoint=https://${env//prod./}ld.admin.ch/query

    [[ ${CI} == true ]] && echo === endpoint: ${endpoint} === cube: ${cube} ===
    cubename_base="${env}${cube//[^A-Za-z0-9 ]/_}"
    metadata=metadata/${cubename_base}.ttl
    observations=observations/${cubename_base}.ttl
    txtreport=observations/${cubename_base}.txt
    htmlreport=html_reports/${cubename_base}.observations.html
    cmd="npx barnard59 cube fetch-metadata --endpoint ${endpoint} --cube ${cube} > metadata.ttl<br />npx barnard59 cube fetch-observations --endpoint ${endpoint} --cube ${cube} | npx barnard59 cube check-observations --constraint metadata.ttl | npx barnard59 shacl report-summary"
    touch ${observations}
    until [ -s ${observations} ] ; do \
      cat query-observation-sample.rq | sed -e "s~\${cube}~${cube}~" | curl ${endpoint} -f -s -X POST -H 'Accept: application/n-triples' -H 'Content-Type: application/sparql-query' --data-binary @- -o ${observations} || ( rm -f ${observations} ; sleep `shuf -i 5-20 -n 1` )
    done
    until [ -s ${txtreport} ] ; do \
      cat ${observations} | ${barnard59} cube check-observations --constraint ${metadata} 2> ${observations}.check.log | ${barnard59} shacl report-summary 2> ${observations}.report.log > ${txtreport}
      grep success ${txtreport} > /dev/null && grep Error ${observations}.*.log > /dev/null && ( echo "VALIDATION_FAILED" ; cat ${observations}.*.log ) > ${txtreport} # double check for Errors
    done

    status=`cat ${metadata} | grep -oP "<http://schema.org/creativeWorkStatus> <https://ld.admin.ch/vocabulary/CreativeWorkStatus/\K[A-Za-z]+"` || status=Error
    modified=`cat ${metadata} | grep -oP "<http://schema.org/dateModified> \"\K[0-9:\.\-\+TZ]+"` || modified=undefined
    visualize="<a href=\"https://${env//prod./}visualize.admin.ch/create/new?cube=${cube}&dataSource=${datasource}\" target=_blank>visualize</a>"
    validator="<a href=\"https://cube-validator.lindas.admin.ch/validate/$(echo -n ${endpoint} | jq -sRr @uri)/$(echo -n ${cube} | jq -sRr @uri)?tab=observation&profile=$(echo -n https://cube.link/ref/main/shape/profile-visualize | jq -sRr @uri)\" target=_blank>validated</a>"
    echo "<h2 class=${status}><a href=#${cube//[^A-Za-z0-9 ]/_} name=${cube//[^A-Za-z0-9 ]/_} class=a>#</a> ${cube}</h2>" >> ${htmlreport}
    echo "<div class=main><div class='c c1'>endpoint: ${endpoint}<br />" >> ${htmlreport}
    echo "status: ${status}<br />" >> ${htmlreport}

    echo "modified: `echo ${modified} | sed -e "s~\.[0-9]*~~" | sed -e "s~\+00:00~Z~"`<br />" >> ${htmlreport}
    echo "${visualize}<br />" >> ${htmlreport}
    echo "${validator}: `date -u +"%Y-%m-%dT%H:%M:%SZ"`</div>" >> ${htmlreport}
    echo "<div class='c c2'>" >> ${htmlreport}
    if `grep success ${txtreport} > /dev/null` ; then
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
export -f _checkobservations

[[ ${CI} == true ]] || bar="--bar"
parallel ${bar} _checkobservations :::: ${env}.cubes.txt ::: ${env}

echo "<style>body { font-family: sans-serif; background-color: #eee; } .a { text-decoration:none; color:lightgrey; } .main { display: flex; } .c { min-width:max-content; margin: 0 1em 0 0; } .c1 { width: 350px; } .c2 { width: 130px; } .cmax { width: 100%; overflow: hidden; } .report { max-height: 25vh; font-family: monospace; background-color: #1c1c1c; overflow: auto; white-space: nowrap; padding: 0.4em; font-size:0.8em; border: 1px solid #999; border-radius: 0.4em; } .silver { background-color: silver !important; } .failed { background-color: orange !important; } .violation { color: red; } .warning { color: orangered; } .info { color: orange; } .success { color: darkgreen; } .cmd { color: #eee; font-size: 0.6em; } .Published { color: black; } .Draft { color: grey; } .Error { color: red; }</style>" > html_reports/${env}.summary.observations.html
echo "<script>document.addEventListener('click', e => { if (e.target.matches('.cmd')) { navigator.clipboard.writeText(e.target.textContent).then(() => console.log('copied text'), error => console.error('failed to copy', error)); } });</script>" >> html_reports/${env}.summary.observations.html
echo "<h1><a href=.>Cube Monitor</a> ${env} observations</h1>" >> html_reports/${env}.summary.observations.html
cat html_reports/${env}.http*.observations.html >> html_reports/${env}.summary.observations.html
