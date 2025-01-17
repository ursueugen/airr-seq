version development

import "https://raw.githubusercontent.com/antonkulaga/bioworkflows/main/common/files.wdl" as files


workflow clonal_analysis {

    input {
        File airr_tsv
        String destination
        String name
        Int threads = 12
        Float clones_bin_width = 0.02
        Int max_memory_gb = 96
    }

    call analyze_clones {
        input:
            airr_tsv = airr_tsv,
            name = name,
            binwidth = clones_bin_width,
            threads = threads,
            max_memory = max_memory_gb
    }

    call files.copy as copy_clones {
        input: destination = destination + "/" + "clones",
            files = [
                    analyze_clones.out,
                    analyze_clones.histogram,
                    analyze_clones.vjl_groups
                    ]
    }

    call analyze_diversity {
        input: clones_tsv = analyze_clones.out, name = name
    }

    call files.copy as copy_diversity {
        input: destination = destination + "/" + "clones" + "/" + "diversity",
            files = [
                    analyze_diversity.clone_counts_tsv,
                    analyze_diversity.coverages_tsv,
                    analyze_diversity.abundance_tsv,
                    analyze_diversity.abundance_chart,
                    analyze_diversity.diversity_tsv,
                    analyze_diversity.diversity_chart,
                    ]
    }

    output {
        File clones = copy_clones.destination_folder
        File diversity = copy_diversity.destination_folder
    }

}

task analyze_clones {
    input {
        File airr_tsv
        String name
        String suffix = "_with_clones"
        Float binwidth = 0.02
        Int threads
        Int max_memory
        String method = "novj"
    }
    String method_suffix = "_" + method + "_"

    command {
        clones.R analyze_clones --name ~{name} --suffix ~{suffix} --threads ~{threads} --binwidth ~{binwidth} ~{airr_tsv}
    }

    runtime {
        docker: "quay.io/comp-bio-aging/immcantation"
        docker_memory: "~{max_memory}G"
        docker_cpu: "~{threads+1}"
    }

    output {
        File out = name +"_"+ method + suffix + ".tsv"
        File histogram = name + "_"+ method + suffix + ".svg"
        File vjl_groups = name+ method_suffix + "groups" + ".tsv"
    }
}

task analyze_diversity {
    input {
        File clones_tsv
        String name
    }

    command {
        clones.R analyze_diversity --name ~{name} ~{clones_tsv}
    }

    runtime {
        docker: "quay.io/comp-bio-aging/immcantation"
    }

    output {
        File clone_counts_tsv = name + "_clone_counts.tsv"
        File coverages_tsv = name + "_coverages.tsv"
        File abundance_tsv = name + "_abundance_curve.tsv"
        File abundance_chart = name + "_abundancy_curve.svg"
        File diversity_tsv = name + "_diversity.tsv"
        File diversity_chart = name + "_diversity.svg"
    }
}