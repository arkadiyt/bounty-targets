FROM ruby:3.1.2

WORKDIR /app
COPY Gemfile Gemfile.lock ./
RUN bundle install
