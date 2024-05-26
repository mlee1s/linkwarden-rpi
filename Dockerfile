FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Madrid
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt update && apt install -y wget chromium-browser curl make 

RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN apt install -y nodejs
RUN curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | tee /usr/share/keyrings/yarnkey.gpg >/dev/null
RUN echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | tee /etc/apt/sources.list.d/yarn.list
RUN apt update && apt install -y yarn 
RUN mkdir /data

WORKDIR /data

#############################################
#; Thx forabi for build binares (You can self build)
RUN mkdir prisma-binares
RUN wget https://github.com/forabi/prisma-rpi-builds/releases/download/5.7.0/libquery_engine_napi.so.node -P /data/prisma-binares/
RUN wget https://github.com/forabi/prisma-rpi-builds/releases/download/5.7.0/prisma-fmt -P /data/prisma-binares/
RUN wget https://github.com/forabi/prisma-rpi-builds/releases/download/5.7.0/query-engine -P /data/prisma-binares/
RUN wget https://github.com/forabi/prisma-rpi-builds/releases/download/5.7.0/schema-engine -P /data/prisma-binares/ 

ENV PRISMA_QUERY_ENGINE_LIBRARY=/data/prisma-binares/libquery_engine_napi.so.node
ENV PRISMA_FMT_BINARY=/data/prisma-binares/prisma-fmt
ENV PRISMA_QUERY_ENGINE_BINARY=/data/prisma-binares/query-engine
ENV PRISMA_SCHEMA_ENGINE_BINARY=/data/prisma-binares/schema-engine

RUN chmod +x /data/prisma-binares/*
#############################################
RUN npm install -g node-gyp

COPY ./package.json ./yarn.lock ./playwright.config.ts ./

# Increase timeout to pass github actions arm64 build
RUN --mount=type=cache,sharing=locked,target=/usr/local/share/.cache/yarn yarn install --network-timeout 10000000


RUN npx playwright install-deps && \
    apt-get clean && \
    yarn cache clean

COPY . .

RUN yarn prisma generate && \
    yarn build

# Install chrome and move to playwright
RUN apt install squashfs-tools snapd
RUN rm -rf /root/.cache/ms-playwright/chromium-1067/chrome-linux/
RUN cd /tmp; \
    snap download chromium; \
    mkdir chrome; \
    unsquashfs -f -d  ./chrome chromium_*.snap; \
    mv ./chrome/usr/lib/chromium-browser /root/.cache/ms-playwright/chromium-1067/chrome-linux; \
    cd /data

CMD yarn prisma migrate deploy && yarn start
