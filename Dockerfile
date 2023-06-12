ARG TAG=${TAG}

FROM php:${TAG}-fpm-alpine3.17 AS base
ENV MUSL_LOCPATH /usr/share/i18n/locales/musl \
    TZ UTC

RUN set -ex \
    && apk update \
    && apk add --no-cache icu icu-data-full less yarn libintl docker lz4 lz4-dev libevent-dev mysql-client libpng freetype libzip libjpeg-turbo openssh-client git rsync curl jq python3 py-pip make zip libpq \
    && apk add --no-cache --virtual build-dependencies autoconf icu-dev libzip-dev libpng-dev freetype-dev libpng-dev libxml2-dev libjpeg-turbo-dev g++ cmake musl-dev unixodbc-dev gcc gettext-dev postgresql-dev linux-headers \
    && docker-php-source extract \

    && arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/x64/) \
    && wget https://s3.amazonaws.com/atatus-artifacts/atatus-php/downloads/atatus-php-1.15.0-${arch}-musl.tar.gz -P /usr \
    && cd /usr && tar -xzf atatus-php-*-musl.tar.gz \
    && cd atatus-php-*-musl \
    && sh install.sh && cd /usr && rm -fr atatus* \
    && sed -i "s/extension=\"atatus.so\"/; extension=\"atatus.so\"/g" /usr/local/etc/php/conf.d/atatus.ini \
    && sed -i "s/atatus.framework = \"\"/atatus.framework = \"Laravel\"/g" /usr/local/etc/php/conf.d/atatus.ini \
    && sed -i "s/laravel.enable_queues = false/laravel.enable.queues = true/g" /usr/local/etc/php/conf.d/atatus.ini \
    && sed -i "s/atatus.sql.capture = \"normalized\"/atatus.sql.capture = \"raw\"/g" /usr/local/etc/php/conf.d/atatus.ini \

    && cd /tmp && wget https://gitlab.com/rilian-la-te/musl-locales/-/archive/master/musl-locales-master.zip \
        && unzip musl-locales-master.zip \
        && cd musl-locales-master \
        && cmake -DLOCALE_PROFILE=OFF -D CMAKE_INSTALL_PREFIX:PATH=/usr . && make && make install \
        && cd .. && rm -r musl-locales-master \
\
    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-configure gd --with-jpeg --with-freetype \
    && docker-php-ext-install -j$(nproc) pdo_mysql intl gd zip bcmath calendar pcntl exif opcache soap pgsql pdo_pgsql sockets \
    && pecl upgrade redis event-beta xdebug sqlsrv-5.11.0 pdo_sqlsrv-5.11.0 \
\
    && cd /tmp && curl -O "https://download.microsoft.com/download/1/f/f/1fffb537-26ab-4947-a46a-7a45c27f6f77/msodbcsql18_18.2.1.1-1_amd64.apk" \
    && yes | apk add --allow-untrusted msodbcsql18_18.2.1.1-1_amd64.apk \
    && rm -fr msodbcsql18_18.2.1.1-1_amd64.apk \
\
    && docker-php-ext-enable redis \
    && docker-php-ext-enable --ini-name zz-event.ini event \
    && docker-php-source delete \
\
    && pip install awscli \
\
    && apk del build-dependencies \
    && rm -rf /tmp/*

COPY vemcount.ini www.conf /usr/local/etc/php/conf.d/

RUN mv /usr/local/etc/php/conf.d/www.conf /usr/local/etc/php-fpm.d/www.conf \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && sed -i 's/access.log/;access.log/g' /usr/local/etc/php-fpm.d/docker.conf \
    && sed -i 's/;log_level = notice/log_level = warning/g' /usr/local/etc/php-fpm.conf \
\
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

## NEW LAYER
FROM base AS composer

ENV COMPOSER_ALLOW_SUPERUSER 1 \
    COMPOSER_MEMORY_LIMIT -1 \
    COMPOSER_HOME ./.composer

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# NEW LAYER
FROM composer AS docker
COPY --from=docker/buildx-bin:latest /buildx /usr/libexec/docker/cli-plugins/docker-buildx

# NEW LAYER
FROM docker AS kubectl
COPY --from=rancher/kubectl:v1.26.2 /bin/kubectl /usr/bin/kubectl
