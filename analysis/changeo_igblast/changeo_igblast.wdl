version development

import "https://raw.githubusercontent.com/antonkulaga/bioworkflows/main/common/files.wdl" as files


workflow changeo_igblast {
    input {
        File fastq
        Int threads
        String name
        String destination
    }

    call fastq_conversion {
        input: fastq = fastq
    }


    call igblast {
        input: fasta = fastq_conversion.out, threads = threads
    }

    call changeo {
        input: fasta = fastq_conversion.out, fmt7 = igblast.fmt7, name = name
    }

    call files.copy as copy_folder {
        input: destination = destination, files = [changeo.out]
    }

    call translate {
        input: files = [changeo.airr_tsv,changeo.functional]
    }

    call files.copy as copy_translations {
        input: destination = copy_folder.out[0], files = translate.out
    }



    output {
        File out = copy_folder.out[0]
        File airr_tsv = changeo.airr_tsv
        File airr_tsv_translated = copy_translations.out[0]
        File airr_tsv_translated_functional = copy_translations.out[1]
    }
}

task fastq_conversion {
    input{
        File fastq
    }
    command {
        fastq2fasta.py ~{fastq}
    }
    runtime {
        docker: "immcantation/suite:devel"
    }
    output {
        File out = basename(fastq, ".fastq") + ".fasta"
    }
}

task igblast {
    input {
        File fasta
        Int threads
    }
    command {
        mkdir -p igblast
        echo "~{basename(fasta, ".fasta")}_igblast.fmt7"
        AssignGenes.py igblast -s ~{fasta} -o ~{basename(fasta, ".fasta")}_igblast.fmt7 -b /usr/local/share/igblast --organism human --loci ig --format blast --nproc ~{threads}
        mv ~{basename(fasta, ".fasta")}_igblast.fmt7 igblast
    }
    runtime {
        docker: "immcantation/suite:devel"
    }

    output {
        File out = "igblast"
        File fmt7 = "igblast" + "/" + basename(fasta, ".fasta")+"_igblast.fmt7"
    }
}


task changeo {
    input {
        File fasta
        File fmt7
        String name
        String format = "airr"
        String outdir = "changeo_igblast"
    }

    command {
        mkdir -p changeo_igblast
        MakeDb.py igblast \
        -s ~{fasta} -i ~{fmt7} \
        -r /usr/local/share/germlines/imgt/human/vdj/ --outdir ~{outdir} --outname ~{name} --extended --format ~{format}

        # Adds germline_alignment_d_mask
        CreateGermlines.py -d ~{outdir}/~{name}_db-pass.tsv \
            --outdir ~{outdir} --format ~{format} \
            -r /usr/local/share/germlines/imgt/human/vdj/ \
            --log "~{outdir}/~{name}_germ.log"
            -g full dmask

        ParseDb.py select -d "~{outdir}/~{name}_db-pass_germ-pass.tsv" -f productive -u T TRUE --outname ~{name}_f
        ParseDb.py sort -d "~{outdir}/~{name}_db-pass_germ-pass.tsv" -o "~{outdir}/~{name}_germ.tsv" --num --descend -f duplicate_count
        ParseDb.py sort -d "~{outdir}/~{name}_f_parse-select.tsv" -o "~{outdir}/~{name}_functional.tsv" --num --descend -f duplicate_count
    }

    runtime {
        docker: "immcantation/suite:devel"
    }

    output {
        File out = outdir
        File airr_tsv = outdir + "/" + name + "_germ.tsv"
        File functional = outdir + "/" + name + "_functional.tsv"
        File log = outdir + "/" + name + "_germ.log"
    }

}

task translate {
    input {
        Array[File] files
        String suffix = "_with_translation"
    }
    String gl = "*"+suffix+".tsv"

    command {
        /home/magus/notebooks/translate.R --wd TRUE --suffix ~{suffix} ~{sep=" " files}
    }

    runtime {
        docker: "quay.io/comp-bio-aging/immcantation"
    }
    output {
        Array[File] out = glob(gl)
    }
}