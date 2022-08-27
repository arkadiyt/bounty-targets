FROM ruby:3.1.2

RUN apt update && apt-get install -y vim

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
