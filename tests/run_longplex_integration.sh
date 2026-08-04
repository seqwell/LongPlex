t#!/usr/bin/env bash

nextflow run \
    -profile docker \
    -c "${PWD}/nextflow.config" \
    -c "${PWD}/tests/limit-resources.config" \
    main_conda.nf \
    --pool_sheet "${PWD}/tests/pool_sheet.csv" \
    --output  "${PWD}/output/"
