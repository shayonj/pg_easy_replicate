FROM ruby:3.3.6-slim

ARG VERSION

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  wget \
  gnupg2 \
  lsb-release \
  build-essential \
  libpq-dev \
  && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-keyring.gpg && \
  echo "deb [signed-by=/usr/share/keyrings/postgresql-keyring.gpg] http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
  apt-get update && \
  apt-get install -y --no-install-recommends postgresql-client && \
  gem install pg_easy_replicate -v $VERSION && \
  apt-get remove -y wget gnupg2 lsb-release && \
  apt-get autoremove -y && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN pg_dump --version
