FROM php:cli-alpine AS base

RUN set -ex \
  	&& apk update \
    && apk add --no-cache icu libpng freetype libzip libjpeg-turbo imagemagick docker mysql-client \
    && apk add --no-cache --virtual build-dependencies icu-dev libxml2-dev freetype-dev libzip-dev libpng-dev \
        libjpeg-turbo-dev g++ make autoconf imagemagick-dev \
    && docker-php-source extract \
    && pecl upgrade redis imagick \
    && docker-php-ext-enable redis imagick \
    && docker-php-source delete \
    && docker-php-ext-install -j$(nproc) pdo_mysql intl zip gd bcmath calendar pcntl exif \
    && apk del build-dependencies \
    && rm -rf /tmp/*

COPY vemcount.ini /usr/local/etc/php/conf.d/vemcount.ini

ENV TZ UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone


## NEW LAYER
FROM base AS composer

ENV COMPOSER_ALLOW_SUPERUSER 1
ENV COMPOSER_MEMORY_LIMIT -1
ENV COMPOSER_HOME ./.composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
