FROM ruby:3.1.4

ARG VERSION

RUN gem install pg_easy_replicate -v $VERSION
