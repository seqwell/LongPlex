#!/usr/bin/env bash

nextflow run \
    -profile docker \
    -c "${PWD}/nextflow.config" \
    main.nf \
    --samplesheet "${PWD}/tests/samplesheet.csv" \
    --output  "${PWD}/output/"
