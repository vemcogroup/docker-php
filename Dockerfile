ARG TAG=8.4

FROM php:${TAG}-fpm-alpine AS base
ARG CURL_VERSION=8.14.1
ENV MUSL_LOCPATH=/usr/share/i18n/locales/musl \
    TZ=UTC

RUN set -ex \
    && apk add --no-cache aws-cli musl-locales icu icu-data-full less yarn libintl docker lz4 lz4-dev zstd-dev libevent-dev mysql-client libpng freetype libzip libjpeg-turbo openssh-client git rsync curl jq python3 make zip libpq \
    && apk add --no-cache --virtual build-dependencies autoconf curl-dev openssl-dev icu-dev libzip-dev freetype-dev libpng-dev libxml2-dev libjpeg-turbo-dev g++ cmake musl-dev unixodbc-dev gcc gettext-dev postgresql-dev linux-headers \
    && docker-php-source extract \
    && cd /tmp \
    && curl -fsSLO "https://curl.se/download/curl-${CURL_VERSION}.tar.gz" \
    && tar -xzf "curl-${CURL_VERSION}.tar.gz" \
    && cd "curl-${CURL_VERSION}" \
    && ./configure \
        --prefix=/usr/local \
        --disable-static \
        --enable-shared \
        --enable-ntlm \
        --with-openssl \
        --with-zlib \
    && make -j"$(nproc)" \
    && make install \
    && cd / \
    && rm -rf "/tmp/curl-${CURL_VERSION}" "/tmp/curl-${CURL_VERSION}.tar.gz" \
    && export PATH="/usr/local/bin:${PATH}" \
        PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:${PKG_CONFIG_PATH:-}" \
        CPPFLAGS="-I/usr/local/include" \
        LDFLAGS="-L/usr/local/lib" \
\
#    && arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/x64/) \
#    && wget https://s3.amazonaws.com/atatus-artifacts/atatus-php/downloads/atatus-php-1.17.1-${arch}-musl.tar.gz -P /usr \
#    && cd /usr && tar -xzf atatus-php-*-musl.tar.gz \
#    && cd atatus-php-*-musl \
#    && sh install.sh && cd /usr && rm -fr atatus* \
#    && sed -i "s/extension=\"atatus.so\"/; extension=\"atatus.so\"/g" /usr/local/etc/php/conf.d/atatus.ini \
#    && sed -i "s/atatus.framework = \"\"/atatus.framework = \"Laravel\"/g" /usr/local/etc/php/conf.d/atatus.ini \
#    && sed -i "s/laravel.enable_queues = false/laravel.enable.queues = true/g" /usr/local/etc/php/conf.d/atatus.ini \
#    && sed -i "s/atatus.sql.capture = \"normalized\"/atatus.sql.capture = \"raw\"/g" /usr/local/etc/php/conf.d/atatus.ini \
#\
    && docker-php-ext-configure pgsql --with-pgsql=/usr/local/pgsql \
    && docker-php-ext-configure gd --with-jpeg --with-freetype \
\
    && PHP_VERSION="$(php -r 'echo PHP_VERSION;')"; \
    case "$PHP_VERSION" in \
      8.3.*) \
        docker-php-ext-configure ftp --with-openssl-dir=/usr \
        && docker-php-ext-install opcache & ;; \
      8.4.*) \
        docker-php-ext-configure ftp --with-ftp-ssl \
        && docker-php-ext-install opcache & ;; \
      *) \
        docker-php-ext-configure ftp --with-ftp-ssl ;; \
    esac \
\
    && docker-php-ext-install -j$(nproc) curl pdo_mysql intl gd zip bcmath calendar pcntl exif soap pgsql pdo_pgsql sockets ftp \
    && php -r '$features = curl_version()["feature_list"] ?? []; if (($features["NTLM"] ?? false) !== true) { fwrite(STDERR, "libcurl NTLM support is required\\n"); exit(1); }' \
    && pecl upgrade event xdebug sqlsrv pdo_sqlsrv pcov \
\
    && arch=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) \
    && mssql_driver=msodbcsql18_18.6.1.1-1_${arch}.apk \
    && cd /tmp && curl -O "https://download.microsoft.com/download/9dcab408-e0d4-4571-a81a-5a0951e3445f/${mssql_driver}" \
    && yes | apk add --allow-untrusted ${mssql_driver} \
    && rm -fr ${mssql_driver} \
    && pecl download redis \
    && tar -xzf redis-*.tgz && cd redis-* \
    && phpize \
    && ./configure --enable-redis-lz4=yes --enable-redis-zstd=yes --with-liblz4=/usr/lib/ \
    && make -j"$(nproc)" && make install \
    && cd / && rm -rf /redis-* /usr/local/lib/php/doc/redis \
    \
    && git clone --recursive --depth=1 https://github.com/kjdev/php-ext-lz4.git /tmp/php-ext-lz4 \
    && cd /tmp/php-ext-lz4 \
    && phpize \
    && ./configure --with-lz4-includedir=/usr \
    && make -j"$(nproc)" \
    && make install \
    && docker-php-ext-enable lz4 \
    && cd / \
    && rm -rf /tmp/php-ext-lz4 \
    \
    && docker-php-ext-enable redis \
    && docker-php-ext-enable --ini-name zz-event.ini event \
    && docker-php-source delete \
\
    && apk del build-dependencies \
    && rm -rf /tmp/*

COPY vemcount.ini www.conf /usr/local/etc/php/conf.d/

RUN mv /usr/local/etc/php/conf.d/www.conf /usr/local/etc/php-fpm.d/www.conf \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && sed -i 's/access.log/;access.log/g' /usr/local/etc/php-fpm.d/docker.conf \
    && sed -i 's/;log_level = notice/log_level = warning/g' /usr/local/etc/php-fpm.conf \
\
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && echo -e "\n\n[client-mariadb]\ndisable-ssl-verify-server-cert" >> /etc/my.cnf

## NEW LAYER
FROM base AS composer

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_MEMORY_LIMIT=-1 \
    COMPOSER_HOME=./.composer

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# NEW LAYER
FROM composer AS docker
COPY --from=docker/buildx-bin:latest /buildx /usr/libexec/docker/cli-plugins/docker-buildx

# NEW LAYER
FROM docker AS kubectl
COPY --from=rancher/kubectl:v1.34.5 /bin/kubectl /usr/local/bin/kubectl

COPY --from=oven/bun:alpine /usr/local/bin/bun /usr/local/bin/bun
