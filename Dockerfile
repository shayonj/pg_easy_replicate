FROM ruby:3.1.4

ARG VERSION

RUN apt-get update && apt-get install postgresql-client -y
RUN pg_dump --version
RUN gem install pg_easy_replicate -v $VERSION
