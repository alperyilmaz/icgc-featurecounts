# Troubleshooting

## I'm getting lots of '403 Forbidden' errors

The main reason for this behaviour is: Your links that were created in step 1 did run out of time. Process `fetch_encrypted_s3_url` gets pre-authenticated S3 URLs for the requested BAM files and passes these to process `featureCounts`. If you have many BAM files that in total take more than a day for downloading and processing (> ~30), you might want to split the workload to multiple machines. More detailed information can be found [here](http://docs.icgc.org/cloud/guide/#how-long-will-pre-signed-urls-remain-valid).

## Why can't I run everything in conda?

The reason for this is mainly process `fetch_encrypted_s3_url`that relies on the [Overture Score-client](https://github.com/overture-stack/score) for fetching pre-authenticated URLs from AWS S3. While making a Bioconda or conda-forge recipe for this tool available wouldn't be a general issue, the requirement to use Oracle Java for running causes some trouble. Neither Bioconda nor conda-forge provide access to Oracle Java (and instead rely on OpenJDK/OpenJRE), thus making packaging the score client [unfeasible](https://github.com/bioconda/bioconda-recipes/issues/8540) for now.

## Input Manifest not found

Please make sure to specify a manifest file in the correct format. These are automatically created by the ICGC/DCC Data Portal in the correct `.tsv.gz` format and should only be unpacked to `tsv` format. Do not modify the files as the header is required to read the `object_id` and `file_name` information correctly. Further requirements:

1. The path must be enclosed in quotes (`'` or `"`)

If the pipeline can't find your manifest then you will get the following error

```
ERROR ~ Manifest file not found
```

## Extra resources and getting help
If you still have an issue with running the pipeline then feel free to contact us.
Have look at the [pipeline website](https://github.com/nf-core/ICGC-FeatureCounts) to find out how.

If you have problems that are related to Nextflow and not our pipeline then check out the [Nextflow gitter channel](https://gitter.im/nextflow-io/nextflow) or the [google group](https://groups.google.com/forum/#!forum/nextflow).
