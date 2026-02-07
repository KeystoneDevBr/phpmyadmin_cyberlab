FROM phpmyadmin:latest AS builder

# Install OpenSSL and Cron to generate self-signed certificates.
RUN apt-get update && apt-get install -y openssl cron;


# Self-signed certificate generation
RUN openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -subj '/C=AA/ST=AA/L=AA/O=AA/OU=AA/CN=aaa.com.br/emailAddress=aaa@gmail.com' \
    -addext "subjectAltName=DNS:aaa.com.br" \
    -keyout /etc/ssl/private/apache2-selfsigned.key \
    -out /etc/ssl/certs/apache2-selfsigned.crt

FROM phpmyadmin:5.2.3-apache@sha256:ce66eefd046088d7a7cc7f2595da08e2896e099b6613e5008e04243fcefc31f6 AS production

# Copy the self-signed certificates from the builder stage to the production stage
COPY --from=builder /etc/ssl/private/apache2-selfsigned.key /etc/ssl/private/server.key
COPY --from=builder /etc/ssl/certs/apache2-selfsigned.crt /etc/ssl/certs/server.crt

# Timezone Ajust to America/Sao_Paulo (GMT-3)
ARG TZ=America/Sao_Paulo
ENV TZ=${TZ}

RUN ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone

# Allow to connect to any host, not only the one defined in PMA_HOST
ENV PMA_ARBITRARY=1

# Disable SSL to avoid connection issues with MySQL/MariaDB
ENV PMA_SSL=0

# Disable SSL verification to avoid connection issues with MySQL/MariaDB
ENV PMA_SSL_VERIFY=0

# Define localhost database connection as default
ARG DB_HOST="127.0.0.1"
ARG DB_PORT=3306
ENV PMA_HOST=${DB_HOST}
ENV PMA_PORT=${DB_PORT}

RUN echo '<?php $cfg["blowfish_secret"] = "d8F!3kL2pZr9SxAq0M#VYcW@eR6H7JQ1";' > /etc/phpmyadmin/config.secret.inc.php

# Allow to connect to any host, not only the one defined in PMA_HOST and PMA_PORT
RUN echo '<?php $cfg["AllowArbitraryServer"] = true;' > /etc/phpmyadmin/config.auth.inc.php

ADD ./config/default-ssl.conf /etc/apache2/sites-available/default-ssl.conf

RUN a2enmod ssl && a2dissite 000-default.conf && a2ensite default-ssl.conf

EXPOSE 443