FROM fluent/fluentd:v0.14

RUN apk add --no-cache --update --virtual=build-dependencies ruby-dev build-base && \
  gem install fluent-plugin-mongo && \
  gem install fluent-plugin-elasticsearch && \
  apk del build-dependencies && \
  rm -rf /tmp/* /var/tmp/* /var/cache/apk/*

