FROM ruby:3.0

ARG VERSION=0.2.0

RUN gem install pg_online_schema_change -v $VERSION