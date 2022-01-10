ARG TAG=${TAG}

FROM php:${TAG}-fpm-alpine AS base
ENV MUSL_LOCPATH /usr/share/i18n/locales/musl

RUN set -ex \
    && apk update \
    && apk add --no-cache yarn docker lz4 lz4-dev libevent-dev mysql-client libpng freetype libzip icu libjpeg-turbo openssh-client git rsync curl jq python3 py-pip make zip libpq \
    && apk add --no-cache --virtual build-dependencies autoconf icu-dev libzip-dev libpng-dev freetype-dev libpng-dev libxml2-dev libjpeg-turbo-dev g++ cmake musl-dev unixodbc-dev gcc gettext-dev libintl postgresql-dev \
    && docker-php-source extract \

    && wget https://atatus-artifacts.s3.amazonaws.com/atatus-php/downloads/atatus-php-1.13.0-d1-x64-musl.tar.gz -P /usr \
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

    && mkdir -p /tmp/phpredis \
        && curl -L https://pecl.php.net/get/redis | tar xvz -C /tmp/phpredis --strip 1 \
        && cd /tmp/phpredis \
        && phpize \
        && ./configure --enable-redis-lz4 --with-liblz4=/usr/lib/ \
        && make && make install \

    && docker-php-ext-configure pgsql -with-pgsql=/usr/local/pgsql \
    && docker-php-ext-configure gd --with-jpeg --with-freetype \
    && docker-php-ext-install -j$(nproc) pdo_mysql intl gd zip bcmath calendar pcntl exif opcache soap pgsql pdo_pgsql sockets \
    && pecl upgrade event-beta xdebug sqlsrv-5.9.0 pdo_sqlsrv-5.9.0 \

    && cd /tmp && curl -O https://download.microsoft.com/download/e/4/e/e4e67866-dffd-428c-aac7-8d28ddafb39b/msodbcsql17_17.7.2.1-1_amd64.apk \
    && yes | apk add --allow-untrusted msodbcsql17_17.7.2.1-1_amd64.apk \
    && rm -fr msodbcsql17_17.7.2.1-1_amd64.apk \

    && docker-php-ext-enable redis \
    && docker-php-ext-enable --ini-name zz-event.ini event \
    && docker-php-source delete \

    && pip install awscli \
    && curl -sLO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl \
    && mv kubectl /usr/bin/ \
    && chmod +x /usr/bin/kubectl \

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
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
