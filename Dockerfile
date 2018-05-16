FROM ruby:2.5.1

# throw errors if Gemfile has been modified since Gemfile.lock
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app

COPY . /usr/src/app

RUN bundle install --quiet
EXPOSE 3000
CMD ["tubes"]
