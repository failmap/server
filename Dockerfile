FROM debian:jessie

WORKDIR /root/

ADD scripts/bootstrap.sh scripts/bootstrap.sh
RUN apt-get update -yqq
RUN apt-get install -yqq make ruby git netcat puppet-lint shellcheck build-essential libssl-dev
ADD https://github.com/rbsec/sslscan/archive/1.11.0-rbsec.tar.gz ./
RUN tar zxf 1.11.0-rbsec.tar.gz
WORKDIR sslscan-1.11.0-rbsec/
RUN make sslscan
RUN install sslscan /usr/local/bin/
WORKDIR /root/

RUN gem install librarian-puppet

RUN scripts/bootstrap.sh

ADD vendor vendor/
ADD manifests manifests/
ADD modules modules/
ADD hiera hiera/
ADD hiera.yaml ./

ENV facter_env docker
ENV facter_fqdn faalserver.faalkaart.test
ENV facter_ipaddress6 ::1
ADD scripts/apply.sh scripts/
RUN scripts/apply.sh

ADD scripts/docker_test.sh scripts/
ADD scripts/test.sh scripts/

RUN scripts/docker_test.sh
