# ICGC-FeatureCounts: Configuration for other clusters

It is entirely possible to run this pipeline on other clusters, though you will need to set up your own config file so that the pipeline knows how to work with your cluster.

> If you think that there are other people using the pipeline who would benefit from your configuration (eg. other common cluster setups), please let us know. We can add a new configuration and profile which can used by specifying `-profile <name>` when running the pipeline.

If you are the only person to be running this pipeline, you can create your config file as `~/.nextflow/config` and it will be applied every time you run Nextflow. Alternatively, save the file anywhere and reference it when running the pipeline with `-c path/to/config` (see the [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more).

A basic configuration comes with the pipeline, which runs by default (the `standard` config profile - see [`conf/base.config`](../conf/base.config)). This means that you only need to configure the specifics for your system and overwrite any defaults that you want to change.

## Cluster Environment

By default, the pipeline uses the `local` Nextflow executor - in other words, all jobs are run in the login session. If you're using a simple server, this may be fine. If you're using a compute cluster, this is bad as all jobs will run on the head node.

To specify your cluster environment, add the following line to your config file:

```nextflow
process {
  executor = 'YOUR_SYSTEM_TYPE'
}
```

Many different cluster types are supported by Nextflow. For more information, please see the [Nextflow documentation](https://www.nextflow.io/docs/latest/executor.html).

Note that you may need to specify cluster options, such as a project or queue. To do so, use the `clusterOptions` config option:

```nextflow
process {
  executor = 'SLURM'
  clusterOptions = '-A myproject'
}
```

## Software Requirements
To run the pipeline, several software packages are required. How you satisfy these requirements is essentially up to you and depends on your system. If possible, we _highly_ recommend using either Docker or Singularity.

### Docker
Docker is a great way to run ICGC-FeatureCounts, as it manages all software installations and allows the pipeline to be run in an identical software environment across a range of systems.

Nextflow has [excellent integration](https://www.nextflow.io/docs/latest/docker.html) with Docker, and beyond installing the two tools, not much else is required.

First, install docker on your system: [Docker Installation Instructions](https://docs.docker.com/engine/installation/)

Then, simply run the analysis pipeline:
```bash
nextflow run ICGC-FeatureCounts -profile docker --reads '<path to your reads>'
```

Nextflow will recognise `ICGC-FeatureCounts` and download the pipeline from GitHub. The `-profile docker` configuration lists the [icgc-featurecounts](https://hub.docker.com/r/nfcore/icgc-featurecounts/) image that we have created and is hosted at dockerhub, and this is downloaded.

The public docker images are tagged with the same version numbers as the code, which you can use to ensure reproducibility. When running the pipeline, specify the pipeline version with `-r`, for example `-r v1.0.0`. This uses pipeline code and docker image from this tagged version.

To add docker support to your own config file (instead of using the `docker` profile, which runs locally), add the following:

```nextflow
docker {
  enabled = true
}
process {
  container = wf_container
}
```

The variable `wf_container` is defined dynamically and automatically specifies the image tag if Nextflow is running with `-r`.

A test suite for docker comes with the pipeline, and can be run by simply using the test profile:
```bash
nextflow run nf-core/ICGC-featurecounts -profile test 
```
This is also automatically run using [Travis](https://travis-ci.org/ICGC-FeatureCounts/) whenever changes are made to the pipeline.

### Singularity image
Many HPC environments are not able to run Docker due to security issues. [Singularity](http://singularity.lbl.gov/) is a tool designed to run on such HPC systems which is very similar to Docker. Even better, it can use create images directly from dockerhub.

To use the singularity image for a single run, use `-with-singularity 'shub://nf-core/ICGC-featureCounts'`. This will download the Singularity container from Singularity hub.

To specify singularity usage in your pipeline config file, use the profile Singularity.
