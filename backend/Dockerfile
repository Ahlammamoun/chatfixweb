FROM php:8.2-fpm

RUN apt-get update && apt-get install -y \
    git unzip curl libzip-dev libicu-dev libonig-dev libxml2-dev \
    && docker-php-ext-install intl pdo pdo_mysql zip opcache

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/chatFix
COPY . .

RUN composer install --no-interaction --prefer-dist

# 👇 Correction importante : PHP-FPM écoute sur le port 9000 (et non un socket)
RUN sed -i 's|listen = /run/php/php-fpm.sock|listen = 9000|' /usr/local/etc/php-fpm.d/www.conf

EXPOSE 9000
CMD ["php-fpm"]
