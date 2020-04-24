FROM golang:alpine as builder

RUN set -x \
# use tuna mirrors
    && sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories \
    && apk update\
	&& apk upgrade\
	&& apk add --no-cache \
	gcc \
    libc-dev \
	perl-dev \
	git \
	cmake \
	make \
	bash \
    alpine-sdk \
    findutils \
	build-base \
	libunwind-dev \
	linux-headers \
	&& mkdir -p /usr/local/src \
	&& git clone --depth=1 https://gitee.com/koalarong/boringssl.git /usr/local/src/boringssl \
	&& cd /usr/local/src/boringssl \
	&& mkdir build && cd build && cmake .. \
	&& make && cd ../ \
	&& mkdir -p .openssl/lib && cd .openssl && ln -s ../include . && cd ../ \
	&& cp build/crypto/libcrypto.a build/ssl/libssl.a .openssl/lib


FROM alpine:latest as nginx

LABEL maintainer="NGINX Docker Maintainers <docker-maint@nginx.com>"

ENV NGINX_VERSION 1.18.0
ENV MOD_PAGESPEED_TAG v1.13.35.2
ENV NGX_PAGESPEED_TAG v1.13.35.2-stable

RUN set -x \
# use tuna mirrors
    && sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories \
    && apk update\
	&& apk upgrade\
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
	&& apk add --no-cache --virtual .build-deps \
		git \
		gcc \
        libc-dev \
        make \
		cmake \
        pcre-dev \
        zlib-dev \
        linux-headers \
        libxslt-dev \
		libunwind-dev \
        gd-dev \
        geoip-dev \
        perl-dev \
		musl-dev \
		musl-utils \
        libedit-dev \
        mercurial \
        bash \
        alpine-sdk \
        findutils \
		build-base \
		wget \
	&& curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& mkdir -p /usr/local/src \
	&& tar -zxC /usr/local/src -f nginx.tar.gz \
	&& rm nginx.tar.gz
COPY --from=builder /usr/local/src/boringssl /usr/local/src/boringssl
RUN set -x \
	&& git clone --depth=1 --recurse-submodules https://gitee.com/koalarong/ngx_brotli.git /usr/local/src/ngx_brotli\
	# && git clone --depth=1  https://gitee.com/koalarong/ngx_brotli.git /usr/local/src/ngx_brotli\
	&& cd /usr/local/src \
	# && wget https://github.com/gperftools/gperftools/releases/download/gperftools-2.7.90/gperftools-2.7.90.tar.gz \
	# && tar -zxf gperftools-2.7.90.tar.gz \
	# && cd gperftools-2.7.90 \
	# && ./configure && make -j$(getconf _NPROCESSORS_ONLN) && make install \
	# && echo '/usr/local/lib' > /etc/ld.so.conf.d/local_lib.conf && ldconfig \
	# && mkdir -p /tmp/tcmalloc \
	# && chmod 777 /tmp/tcmalloc \
	# make nginx
	&& cd /usr/local/src/nginx-$NGINX_VERSION \
	&& ./configure \
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--user=nginx \
		--group=nginx \
		--with-compat \
		--with-file-aio \
		--with-threads \
		--with-http_addition_module \
		--with-http_auth_request_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_mp4_module \
		--with-http_random_index_module \
		--with-http_realip_module \
		--with-http_secure_link_module \
		--with-http_slice_module \
		--with-http_ssl_module \
		--with-http_stub_status_module \
		--with-http_sub_module \
		--with-http_v2_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-stream \
		--with-stream_realip_module \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module\
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-stream_geoip_module=dynamic \
		--with-pcre-jit \
		--with-openssl=/usr/local/src/boringssl/ \
		# –-with-google_perftools_module \
		# --with-ld-opt="-Wl,-z,relro,--start-group -lapr-1 -laprutil-1 -licudata -licuuc -lpng -lturbojpeg -ljpeg"\
		--with-ld-opt=-Wl,--as-needed \
		--with-cc-opt='-Os -fomit-frame-pointer' \
		--add-module=/usr/local/src/ngx_brotli \
	&& touch /usr/local/src/boringssl/.openssl/include/openssl/ssl.h \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& rm -rf /usr/local/src \
	\
	# Bring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/ \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --no-cache --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/ \
	\
	# Bring in tzdata so users could set the timezones through the environment
	# variables
	&& apk add --no-cache tzdata \
	\
	# forward request and error logs to docker log collector
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
	&& mkdir -p /var/cache/nginx/client_temp \
	&& nginx -t \
	&& nginx -V 

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx.vh.default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]