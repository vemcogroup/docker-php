FROM php:fpm-alpine3.9 AS base

RUN set -ex \
  	&& apk update \
    && apk add --no-cache docker mysql-client libpng libzip icu \
    && apk add --no-cache --virtual build-dependencies g++ make autoconf icu-dev libzip-dev libpng-dev \
    && docker-php-source extract \
    && pecl upgrade redis \
    && docker-php-ext-enable redis \
    && docker-php-source delete \
    && docker-php-ext-install -j$(nproc) pdo_mysql intl gd zip bcmath calendar pcntl exif opcache \
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
