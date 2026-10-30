ARG TAG=8.4

FROM php:${TAG}-fpm-trixie AS base
ENV TZ=UTC

COPY --from=node:24-trixie-slim /usr/local/bin/node /usr/local/bin/node
COPY --from=node:24-trixie-slim /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/npm

RUN --mount=type=bind,from=ghcr.io/php/pie:1.4.9-bin,source=/pie,target=/usr/local/bin/pie set -ex \
    && ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && apt-get update \
    && apt-get install -y --no-install-recommends awscli locales less docker-cli lz4 default-mysql-client openssh-client git rsync curl jq python3 make zip libstdc++6 tzdata libgssapi-krb5-2 libbrotli1 \
    && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libbrotli1)" ge 1.1.0-2+deb13u1 \
&& node -e 'const [major, minor, patch] = process.versions.node.split(".").map(Number); if (major !== 24 || minor < 22 || (minor === 22 && patch < 1)) throw new Error("Node 24.22.1 or newer is required");' \
&& sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen \
    && savedAptMark="$(apt-mark showmanual)" \
    && apt-get install -y --no-install-recommends $PHPIZE_DEPS automake libtool libcurl4-openssl-dev libssl-dev libicu-dev libzip-dev libfreetype6-dev libpng-dev libxml2-dev libjpeg62-turbo-dev cmake unixodbc-dev libpq-dev liblz4-dev libzstd-dev libevent-dev zlib1g-dev \
    && curl -fsSL https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb \
    && dpkg -i /tmp/packages-microsoft-prod.deb \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 \
    && rm /tmp/packages-microsoft-prod.deb \
    && docker-php-source extract \
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
    && docker-php-ext-configure pgsql --with-pgsql=/usr \
    && docker-php-ext-configure gd --with-jpeg --with-freetype \
\
    && PHP_VERSION="$(php -r 'echo PHP_VERSION;')" \
    && case "$PHP_VERSION" in \
      8.3.*) \
        docker-php-ext-configure ftp --with-openssl-dir=/usr \
        && docker-php-ext-install opcache ;; \
      8.4.*) \
        docker-php-ext-configure ftp --with-ftp-ssl \
        && docker-php-ext-install opcache ;; \
      *) \
        docker-php-ext-configure ftp --with-ftp-ssl ;; \
    esac \
\
    && docker-php-ext-install -j$(nproc) curl pdo_mysql intl gd zip bcmath calendar pcntl exif soap pgsql pdo_pgsql sockets ftp \
    && php -r '$features = curl_version()["feature_list"] ?? []; if (($features["NTLM"] ?? false) !== true) { fwrite(STDERR, "libcurl NTLM support is required\\n"); exit(1); }' \
    && git clone --depth=1 --branch 3.1.6 https://bitbucket.org/osmanov/pecl-event.git /tmp/php-event \
    && test "$(git -C /tmp/php-event rev-parse HEAD)" = 63cb86c2699591591321c45bfcd8e5074896e020 \
    && cd /tmp/php-event \
    && phpize \
    && ./configure --with-event-core --with-event-libevent-dir=/usr --with-event-openssl --with-event-extra --enable-event-sockets \
    && make -j"$(nproc)" && make install \
    && cd / && rm -rf /tmp/php-event \
    && for extension in xdebug/xdebug:3.5.3 microsoft/sqlsrv:5.13.3 microsoft/pdo_sqlsrv:5.13.3 pecl/pcov:1.0.12; do \
        pie install --no-interaction --skip-enable-extension --make-parallel-jobs="$(nproc)" "$extension" || exit 1; \
    done \
    && pie install --no-interaction --skip-enable-extension --make-parallel-jobs="$(nproc)" phpredis/phpredis:6.3.0 --enable-redis-lz4 --enable-redis-zstd --with-liblz4=/usr \
    && rm -rf /root/.pie /root/.cache/composer \
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
    && apt-mark auto '.*' > /dev/null \
    && apt-mark manual $savedAptMark msodbcsql18 packages-microsoft-prod \
    && find /usr/local /opt/microsoft -type f \( -executable -o -name '*.so*' \) -exec ldd '{}' ';' \
        | awk '/=>/ { so = $(NF-1); if (index(so, "/usr/local/") == 1) next; sub("^/(usr/)?", "", so); print "*" so }' \
        | sort -u \
        | xargs -r dpkg-query --search \
        | awk -F: '!/^diversion / { print $1 }' \
        | sort -u \
        | xargs -r apt-mark manual \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false \
    && rm -rf /var/lib/apt/lists/* /tmp/*

COPY vemcount.ini www.conf /usr/local/etc/php/conf.d/

RUN mv /usr/local/etc/php/conf.d/www.conf /usr/local/etc/php-fpm.d/www.conf \
    && mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini" \
    && sed -i 's/access.log/;access.log/g' /usr/local/etc/php-fpm.d/docker.conf \
    && sed -i 's/;log_level = notice/log_level = warning/g' /usr/local/etc/php-fpm.conf \
\
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && printf '\n[client-mariadb]\nskip-ssl-verify-server-cert\n' >> /etc/mysql/mariadb.conf.d/50-client.cnf

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
COPY --from=rancher/kubectl:v1.35.6 /bin/kubectl /usr/local/bin/kubectl

COPY --from=oven/bun:debian /usr/local/bin/bun /usr/local/bin/bun
