# ICGC-FeatureCounts: Local Configuration

If running the pipeline in a local environment, we highly recommend using either Docker or Singularity.

## Docker
Docker is a great way to run ICGC-FeatureCounts, as it manages all software installations and allows the pipeline to be run in an identical software environment across a range of systems.

Nextflow has [excellent integration](https://www.nextflow.io/docs/latest/docker.html) with Docker, and beyond installing the two tools, not much else is required. The ICGC-FeatureCounts profile comes with a configuration profile for docker, making it very easy to use. 

First, install docker on your system: [Docker Installation Instructions](https://docs.docker.com/engine/installation/)

Then, simply run the analysis pipeline:
```bash
nextflow run nf-core/ICGC-FeatureCounts -profile docker --manifest '<path to your manifest>' --gtf '<path to your gtf file>' 
```

Nextflow will recognise `ICGC-FeatureCounts` and download the pipeline from GitHub. The `-profile docker` configuration lists the [icgc-featurecounts](https://hub.docker.com/r/nfcore/icgc-featurecounts/) image that we have created and is hosted at dockerhub, and this is downloaded.


### Pipeline versions
The public docker images are tagged with the same version numbers as the code, which you can use to ensure reproducibility. When running the pipeline, specify the pipeline version with `-r`, for example `-r v1.0.0`. This uses pipeline code and docker image from this tagged version.


## Singularity image
Many HPC environments are not able to run Docker due to security issues. [Singularity](http://singularity.lbl.gov/) is a tool designed to run on such HPC systems which is very similar to Docker. Even better, it can use create images directly from dockerhub.

To use the singularity image for a single run, use `-with-singularity 'shub://nf-core/ICGC-featureCounts'`. This will download the Singularity container from Singularity hub automatically.

If you intend to run the pipeline offline, nextflow will not be able to automatically download the singularity image for you. Instead, you'll have to do this yourself manually first, transfer the image file and then point to that.

First, pull the image file where you have an internet connection:

```bash
singularity pull --name icgc-featurecounts.simg shub://nf-core/ICGC-featureCounts
```

Then transfer this file and run the pipeline with this path:

```bash
nextflow run /path/to/ICGC-FeatureCounts -with-singularity /path/to/icgc-featurecounts.simg
```
