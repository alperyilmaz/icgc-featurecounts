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
params.test = false

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
        .set {gtf_featureCounts}
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
    set val(file_name), file('s3_path.txt') into s3_url

    script:
    if(params.test){
        """
        echo "ftp://ftp.1000genomes.ebi.ac.uk/vol1/ftp/technical/pilot3_exon_targetted_GRCh37_bams/data/NA06994/alignment/NA06994.chrom21.LS454.ssaha2.CEU.exon_targetted.20100311.bam" > "s3_path.txt"
        """
    } else {
    """
    export ACCESSTOKEN=$params.accesstoken
    /score-client/bin/score-client url --object-id $id | grep -e "^https*" > s3_path.txt
    """
    }
}

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
    set val(file_name), val(s3_path) from s3_url
    file gtf from gtf_featureCounts.collect()
    file biotypes_header

    output:
    file "${file_name}_gene.featureCounts.txt" into geneCounts, featureCounts_to_merge
    file "${file_name}_gene.featureCounts.txt.summary" into featureCounts_logs
    file "${file_name}_biotype_counts*mqc.{txt,tsv}" into featureCounts_biotype

    script:
    url = file(s3_path).text
    url = url.trim()
    def featureCounts_direction = 0
    if (forward_stranded && !unstranded) {
        featureCounts_direction = 1
    } else if (reverse_stranded && !unstranded){
        featureCounts_direction = 2
    }
    // Try to get real sample name
    """
    wget -O $file_name \"${url}\"
    featureCounts -a $gtf -g gene_id -o ${file_name}_gene.featureCounts.txt -p -s $featureCounts_direction $file_name
    featureCounts -a $gtf -g gene_biotype -o ${file_name}_biotype.featureCounts.txt -p -s $featureCounts_direction $file_name
    cut -f 1,7 ${file_name}_biotype.featureCounts.txt | tail -n +3 | cat $biotypes_header - >> ${file_name}_biotype_counts_mqc.txt
    mqc_features_stat.py ${file_name}_biotype_counts_mqc.txt -s $file_name -f rRNA -o ${file_name}_biotype_counts_gs_mqc.tsv
    """


}



/*
 * STEP 9 - Merge featurecounts
 */
process merge_featureCounts {
    tag "${input_files[0]}"
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
 * Pipeline parameters to go into MultiQC report
 */
process workflow_summary_mqc {
    executor 'local'
    output:
    file 'workflow_summary_mqc.yaml' into workflow_summary_yaml

    exec:
    def yaml_file = task.workDir.resolve('workflow_summary_mqc.yaml')
    yaml_file.text  = """
    id: 'nfcore-icgc-featurecounts-summary'
    description: " - this information is collected when the pipeline is started."
    section_name: 'nfcore/ICGC-FeatureCounts Workflow Summary'
    section_href: 'https://github.com/nf-core/ICGC-FeatureCounts'
    plot_type: 'html'
    data: |
        <dl class=\"dl-horizontal\">
${summary.collect { k,v -> "            <dt>$k</dt><dd><samp>${v ?: '<span style=\"color:#999999;\">N/A</a>'}</samp></dd>" }.join("\n")}
        </dl>
    """.stripIndent()
}


/*
* STEP 2 - MultiQC to summarize run
*/

process multiqc {
    publishDir "${params.outdir}/MultiQC", mode: 'copy'

    input:
    file multiqc_config
    file ('featureCounts/*') from featureCounts_logs.collect()
    file ('featureCounts_biotype/*') from featureCounts_biotype.collect()
    file ('software_versions/*') from software_versions_yaml.collect()
    file ('workflow_summary/*') from workflow_summary_yaml.collect()

    output:
    file "*multiqc_report.html" into multiqc_report
    file "*_data"

    script:
    rtitle = ''
    rfilename = ''
    """
    multiqc . -f $rtitle $rfilename --config $multiqc_config \\
        -m custom_content -m featureCounts
    """
}

