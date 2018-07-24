FROM nfcore/base
MAINTAINER Alexander Peltzer <alexander.peltzer@qbic.uni-tuebingen.de>
LABEL authors="alexander.peltzer@qbic.uni-tuebingen.de" \
    description="Docker image containing all requirements for ICGC-FeatureCounts pipeline"

COPY environment.yml /
RUN conda env update -n root -f /environment.yml && conda clean -a
