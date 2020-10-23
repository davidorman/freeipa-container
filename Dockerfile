# build slurm packages
FROM registry.centos.org/centos:7 AS builder
WORKDIR /root
RUN yum -y groupinstall "Development Tools"
RUN yum -y install epel-release
RUN yum -y install wget  munge-devel munge-libs readline-devel openssl-devel openssl pam-devel  perl-ExtUtils-MakeMaker  mariadb-server mariadb-devel munge
RUN wget https://download.schedmd.com/slurm/slurm-18.08.8.tar.bz2
RUN rpmbuild -ta slurm*.tar.bz2



# install slurm and munge before ipa stuff starts.
FROM registry.centos.org/centos:7
MAINTAINER David Orman

RUN groupadd -g 400 -r munge
RUN useradd munge -r -s /sbin/nologin -u 400 -g 400 -d /var/run/munge

RUN groupadd -g 401 slurm
RUN useradd slurm -u 401 -g 401 -s /sbin/nologin

RUN yum -y install epel-release
RUN yum -y install munge

COPY --from=builder  /root/rpmbuild/RPMS/x86_64/slurm* /root/
RUN yum -y localinstall /root/slurm*

RUN touch /etc/slurm/slurm.conf
RUN touch /etc/munge/munge.key
RUN chmod 400  /etc/munge/munge.key
RUN chown -R 400.400 /etc/munge

RUN echo -e '#!/bin/bash\n/bin/sleep infinity' > /usr/local/bin/startup.sh
RUN chmod 755 /usr/local/bin/startup.sh

# regular ipa stuff

RUN yum swap -y -- remove fakesystemd -- install systemd systemd-libs && yum clean all

# Install FreeIPA client
RUN yum install -y ipa-client dbus-python perl 'perl(Data::Dumper)' 'perl(Time::HiRes)' && yum clean all

ADD dbus.service /etc/systemd/system/dbus.service
RUN ln -sf dbus.service /etc/systemd/system/messagebus.service

ADD systemctl /usr/bin/systemctl
ADD ipa-client-configure-first /usr/sbin/ipa-client-configure-first

RUN chmod -v +x /usr/bin/systemctl /usr/sbin/ipa-client-configure-first

ENTRYPOINT /usr/sbin/ipa-client-configure-first
