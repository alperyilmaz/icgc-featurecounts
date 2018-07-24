# ICGC-FeatureCounts
This pipeline takes some BAM files from ICGC and runs featureCounts on them.

[![Build Status](https://travis-ci.org/ICGC-FeatureCounts.svg?branch=master)](https://travis-ci.org/ICGC-FeatureCounts)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.30.0-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](http://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/icgc-featurecounts.svg)](https://hub.docker.com/r/icgc-featurecounts)
![Singularity Container available](
https://img.shields.io/badge/singularity-available-7E4C74.svg)

### Introduction
ICGC-FeatureCounts: This pipeline takes some BAM files from ICGC and runs featureCounts on them.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker / singularity containers making installation trivial and results highly reproducible.


### Documentation
The ICGC-FeatureCounts pipeline comes with documentation about the pipeline, found in the `docs/` directory:

1. [Installation](docs/installation.md)
2. Pipeline configuration
    * [Local installation](docs/configuration/local.md)
    * [Adding your own system](docs/configuration/adding_your_own.md)
3. [Running the pipeline](docs/usage.md)
4. [Output and how to interpret the results](docs/output.md)
5. [Troubleshooting](docs/troubleshooting.md)

### Credits
This pipeline was written by Alexander Peltzer ([apeltzer](https://github.com/apeltzer)) at [QBiC](apeltzer.github.io).
