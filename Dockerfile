#
# R Container Image
# Author: Nathan Palmer
# Copyright: Harvard Medical School
#

FROM ubuntu:20.04

#------------------------------------------------------------------------------
# Basic initial system configuration
#------------------------------------------------------------------------------

USER root

# install standard Ubuntu Server packages
RUN yes | unminimize

# we're going to create a non-root user at runtime and give the user sudo
RUN apt-get update && \
	apt-get -y install sudo \
	&& echo "Set disable_coredump false" >> /etc/sudo.conf
	
# set locale info
RUN echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
	&& apt-get update && apt-get install -y locales \
	&& locale-gen en_US.utf8 \
	&& /usr/sbin/update-locale LANG=en_US.UTF-8
ENV LC_ALL en_US.UTF-8
ENV LANG en_US.UTF-8
ENV TZ=America/New_York

WORKDIR /tmp

#------------------------------------------------------------------------------
# Install system tools and libraries via apt
#------------------------------------------------------------------------------

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
	&& apt-get install \
		-y \
		ca-certificates \
		curl \
		less \
		libgomp1 \
		libpango-1.0-0 \
		libxt6 \
		libsm6 \
		make \
		texinfo \
		libtiff-dev \
		libpng-dev \
		libicu-dev \
		libpcre3 \
		libpcre3-dev \
		libbz2-dev \
		liblzma-dev \
		gcc \
		g++ \
		openjdk-8-jre \
		openjdk-8-jdk \
		gfortran \
		libreadline-dev \
		libx11-dev \
		libcurl4-openssl-dev \ 
		libssl-dev \
		libxml2-dev \
		wget \
		libtinfo5 \
		openssh-server \
		ssh \
		xterm \
		xauth \
		screen \
		tmux \
		git \
		libgit2-dev \
		nano \
		emacs \
		vim \
		man-db \
		zsh \
		unixodbc \
		unixodbc-dev \
		gnupg \
		krb5-user \
		python3-dev \
		python3 \ 
		python3-pip \
		alien \
		libaio1 \
		pkg-config \ 
		libkrb5-dev \
		unzip \
		cifs-utils \
		lsof \
		libnlopt-dev \
		libopenblas-openmp-dev \
		libpcre2-dev \
		systemd \
		libcairo2-dev \
	&& rm -rf /var/lib/apt/lists/*


#------------------------------------------------------------------------------
# Configure system tools
#------------------------------------------------------------------------------

# required for ssh and sshd	
RUN mkdir /var/run/sshd	

# configure X11
RUN sed -i "s/^.*X11Forwarding.*$/X11Forwarding yes/" /etc/ssh/sshd_config \
    && sed -i "s/^.*X11UseLocalhost.*$/X11UseLocalhost no/" /etc/ssh/sshd_config \
    && grep "^X11UseLocalhost" /etc/ssh/sshd_config || echo "X11UseLocalhost no" >> /etc/ssh/sshd_config	

# tell git to use the cache credential helper and set a 1 day-expiration
RUN git config --system credential.helper 'cache --timeout 86400'


#------------------------------------------------------------------------------
# Install and configure database connectivity components
#------------------------------------------------------------------------------

# install FreeTDS driver
WORKDIR /tmp
RUN wget ftp://ftp.freetds.org/pub/freetds/stable/freetds-1.1.40.tar.gz
RUN tar zxvf freetds-1.1.40.tar.gz
RUN cd freetds-1.1.40 && ./configure --enable-krb5 && make && make install
RUN rm -r /tmp/freetds*

# tell unixodbc where to find the FreeTDS driver shared object
RUN echo '\n\
[FreeTDS]\n\
Driver = /usr/local/lib/libtdsodbc.so \n\
' >> /etc/odbcinst.ini


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


#------------------------------------------------------------------------------
# Final odds and ends
#------------------------------------------------------------------------------

# allow modification of these locations so users can install R packages without warnings
RUN chmod -R 777 $R_HOME/library
RUN chmod -R 777 $R_HOME/doc/html/packages.html

# Create a mount point for host filesystem data
RUN mkdir /HostData

# enable password authedtication over SSH
RUN sed -i 's!^#PasswordAuthentication yes!PasswordAuthentication yes!' /etc/ssh/sshd_config
EXPOSE 22

# Copy startup script
RUN mkdir /startup
COPY startup.sh /startup/startup.sh
RUN chmod 700 /startup/startup.sh

CMD ["/startup/startup.sh"]
