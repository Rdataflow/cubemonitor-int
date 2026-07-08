#!/bin/bash

cd html_reports

echo "<h1>Cube Monitor</h1>" > index.html
for env in test int prod ; do
    echo "<h2><a href=${env}.summary.html>${env}</a></h2>" >> index.html
    for entry in metadata observations ; do
        echo "<h3><a href=${env}.summary.${entry}.html>${entry}</a></h3>" >> index.html
    done
done
