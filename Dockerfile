FROM ruby:3.1.4

ARG VERSION

# TODO ensure pg_dump exists
RUN gem install pg_easy_replicate -v $VERSION
