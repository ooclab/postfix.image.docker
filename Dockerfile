From ubuntu:latest
MAINTAINER gwind <lijian@ooclab.com>

# Set noninteractive mode for apt-get
ENV DEBIAN_FRONTEND noninteractive

# Update & Install package here for cache
#RUN sed -i -e 's@archive.ubuntu.com@cn.archive.ubuntu.com@' /etc/apt/sources.list \
RUN apt-get update -y && apt-get dist-upgrade -y \
        && apt-get -y install apt-utils rsyslog \
                postfix sasl2-bin libsasl2-modules \
                opendkim opendkim-tools \
        && apt-get clean \
        && rm -rf /var/lib/apt/lists/*
# opendkim
# https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-dkim-with-postfix-on-debian-wheezy

# Add files
RUN mkdir -pv /opt/bin/ \
    && mkdir -pv /etc/opendkim/keys

COPY assets/build_opendkim_keys.sh /opt/bin/build_opendkim_keys.sh
COPY assets/build_tls_keys.sh /opt/bin/build_tls_keys.sh
COPY assets/start.sh /opt/bin/start.sh

RUN chmod 755 /opt/bin/build_opendkim_keys.sh \
    && chmod 755 /opt/bin/build_tls_keys.sh \
    && chmod 755 /opt/bin/start.sh

# Run
CMD ["/opt/bin/start.sh"]
