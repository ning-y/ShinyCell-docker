# syntax=docker/dockerfile:1

FROM rocker/r2u:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    SHINYCELL_APP_DIR=/srv/shinycell-app \
    SHINYCELL_PORT=3838

RUN apt-get update && apt-get install -y --no-install-recommends \
    r-cran-seurat \
    r-cran-data.table \
    r-cran-matrix \
    r-cran-hdf5r \
    r-cran-httpuv \
    r-cran-reticulate \
    r-cran-r.utils \
    r-cran-ggplot2 \
    r-cran-gridextra \
    r-cran-glue \
    r-cran-readr \
    r-cran-rcolorbrewer \
    r-cran-shiny \
    r-cran-shinyhelper \
    r-cran-dt \
    r-cran-magrittr \
    r-cran-ggdendro \
    r-cran-ggrepel \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/ShinyCell
COPY . /opt/ShinyCell
RUN Rscript -e "install.packages('/opt/ShinyCell', repos = NULL, type = 'source')" && \
    Rscript -e "stopifnot(requireNamespace('ShinyCell', quietly = TRUE))"

COPY docker/run_shinycell.R /usr/local/bin/run_shinycell.R
COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/run_shinycell.R /usr/local/bin/docker-entrypoint.sh && \
    mkdir -p "${SHINYCELL_APP_DIR}"

WORKDIR /data
VOLUME ["/data"]
EXPOSE 3838

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
