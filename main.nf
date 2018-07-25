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
      --accesstoken                 The ICGC/TCGA access token used for retrieving the files on AWS S3

      Strandedness:
      --forward_stranded            The library is forward stranded
      --reverse_stranded            The library is reverse stranded
      --unstranded                  The default behaviour

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
params.gtf = false
params.manifest = false
params.multiqc_config = "$baseDir/conf/multiqc_config.yaml"
params.email = false
params.plaintext_email = false

biotypes_header = file("$baseDir/assets/biotypes_header.txt")
multiqc_config = file(params.multiqc_config)
output_docs = file("$baseDir/docs/output.md")

forward_stranded = params.forward_stranded
reverse_stranded = params.reverse_stranded
unstranded = params.unstranded

multiqc_config = file(params.multiqc_config)
output_docs = file("$baseDir/docs/output.md")

// Validate inputs
if ( params.manifest ){
    manifest = file(params.manifest)
    if( !manifest.exists() ) exit 1, "Manifest file not found: ${params.manifest}"
}

if( params.gtf ){
    Channel
        .fromPath(params.gtf)
        .ifEmpty { exit 1, "GTF annotation file not found: ${params.gtf}" }
        .into {gtf_featureCounts}
} else {
    exit 1, "No GTF annotation specified!"
}


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
    featureCounts -v &> v_featurecounts.txt
    multiqc --version > v_multiqc.txt
    scrape_software_versions.py > software_versions_mqc.yaml
    """
}

/*
* Channel should be set up to S3 storage entitites from a single TSV file (Manifest from ICGC)
* repo_code	file_id	object_id	file_format	file_name	file_size	md5_sum	index_object_id	donor_id/donor_count	project_id/project_count	study
* We'd need to access the object_id and probably take the file_name with us too ,-) 
*/
file_manifest = file(params.manifest)

//Create channel for file_name/object_id tuples
//crypted_object_ids = Channel.create()

crypted_object_ids = Channel.from(file_manifest)
       .splitCsv(header: true, sep:'\t')
       .map { row -> tuple("${row.file_name}", "${row.object_id}")}
       //.set (crypted_object_ids)

/*
 * STEP 0 - ICGC Score Client to get S3 URL
 */
process fetch_encrypted_s3_url {
    tag "$file_name"
    
    input:
    set val(file_name), val(id) from crypted_object_ids

    output:
    set val(file_name), val(url) into s3_url

    script:
    """
    export ACCESSTOKEN=$params.accesstoken
    url=$(/score-client/bin/score-client url --object-id $id | grep -e "^https*")
    """
}

//TODO get a set of file_name and object_id, also produce file_name and then attach the s3 URL to it

/*
* STEP 1 - FeatureCounts on RNAseq BAM files
*/

process featureCounts{
    tag "$file_name"
    publishDir "${params.outdir}/featureCounts", mode: 'copy',
        saveAs: {filename ->
            if (filename.indexOf("biotype_counts") > 0) "biotype_counts/$filename"
            else if (filename.indexOf("_gene.featureCounts.txt.summary") > 0) "gene_count_summaries/$filename"
            else if (filename.indexOf("_gene.featureCounts.txt") > 0) "gene_counts/$filename"
            else "$filename"
        }

    input:
    set val(file_name), val(url) from s3_url
    file gtf from gtf_featureCounts.collect()
    file biotypes_header

    output:
    file "${bam_featurecounts.baseName}_gene.featureCounts.txt" into geneCounts, featureCounts_to_merge
    file "${bam_featurecounts.baseName}_gene.featureCounts.txt.summary" into featureCounts_logs
    file "${bam_featurecounts.baseName}_biotype_counts*mqc.{txt,tsv}" into featureCounts_biotype

    script:
    def featureCounts_direction = 0
    if (forward_stranded && !unstranded) {
        featureCounts_direction = 1
    } else if (reverse_stranded && !unstranded){
        featureCounts_direction = 2
    }
    // Try to get real sample name
    """
    wget -O $file_name $url
    featureCounts -a $gtf -g gene_id -o ${bam_featurecounts.baseName}_gene.featureCounts.txt -p -s $featureCounts_direction $file_name
    featureCounts -a $gtf -g gene_biotype -o ${bam_featurecounts.baseName}_biotype.featureCounts.txt -p -s $featureCounts_direction $file_name
    cut -f 1,7 ${file_name.baseName}_biotype.featureCounts.txt | tail -n +3 | cat $biotypes_header - >> ${file_name.baseName}_biotype_counts_mqc.txt
    mqc_features_stat.py ${file_name.baseName}_biotype_counts_mqc.txt -s $file_name -f rRNA -o ${file_name.baseName}_biotype_counts_gs_mqc.tsv
    """


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

