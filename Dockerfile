FROM ruby:3.2.0

RUN apt update && apt-get install -y vim cron

RUN curl -sOL https://cronitor.io/dl/linux_amd64.tar.gz && \
  tar xvf linux_amd64.tar.gz -C /usr/bin/

WORKDIR /app
COPY Gemfile Gemfile.lock ./
COPY config/cron /etc/cron.d/cron
RUN chown root:root /etc/cron.d/cron
RUN bundle install
COPY . .
