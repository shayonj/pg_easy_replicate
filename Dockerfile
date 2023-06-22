FROM ruby:3.0

ARG VERSION=0.1.2

RUN gem install pg_easy_replicate -v $VERSION
