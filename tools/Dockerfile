FROM debian:10
RUN dpkg --add-architecture i386
RUN apt-get update
RUN apt-get install -y wget wine wine32 make
RUN ln -s /usr/bin/wine /usr/local/bin/wine
COPY .wine /root/.wine
