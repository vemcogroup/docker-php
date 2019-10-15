FROM php:fpm-alpine3.10 AS base

RUN set -ex \
  	&& apk update \
    && apk add --no-cache docker mysql-client libpng libzip icu libjpeg-turbo imagemagick openssh-client git rsync curl jq python py-pip make zip \
    && apk add --no-cache --virtual build-dependencies g++ autoconf icu-dev libzip-dev libpng-dev freetype-dev libpng-dev \
        libxml2-dev libjpeg-turbo-dev g++ imagemagick-dev \
    && docker-php-source extract \
    && pecl upgrade redis imagick \
    && docker-php-ext-enable redis imagick \
    && docker-php-source delete \
    && docker-php-ext-install -j$(nproc) pdo_mysql intl gd zip bcmath calendar pcntl exif opcache soap \
    && apk del build-dependencies \
    && rm -rf /tmp/*

COPY vemcount.ini /usr/local/etc/php/conf.d/vemcount.ini
COPY www.conf /usr/local/etc/php-fpm.d/www.conf

RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

RUN sed -i 's/access.log/;access.log/g' /usr/local/etc/php-fpm.d/docker.conf
RUN sed -i 's/;log_level = notice/log_level = warning/g' /usr/local/etc/php-fpm.conf

ENV TZ UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


## NEW LAYER
FROM base AS composer

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_MEMORY_LIMIT -1
ENV COMPOSER_HOME ./.composer
COPY --from=composer:1.9 /usr/bin/composer /usr/bin/composer
