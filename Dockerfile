FROM alpine:3.14 AS php
RUN rm -rf /usr/lib/* /usr/include/* &&\
apk add --no-cache curl  wget \
php php7-fpm php7-bcmath php7-cli php7-ctype php7-curl php7-dom php7-fpm php7-gd php7-iconv php7-intl php7-json php7-mbstring php7-mcrypt php7-openssl php7-pdo_mysql php7-phar php7-session php7-simplexml php7-soap php7-tokenizer php7-xml php7-xmlwriter php7-xsl php7-zip php7-zlib php7-sockets php7-sodium php7-fileinfo php7-xmlreader erlang &&\
mkdir -p /usr/share/rabbitmq-server && wget https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.8.35/rabbitmq-server-generic-unix-latest-toolchain-3.8.35.tar.xz -O - | tar xJz -C /usr/share/rabbitmq-server --strip-components=1 &&\
echo -e "export PATH=$PATH:/usr/share/rabbitmq-server/sbin/" >> /etc/profile &&\
#PHP-COMPOSER
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer --version=1.10.22

#redis
ARG REDIS_VERSION="6.0.4"
ARG REDIS_DOWNLOAD_URL="http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz"

RUN apk update && apk upgrade \
    && apk add --update --no-cache --virtual build-deps gcc make linux-headers musl-dev tar \
    && wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL" \
    && mkdir -p /usr/src/redis \
    && tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1 \
    && rm redis.tar.gz \
    && make -C /usr/src/redis install redis-cli /usr/bin \
    && rm -r /usr/src/redis \
    && apk del build-deps \
    && rm -rf /var/cache/apk/*



FROM alpine:3.12 AS build
RUN rm -rf /usr/lib/* /usr/include/*
COPY --from=php /etc/passwd /etc/group /etc/
COPY --from=php /usr/local/bin/composer /usr/local/bin/composer
COPY --from=php /var/log/php7/ /var/log/php7/
COPY --from=php /root/.composer/ /root/.composer/
COPY --from=php /usr/bin/php /usr/bin/
COPY --from=php /usr/local/bin/redis-server /usr/local/bin/redis-sentinel /usr/local/bin/redis-cli /usr/local/bin/redis-check-rdb /usr/local/bin/redis-check-aof /usr/local/bin/redis-benchmark /usr/bin/erl /usr/bin/erlc /usr/bin/
COPY --from=php /usr/lib/ /usr/lib/
COPY --from=php /usr/sbin/php-fpm7 /usr/sbin/php-fpm7
COPY --from=php /etc/php7/ /etc/php7/
COPY --from=php /etc/profile /etc/profile
COPY --from=php /usr/share/rabbitmq-server /usr/share/rabbitmq-server
RUN apk add --no-cache \
curl \
#mysql \
mysql \
mysql-client \
shadow \
sudo \
openssh \
bash \
axel \
wget \
openjdk8-jre-base &&\
mkdir -p /etc/nginx/ &&\
#SQL
addgroup mysql mysql &&\
find /usr/share/mariadb/* -maxdepth 1 ! -name "english" -type d -not -path '.' -exec rm -rf {} + &&\

#SSH
mkdir -p ~/.ssh &&\
addgroup -S magento && adduser -S -G magento magento -D -s /bin/ash &&\
echo  "magento ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers &&\
echo 'magento ALL=(ALL:ALL) /usr/sbin/nginx, /usr/bin/php, /usr/bin/mysql, /usr/bin/composer, /usr/sbin/crond' | EDITOR='tee -a' visudo &&\
echo -e "magento\nmagento" | passwd magento &&\
ssh-keygen -A &&\
ssh-keygen -t rsa -f ~/.ssh/id_rsa -N '' &&\
#addgroup -S www-data &&\
adduser -S -D -u 82 -s /sbin/nologin -h /var/www -G www-data www-data &&\
usermod -a -G www-data magento &&\
apk add nginx &&\




#ELASTIC
axel https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.9.0-linux-x86_64.tar.gz && tar -xf  elasticsearch-7.9.0-linux-x86_64.tar.gz -C /usr/share/ \
&& echo -e "export ES_JAVA_HOME=/usr/lib/jvm/java-8-openjdk\nexport JAVA_HOME=/usr/lib/jvm/java-8-openjdk" >> /etc/profile \
&& mv /usr/share/elasticsearch-7.9.0* /usr/share/elasticsearch \
&& mkdir /usr/share/elasticsearch/data \
&& mkdir /usr/share/elasticsearch/config/scripts \
&& rm -rf /var/cache/apk/* /usr/share/elasticsearch/jdk /usr/share/elasticsearch/modules/x-pack-ml \
&& adduser -D -u 1000 -h /usr/share/elasticsearch elasticsearch
COPY elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml

#MULTISTAGE
FROM alpine:3.12
EXPOSE 6379 9200 9300 3306 80 9000 22 5672 15672
COPY --from=build /etc/sudoers /etc/profile /etc/passwd /etc/group /etc/shadow /etc/
COPY --from=build /etc/php7/ /etc/php7/
COPY --from=build /etc/nginx/ /etc/nginx/ 
COPY --from=build /etc/ssh/ /etc/ssh/
COPY --from=build /etc/profile /etc/profile
COPY --from=build /usr/sbin/php-fpm7 /usr/sbin/nginx /usr/sbin/sshd /usr/sbin/visudo /usr/sbin/
COPY --from=build /usr/lib/ /usr/lib/
COPY --from=build /var/lib/nginx/ /var/lib/nginx/
COPY --from=build /usr/share/mariadb/ /usr/share/mariadb/
COPY --from=build /usr/share/elasticsearch/ /usr/share/elasticsearch/
COPY --from=build /usr/share/rabbitmq-server /usr/share/rabbitmq-server
COPY --from=build /usr/bin/redis-server /usr/bin/redis-sentinel /usr/bin/redis-cli /usr/bin/redis-check-rdb /usr/bin/redis-check-aof /usr/bin/redis-benchmark /usr/bin/erl /usr/bin/erlc /usr/bin/php /usr/bin/curl /usr/bin/mysql /usr/bin/mysqldump /usr/bin/mysqld /usr/bin/mysql_install_db /usr/bin/my_print_defaults /usr/bin/resolveip /usr/bin/
COPY --from=build /bin/bash /bin/bash
COPY --from=build /root/.ssh/ /root/.ssh/
COPY --from=build /root/.composer/ /root/.composer/
#COPY --from=build /usr/local/sbin/varnishd /usr/local/sbin/varnishd
COPY --from=build /usr/local/bin/composer /usr/local/bin/composer
#COPY --from=build /usr/local/lib/varnish /usr/local/lib/varnish
COPY --from=build /var/log/php7/ /var/log/php7/
COPY --from=build /home/magento /home/magento
#varnish 
RUN wget http://varnish-cache.org/downloads/varnish-6.4.0.tgz \
&& gunzip -c varnish-6.4.0.tgz | tar xvf - \
&& apk --update --no-cache add -q \
   autoconf \
   automake \
   build-base \
   ca-certificates \
   cpio \
   gzip \
   libedit-dev \
   libtool \
   libunwind-dev \
   linux-headers \
   pcre2-dev \
   py-docutils \
   py3-sphinx \
   tar \
   pcre-dev \
&& cd /varnish-6.4.0 && sh autogen.sh \
&& sh configure --with-unwind \
&& make -j "$(nproc)" \
&& make install -j "$(nproc)" \
&& cd / && mkdir /etc/varnish

COPY redis.conf /etc/redis.conf
COPY nginx.conf /etc/nginx/
COPY auth.json /root/.composer/auth.json
COPY elasticsearch.yml /usr/share/elasticsearch/config/elasticsearch.yml
COPY default.conf /etc/nginx/conf.d/default.conf
COPY php.ini /etc/php7/php.ini
COPY www.conf /etc/php7/php-fpm.d/
COPY default.vcl /etc/varnish/
COPY script.sh /
COPY startup.sh /startup.sh

ENTRYPOINT ["/startup.sh"]
