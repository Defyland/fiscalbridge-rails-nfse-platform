FROM ruby:3.4.6-slim

ARG INSTALL_BROWSER=false

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  git \
  libpq-dev \
  libyaml-dev \
  pkg-config \
  postgresql-client \
  && if [ "$INSTALL_BROWSER" = "true" ]; then apt-get install -y --no-install-recommends chromium chromium-driver; fi \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ARG BUNDLE_WITHOUT=development:test

ENV BUNDLE_WITHOUT=${BUNDLE_WITHOUT} \
    RAILS_ENV=production \
    TARGET_PORT=3000 \
    HTTP_PORT=80

COPY Gemfile Gemfile.lock ./
RUN gem install bundler -v 4.0.10
RUN bundle install

COPY . .

RUN mkdir -p storage tmp/pids log \
  && SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile

EXPOSE 80

CMD ["bundle", "exec", "thrust", "bundle", "exec", "puma", "-C", "config/puma.rb"]
