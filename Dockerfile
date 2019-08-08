FROM alpine:edge as NODE

ENV NODE_VERSION 12.7.0
ENV YARN_VERSION 1.17.3

RUN addgroup -g 1000 node \
    && adduser -u 1000 -G node -s /bin/sh -D node \
    && apk add --no-cache \
        libstdc++ \
    && apk add --no-cache --virtual .build-deps \
        binutils-gold \
        curl \
        g++ \
        gcc \
        gnupg \
        libgcc \
        linux-headers \
        make \
        python \
  && for key in \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    FD3A5288F042B6850C66B31F09FE44734EB7990E \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    B9AE9905FFD7803F25714661B63B535A4C206CA9 \
    77984A986EBC2AA786BC0F66B01FBB92821C587A \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz" \
    && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
    && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
    && grep " node-v$NODE_VERSION.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && tar -xf "node-v$NODE_VERSION.tar.xz" \
    && cd "node-v$NODE_VERSION" \
    && ./configure \
    && make -j$(getconf _NPROCESSORS_ONLN) V= \
    && make install \
    && apk del .build-deps \
    && cd .. \
    && rm -Rf "node-v$NODE_VERSION" \
    && rm "node-v$NODE_VERSION.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt

RUN apk add --no-cache --virtual .build-deps-yarn curl gnupg tar \
  && for key in \
    6A010C5166006599AA17F08146C2130DFD2497F5 \
  ; do \
    gpg --batch --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys "$key" || \
    gpg --batch --keyserver hkp://ipv4.pool.sks-keyservers.net --recv-keys "$key" || \
    gpg --batch --keyserver hkp://pgp.mit.edu:80 --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz" \
  && curl -fsSLO --compressed "https://yarnpkg.com/downloads/$YARN_VERSION/yarn-v$YARN_VERSION.tar.gz.asc" \
  && gpg --batch --verify yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && mkdir -p /opt \
  && tar -xzf yarn-v$YARN_VERSION.tar.gz -C /opt/ \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarn /usr/local/bin/yarn \
  && ln -s /opt/yarn-v$YARN_VERSION/bin/yarnpkg /usr/local/bin/yarnpkg \
  && rm yarn-v$YARN_VERSION.tar.gz.asc yarn-v$YARN_VERSION.tar.gz \
  && apk del .build-deps-yarn

FROM NODE as ANDROID

ENV ANDROID_HOME /usr/local/android
ENV ANDROID_VERSION 27
ENV ANDROID_BUILD_TOOLS_VERSION 27.0.3

RUN mkdir "$ANDROID_HOME" && \
    mkdir /root/.android && \
    touch /root/.android/repositories.cfg && \
    apk add openjdk8 && \
    apk add curl

WORKDIR $ANDROID_HOME
RUN curl -fsSLO --compressed https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip && \
    unzip sdk-tools-linux-4333796.zip && \
    rm sdk-tools-linux-4333796.zip && \
    chmod -R +x $ANDROID_HOME/tools/bin

ENV PATH="${PATH}:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin:${ANDROID_HOME}/platform-tools"

RUN  sdkmanager --update
RUN yes | sdkmanager --licenses
RUN sdkmanager "platform-tools" --no_https
RUN sdkmanager "platforms;android-${ANDROID_VERSION}" \
               "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
               "extras;android;m2repository" \
               "extras;google;m2repository" \
               "extras;google;google_play_services" --no_https

RUN apk del openjdk8

FROM ANDROID as JAVA

ARG JDK_LOCATION

ENV JAVA_HOME /opt/java/current
ENV GLIBC_VERSION 2.29-r0

RUN apk upgrade --update && \
    apk add --update tar libstdc++ curl ca-certificates bash && \
    for pkg in glibc-${GLIBC_VERSION} glibc-bin-${GLIBC_VERSION} glibc-i18n-${GLIBC_VERSION}; do curl -sSL https://github.com/andyshinn/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/${pkg}.apk -o /tmp/${pkg}.apk; done && \
    apk add --allow-untrusted /tmp/*.apk && \
    rm -v /tmp/*.apk && \
    ( /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 C.UTF-8 || true ) && \
    echo "export LANG=C.UTF-8" > /etc/profile.d/locale.sh && \
    /usr/glibc-compat/sbin/ldconfig /lib /usr/glibc-compat/lib

ADD ${JDK_LOCATION} /tmp
RUN mkdir /opt/java && \ 
    tar -zxvf /tmp/jdk-8u221-linux-x64.tar.gz -C /opt/java && \
    ln -s /opt/java/jdk1.8.0_221 /opt/java/current && \
    ln -sfT /opt/java/current/bin/java /usr/bin/java && \
    ln -sfT /opt/java/current/bin/javac /usr/bin/javac && \
    ln -sfT /opt/java/current/bin/jar /usr/bin/jar && \
    rm -rf /tmp/jdk-8u221-linux-x64.tar.gz && \
    apk del glibc-i18n

ENV PATH ${JAVA_HOME}/bin:${PATH}

FROM JAVA as GRADLE

ENV GRADLE_VERSION 5.5.1
ENV GRADLE_HOME /opt/gradle
ENV PATH ${PATH}:${GRADLE_HOME}/bin
ENV GRADLE_USER_HOME /gradle

WORKDIR /opt
RUN mkdir ${GRADLE_USER_HOME} && \
    curl -fsSLO --compressed https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip && \
    unzip gradle-$GRADLE_VERSION-bin.zip && \
    rm -f gradle-$GRADLE_VERSION-bin.zip && \
    ln -s gradle-$GRADLE_VERSION gradle && \
    chmod +x ${GRADLE_HOME}/bin/gradle

FROM GRADLE as PYTHON

RUN apk add python2

FROM PYTHON as ANGULAR

RUN mkdir /home/workspace
WORKDIR /home/workspace

RUN npm install -g @angular/cli && \
    npm install -g cordova && \
    npm install -g ionic && \
    npm install -g node-gyp && \
    npm install -g npm-install-peers
