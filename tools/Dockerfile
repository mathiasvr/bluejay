FROM debian:10
RUN dpkg --add-architecture i386
RUN apt-get update
RUN apt-get install -y wget wine wine32 make
COPY .wine/user.reg /root/.wine/user.reg
COPY .wine/system.reg /root/.wine/system.reg
COPY .wine/drive_c/Keil_v5 /root/.wine/drive_c/Keil_v5
