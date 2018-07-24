#!/usr/bin/env python
from __future__ import print_function
from collections import OrderedDict
import re

regexes = {
    'ICGC-FeatureCounts': ['v_pipeline.txt', r"(\S+)"],
    'Nextflow': ['v_nextflow.txt', r"(\S+)"],
     'featureCounts': ['v_featurecounts.txt', r"featureCounts v(\S+)"]
}
results = OrderedDict()
results['ICGC-FeatureCounts'] = '<span style="color:#999999;\">N/A</span>'
results['Nextflow'] = '<span style="color:#999999;\">N/A</span>'
results['featureCounts'] = '<span style="color:#999999;\">N/A</span>'

# Search each file using its regex
for k, v in regexes.items():
    with open(v[0]) as x:
        versions = x.read()
        match = re.search(v[1], versions)
        if match:
            results[k] = "v{}".format(match.group(1))

# Dump to YAML
print ('''
id: 'icgc-featurecounts-software-versions'
section_name: 'nf-icgc-featureCounts Software Versions'
section_href: 'https://github.com/apeltzer/nf-icgc-featureCounts'
plot_type: 'html'
description: 'are collected at run time from the software output.'
data: |
    <dl class="dl-horizontal">
''')
for k,v in results.items():
    print("        <dt>{}</dt><dd>{}</dd>".format(k,v))
print ("    </dl>")
