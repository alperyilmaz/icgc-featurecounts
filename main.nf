#!/usr/bin/env nextflow
/*
========================================================================================
                         ICGC-FeatureCounts
========================================================================================
 ICGC-FeatureCounts Analysis Pipeline. Started 2018-07-19.
 #### Homepage / Documentation
 https://github.com/apeltzer/nf-icgc-featureCounts
 #### Authors
 Alexander Peltzer apeltzer <alexander.peltzer@qbic.uni-tuebingen.de> - https://github.com/apeltzer>
----------------------------------------------------------------------------------------
*/


def helpMessage() {
    log.info"""
    =========================================
     ICGC-FeatureCounts v${params.version}
    =========================================
    Usage:

    The typical command for running the pipeline is as follows:

    nextflow run nf-icgc-featureCounts --manifest 'manifest.tsv' --gtf human.grch37.gtf -profile docker

    Mandatory arguments:
      --manifest                    Path to manifest file as created from ICGC DCC Portal
      --gtf                         GTF file for featureCounts
      -profile                      Hardware config to use, e.g. docker / aws

    Other options:
      --outdir                      The output directory where the results will be saved. Must be an S3 bucket on AWS Region used by ICGC (Virginia).
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.
    """.stripIndent()
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Show help emssage
if (params.help){
    helpMessage()
    exit 0
}

// Configurable variables
params.name = false
params.fasta = false
params.gtf = false
params.manifest = false
params.multiqc_config = "$baseDir/conf/multiqc_config.yaml"
params.email = false
params.plaintext_email = false

multiqc_config = file(params.multiqc_config)
output_docs = file("$baseDir/docs/output.md")

// Validate inputs
if ( params.fasta ){
    fasta = file(params.fasta)
    if( !fasta.exists() ) exit 1, "Fasta file not found: ${params.fasta}"
}
//
// NOTE - THIS IS NOT USED IN THIS PIPELINE, EXAMPLE ONLY
// If you want to use the above in a process, define the following:
//   input:
//   file fasta from fasta
//


// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}




// Header log info
log.info """=======================================================
                                          ,--./,-.
          ___     __   __   __   ___     /,-._.--~\'
    |\\ | |__  __ /  ` /  \\ |__) |__         }  {
    | \\| |       \\__, \\__/ |  \\ |___     \\`-._,-`-,
                                          `._,._,\'

ICGC-FeatureCounts v${params.version}"
======================================================="""
def summary = [:]
summary['Pipeline Name']  = 'ICGC-FeatureCounts'
summary['Pipeline Version'] = params.version
summary['Run Name']     = custom_runName ?: workflow.runName
summary['Manifest']     = params.manifest
summary['GTF']          = params.gtf
summary['Max Memory']   = params.max_memory
summary['Max CPUs']     = params.max_cpus
summary['Max Time']     = params.max_time
summary['Output dir']   = params.outdir
summary['Working dir']  = workflow.workDir
summary['Container Engine'] = workflow.containerEngine
if(workflow.containerEngine) summary['Container'] = workflow.container
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Working dir']    = workflow.workDir
summary['Output dir']     = params.outdir
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile
if(params.email) summary['E-mail Address'] = params.email
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="


// Check that Nextflow version is up to date enough
// try / throw / catch works for NF versions < 0.25 when this was implemented
try {
    if( ! nextflow.version.matches(">= $params.nf_required_version") ){
        throw GroovyException('Nextflow version too old')
    }
} catch (all) {
    log.error "====================================================\n" +
              "  Nextflow version $params.nf_required_version required! You are running v$workflow.nextflow.version.\n" +
              "  Pipeline execution will continue, but things may break.\n" +
              "  Please run `nextflow self-update` to update Nextflow.\n" +
              "============================================================"
}


/*
 * Parse software version numbers
 */
process get_software_versions {

    output:
    file 'software_versions_mqc.yaml' into software_versions_yaml

    script:
    """
    echo $params.version > v_pipeline.txt
    echo $workflow.nextflow.version > v_nextflow.txt
    featureCounts --version > v_featurecounts.txt
    multiqc --version > v_multiqc.txt
    scrape_software_versions.py > software_versions_mqc.yaml
    """
}

/*
* Channel should be set up to S3 storage entitites from a single TSV file (Manifest from ICGC)
* repo_code	file_id	object_id	file_format	file_name	file_size	md5_sum	index_object_id	donor_id/donor_count	project_id/project_count	study
* We'd need to access the object_id and probably take the file_name with us too ,-) 
*/
file_manifest = file("${params}.manifest")

crypted_object_ids = Channel
                   .from(file_manifest)
                   .splitCsv(header: true, sep="\t")
                   .view { row -> "${row.object_id}" }


/*
 * STEP 0 - ICGC Score Client to get S3 URL
 */
process fetch_encrypted_s3_url {
    tag "$id"
    
    input:
    val id from crypted_object_ids

    output:
    stdout into s3_url

    script:
    """
    score-client url --object-id $id
    """
}

/*
* STEP 1 - FeatureCounts on RNAseq BAM files
*/

process featureCounts{

    input:
    val sc_stdout from s3_url

    output:


}



/*
 * STEP 9 - Merge featurecounts
 */
process merge_featureCounts {
    tag "${input_files[0].baseName - '.sorted'}"
    publishDir "${params.outdir}/featureCounts", mode: 'copy'

    input:
    file input_files from featureCounts_to_merge.collect()

    output:
    file 'merged_gene_counts.txt'

    script:
    """
    merge_featurecounts.py -o merged_gene_counts.txt -i $input_files
    """
}


/*
* STEP 2 - MultiQC to summarize run
*/

