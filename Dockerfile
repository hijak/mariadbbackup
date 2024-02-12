FROM mariadb

RUN apt update && apt upgrade -y && apt install pigz python3-pip wget -y
RUN pip3 install awscli yq
ADD ./backup.sh /usr/bin/backup
RUN chmod +x /usr/bin/backup

CMD ["/usr/bin/backup"]
