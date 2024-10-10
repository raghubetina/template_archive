# Use Ubuntu 20.04 x86_64 as the base image
# Note: Specifying the architecture as amd64 is important for compatibility with
# Stata, even though it's generally not recommended to do this in Dockerfiles.
FROM --platform=linux/amd64 ubuntu:20.04

# Set non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive

# Preconfigure tex-common to skip format generation
RUN apt-get update -y && \
    apt-get install -y debconf

RUN echo "tex-common tex-common/singleuser note ''" | debconf-set-selections && \
    echo "texlive-base texlive-base/texconfig_migrate note ''" | debconf-set-selections

# Update and install basic utilities
RUN apt-get install -y wget curl git build-essential ca-certificates

# Install git-lfs
RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | bash && \
    apt-get install -y git-lfs && \
    git lfs install

# Install Miniconda (x86_64 version)
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh

# Set PATH to include conda
ENV PATH=/opt/conda/bin:$PATH

# Initialize conda
RUN conda config --set auto_activate_base false && \
    conda init bash

# Copy conda environment file
COPY setup/conda_env.yaml /tmp/conda_env.yaml

# Update conda and create environment
RUN conda update -n base -c defaults conda && \
    conda env create -f /tmp/conda_env.yaml

# Activate the environment
ENV CONDA_DEFAULT_ENV=template
ENV PATH /opt/conda/envs/template/bin:$PATH

# Install R and R packages
RUN apt-get install -y r-base r-base-dev

# Copy R setup script
COPY setup/setup_r.r /tmp/setup_r.r

# Install R packages
RUN Rscript /tmp/setup_r.r

# Install Julia
RUN wget --quiet https://julialang-s3.julialang.org/bin/linux/x64/1.9/julia-1.9.3-linux-x86_64.tar.gz -O /tmp/julia.tar.gz && \
    tar -xzf /tmp/julia.tar.gz -C /opt && \
    ln -s /opt/julia-1.9.3/bin/julia /usr/local/bin/julia && \
    rm /tmp/julia.tar.gz

# Copy Julia setup script
COPY setup/julia_conda_env.jl /tmp/julia_conda_env.jl

# Install Julia packages
RUN julia /tmp/julia_conda_env.jl

# Install minimal TeX Live packages
RUN apt-get install -y --no-install-recommends \
    texlive-latex-base \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    texlive-latex-extra

# Manually generate formats after installation
RUN fmtutil-sys --all

# Install LyX
RUN apt-get install -y lyx

# Clean up apt cache to reduce image size
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set working directory
WORKDIR /app

# Copy project files into the image
COPY . /app

# Fetch gslab_make submodule
RUN git submodule update --init --recursive

# Run setup script
WORKDIR /app/setup
RUN python check_setup.py

# Build the repository
WORKDIR /app
RUN python run_all.py

# Default command
CMD ["/bin/bash"]
