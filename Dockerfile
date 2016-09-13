FROM debian:jessie

WORKDIR /root/

ADD scripts/ scripts/
RUN scripts/bootstrap.sh

ADD Puppetfile.lock ./
ADD vendor vendor/
ADD manifests manifests/
ADD modules modules/
ADD hiera hiera/
ADD Makefile hiera.yaml ./

ENV facter_env docker
ENV facter_fqdn faalserver.faalkaart.dev
RUN scripts/apply.sh

RUN apt-get install -yqq netcat
ADD test.sh /
RUN /test.sh
