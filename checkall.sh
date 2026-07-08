#!/bin/bash
env=${1:-prod}

echo "<style>body { font-family: sans-serif; background-color: #eee; } .a { text-decoration:none; color:lightgrey; } .main { display: flex; } .c { min-width:max-content; margin: 0 1em 0 0; } .c1 { width: 350px; } .c2 { width: 130px; } .cmax { width: 100%; overflow: hidden; } .report { max-height: 25vh; font-family: monospace; background-color: #1c1c1c; overflow: auto; white-space: nowrap; padding: 0.4em; font-size:0.8em; border: 1px solid #999; border-radius: 0.4em; } .silver { background-color: silver !important; } .failed { background-color: orange !important; } .violation { color: red; } .warning { color: orangered; } .info { color: orange; } .success { color: darkgreen; } .cmd { color: #eee; font-size: 0.6em; } .Published { color: black; } .Draft { color: grey; } .Error { color: red; }</style>" > html_reports/${env}.summary.html
echo "<script>document.addEventListener('click', e => { if (e.target.matches('.cmd')) { navigator.clipboard.writeText(e.target.textContent).then(() => console.log('copied text'), error => console.error('failed to copy', error)); } });</script>" >> html_reports/${env}.summary.html
echo "<h1><a href=.>Cube Monitor</a> ${env}</h1>" >> html_reports/${env}.summary.html
for i in html_reports/${env}.http*.*.html ; do \
  echo $i | grep metadata > /dev/null && cat $i >> html_reports/${env}.summary.html || ( echo "<div class=main><div class='c c1'>" && tail -n+6 $i ) >> html_reports/${env}.summary.html
done
