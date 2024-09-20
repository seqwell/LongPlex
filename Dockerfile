FROM 812206152185.dkr.ecr.us-west-2.amazonaws.com/latch-base-nextflow:v1.1.5

WORKDIR /tmp/docker-build/work/

SHELL [ \
    "/usr/bin/env", "bash", \
    "-o", "errexit", \
    "-o", "pipefail", \
    "-o", "nounset", \
    "-o", "verbose", \
    "-o", "errtrace", \
    "-O", "inherit_errexit", \
    "-O", "shift_verbose", \
    "-c" \
]

ENV TZ='Etc/UTC'

ENV LANG='en_US.UTF-8'

ARG DEBIAN_FRONTEND=noninteractive

RUN pip install latch==2.49.6

RUN mkdir /opt/latch

####################################################################################################

COPY . /root/

####################################################################################################

ARG tag

ENV FLYTE_INTERNAL_IMAGE $tag

WORKDIR /root
