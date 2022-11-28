FROM ruby:3.1.2

RUN apt update && apt-get install -y vim cron

WORKDIR /app
COPY Gemfile Gemfile.lock ./
COPY config/cron /etc/cron.d/cron
RUN chown root:root /etc/cron.d/cron
RUN bundle install
COPY . .