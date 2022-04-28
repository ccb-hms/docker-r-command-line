#
# R Container Image
# Author: Nathan Palmer
# Copyright: Harvard Medical School
#

FROM hmsccb/ubuntu-interactive:20.04

#------------------------------------------------------------------------------
# Install and configure R
#------------------------------------------------------------------------------

# declare R version to be installed, make it available at build and run time
ENV R_VERSION_MAJOR 4
ENV R_VERSION_MINOR 2
ENV R_VERSION_BUGFIX 0
ENV R_VERSION $R_VERSION_MAJOR.$R_VERSION_MINOR.$R_VERSION_BUGFIX
ENV R_HOME=/usr/local/lib/R

WORKDIR /tmp
RUN wget https://cran.r-project.org/src/base/R-4/R-$R_VERSION.tar.gz
RUN tar zxvf R-$R_VERSION.tar.gz
# figure out how many cores we should use for compile, and call make -j to do multithreaded build
RUN ["/bin/bash", "-c", "x=$(cat /proc/cpuinfo | grep processor | wc -l) && let ncores=$x-1 && if (( ncores < 1 )); then let ncores=1; fi && echo \"export N_BUILD_CORES=\"$ncores >> /tmp/ncores.txt"]
RUN ["/bin/bash", "-c", "source /tmp/ncores.txt && cd R-$R_VERSION && ./configure -with-blas -with-lapack --enable-R-shlib && make -j $N_BUILD_CORES && make install"]

# Clean up downloaded files
WORKDIR /tmp
RUN rm -r /tmp/R-$R_VERSION*

# set CRAN repository snapshot for standard package installs
ENV R_REPOSITORY=https://cran.microsoft.com/snapshot/2022-04-25
RUN echo 'options(repos = c(CRAN = "'$R_REPOSITORY'"))' >> $R_HOME/etc/Rprofile.site

# enable multithreaded build for R packages
RUN echo 'options(Ncpus = max(c(parallel::detectCores()-1, 1)))' >> $R_HOME/etc/Rprofile.site

# tell R to use wget (devtools::install_github aimed at HTTPS connections had problems with libcurl)
RUN echo 'options("download.file.method" = "wget")' >> $R_HOME/etc/Rprofile.site
RUN Rscript -e "install.packages(c('curl', 'httr'))"


#------------------------------------------------------------------------------
# Install basic R packages
#------------------------------------------------------------------------------

# use the remotes package to manage installations
RUN Rscript -e "install.packages('remotes')"

# configure and install rJava
RUN R CMD javareconf
RUN Rscript -e "remotes::install_cran('rJava', type='source')"

# install devtools
RUN Rscript -e "remotes::install_cran('devtools')"