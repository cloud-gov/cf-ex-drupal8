FROM php:7.1-apache

# Set the DocumentRoot to /var/www/web instead of /var/www/html
RUN sed -i 's/html/web/g' /etc/apache2/sites-available/000-default.conf

RUN apt-get update &&\
    apt-get install -y \
      libbz2-dev libcurl4-openssl-dev libmcrypt-dev \
      libwebp-dev libjpeg-dev libpng-dev \
      git jq wget mysql-client &&\
    docker-php-ext-install bz2 curl gd mbstring mcrypt pdo pdo_mysql zip &&\
    apt-get autoremove -y &&\
    rm -rf /var/lib/apt/lists/* &&\
    rm -rf /var/cache/apt/*

RUN a2enmod rewrite proxy proxy_http

COPY ["install-composer.sh", "/tmp"]
RUN "/tmp/install-composer.sh"

# Add composer-installed libs to path
ENV PATH=/var/www/vendor/bin:$PATH
