FROM debian:jessie

WORKDIR /root/

ADD scripts/bootstrap.sh scripts/bootstrap.sh
RUN apt-get update -yqq
RUN apt-get install -yqq make ruby git netcat nmap puppet-lint shellcheck

RUN gem install librarian-puppet

RUN scripts/bootstrap.sh

ADD vendor vendor/
ADD manifests manifests/
ADD modules modules/
ADD hiera hiera/
ADD hiera.yaml ./

ENV facter_env docker
ENV facter_fqdn faalserver.faalkaart.dev
ADD scripts/apply.sh scripts/
RUN scripts/apply.sh

ADD scripts/test.sh scripts/
RUN scripts/test.sh
