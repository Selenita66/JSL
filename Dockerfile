# ====================================================================
# CEOapp Enterprise Dockerfile - PHP-FPM 8.2 Alpine ARM64 Optimized
# Multi-stage build for production-ready enterprise deployment
# ====================================================================

# 🏗️ Build Stage - Extensions and Dependencies
FROM php:8.2-fpm-alpine3.19 AS builder

# Build arguments
ARG PHP_VERSION=8.2
ARG BUILD_ENV=production
ARG TARGETPLATFORM=linux/arm64

# Labels for enterprise tracking
LABEL maintainer="CEOapp Enterprise Team"
LABEL version="1.0.0"
LABEL description="CEOapp Enterprise PHP-FPM 8.2 Alpine ARM64 Optimized"
LABEL architecture="arm64"
LABEL php.version="${PHP_VERSION}"

# Install build dependencies for ARM64
RUN apk add --no-cache --virtual .build-deps \
    autoconf \
    g++ \
    gcc \
    libc-dev \
    make \
    pkgconf \
    re2c \
    # Image processing
    freetype-dev \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxpm-dev \
    # Database
    mariadb-dev \
    postgresql-dev \
    sqlite-dev \
    # Compression
    bzip2-dev \
    libzip-dev \
    zlib-dev \
    # XML/XSLT
    libxml2-dev \
    libxslt-dev \
    # Security
    libsodium-dev \
    argon2-dev \
    # Networking
    curl-dev \
    openssl-dev \
    # Memory
    libmemcached-dev \
    # Other
    oniguruma-dev \
    readline-dev \
    gettext-dev \
    icu-dev

# Configure and install PHP extensions optimized for ARM64
RUN docker-php-ext-configure gd \
    --with-freetype \
    --with-jpeg \
    --with-webp \
    --with-xpm \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure zip \
    && docker-php-ext-configure pdo_mysql --with-pdo-mysql=mysqlnd \
    && docker-php-ext-configure mysqli --with-mysqli=mysqlnd

# Install PHP extensions in optimal order for caching
RUN docker-php-ext-install -j$(nproc) \
    # Core extensions
    opcache \
    # Database
    pdo \
    pdo_mysql \
    pdo_pgsql \
    pdo_sqlite \
    mysqli \
    # Image processing
    gd \
    exif \
    # Compression
    zip \
    bz2 \
    # XML/JSON
    xml \
    xmlreader \
    xmlwriter \
    xsl \
    # String processing
    mbstring \
    iconv \
    gettext \
    # Internationalization
    intl \
    # Security
    sodium \
    # Math
    bcmath \
    # System
    pcntl \
    posix \
    shmop \
    sysvmsg \
    sysvsem \
    sysvshm \
    # Sockets
    sockets

# Install PECL extensions for enterprise features
RUN pecl channel-update pecl.php.net \
    && pecl install \
    redis-6.0.2 \
    memcached-3.2.0 \
    xdebug-3.3.1 \
    apcu-5.1.23 \
    && docker-php-ext-enable redis memcached apcu

# 🚀 Production Stage - Optimized Runtime
FROM php:8.2-fpm-alpine3.19 AS production

# Copy build arguments
ARG BUILD_ENV=production
ARG PHP_VERSION=8.2

# Labels
LABEL maintainer="CEOapp Enterprise Team"
LABEL version="1.0.0"
LABEL stage="production"

# Install runtime dependencies only
RUN apk add --no-cache \
    # System utilities
    bash \
    curl \
    wget \
    ca-certificates \
    tzdata \
    # Image processing runtime
    freetype \
    libjpeg-turbo \
    libpng \
    libwebp \
    libxpm \
    # Database clients
    mariadb-client \
    postgresql-client \
    sqlite \
    # Compression
    bzip2 \
    libzip \
    # XML/XSLT runtime
    libxml2 \
    libxslt \
    # Security
    libsodium \
    # Memory
    libmemcached \
    # Other runtime
    oniguruma \
    gettext \
    icu \
    # Process management
    supervisor \
    # Monitoring
    htop \
    # Networking
    bind-tools \
    # File operations
    rsync \
    # Log rotation
    logrotate

# Copy PHP extensions from builder
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

# Create application user and group for security
RUN addgroup -g 1000 -S ceoapp \
    && adduser -u 1000 -S ceoapp -G ceoapp -s /bin/bash -h /var/www/html

# Create necessary directories with proper permissions
RUN mkdir -p \
    /var/www/html \
    /var/www/html/logs \
    /var/www/html/uploads \
    /var/www/html/cache \
    /var/www/html/sessions \
    /var/www/html/database \
    /run/php \
    /var/log/php \
    && chown -R ceoapp:ceoapp /var/www/html \
    && chown -R ceoapp:ceoapp /run/php \
    && chown -R ceoapp:ceoapp /var/log/php \
    && chmod -R 755 /var/www/html \
    && chmod -R 775 /var/www/html/logs \
    && chmod -R 775 /var/www/html/uploads \
    && chmod -R 775 /var/www/html/cache \
    && chmod -R 775 /var/www/html/sessions \
    && chmod -R 775 /var/www/html/database

# Install Composer for dependency management
COPY --from=composer:2.7 /usr/bin/composer /usr/bin/composer
RUN chmod +x /usr/bin/composer

# Copy configuration files
COPY php/php.ini /usr/local/etc/php/php.ini
COPY php/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY php/www.conf /usr/local/etc/php-fpm.d/www.conf

# Copy supervisor configuration
COPY supervisor/supervisord.conf /etc/supervisord.conf

# Copy health check script
COPY scripts/php-fpm-healthcheck /usr/local/bin/php-fpm-healthcheck
RUN chmod +x /usr/local/bin/php-fpm-healthcheck

# Copy entrypoint script
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Enterprise security hardening
RUN # Remove unnecessary packages and clean cache
    rm -rf /var/cache/apk/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/* \
    # Secure file permissions
    && find /usr/local/etc -type f -exec chmod 644 {} \; \
    && find /usr/local/etc -type d -exec chmod 755 {} \; \
    # Remove setuid/setgid bits for security
    && find /usr -type f -perm +6000 -exec chmod a-s {} \; \
    # Create secure tmp directory
    && mkdir -p /tmp/php-sessions \
    && chown ceoapp:ceoapp /tmp/php-sessions \
    && chmod 700 /tmp/php-sessions

# Set environment variables for production
ENV PHP_INI_DIR=/usr/local/etc/php
ENV PHP_FPM_USER=ceoapp
ENV PHP_FPM_GROUP=ceoapp
ENV PATH="/var/www/html/vendor/bin:${PATH}"

# Expose PHP-FPM port
EXPOSE 9000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD php-fpm-healthcheck || exit 1

# Set working directory
WORKDIR /var/www/html

# Switch to application user for security
USER ceoapp

# Use custom entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command
CMD ["php-fpm", "-F"]

# 🧪 Development Stage (Optional)
FROM production AS development

USER root

# Install development tools
RUN apk add --no-cache \
    git \
    vim \
    nano \
    strace \
    tcpdump \
    && docker-php-ext-enable xdebug

# Development PHP configuration
COPY php/php-dev.ini /usr/local/etc/php/conf.d/99-dev.ini

# Install additional development dependencies
RUN composer global require --no-interaction \
    phpunit/phpunit \
    squizlabs/php_codesniffer \
    phpstan/phpstan \
    && composer clear-cache

USER ceoapp

# 🔒 Security Stage (Optional)
FROM production AS security-scan

USER root

# Install security scanning tools
RUN apk add --no-cache \
    nmap \
    openssl \
    && composer global require --no-interaction \
    roave/security-advisories:dev-latest \
    && composer clear-cache

USER ceoapp