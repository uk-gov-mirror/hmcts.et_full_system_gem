FROM ruby:2.7.4-alpine
# Set correct environment variables.

ARG GEM_VERSION=>0
ARG user_id=1000
# Get latest rubygems
RUN gem update --system
RUN apk add --no-cache postgresql-dev libffi-dev tzdata gettext wget sudo libmcrypt-dev sqlite sqlite-dev nodejs yarn shared-mime-info git build-base curl bash openjdk11-jre
RUN addgroup app --gid 1000
RUN adduser -SD -u 1000 --shell /bin/bash --home /home/app app app
RUN chown -R app:app /usr/local/bundle
RUN mkdir -p /home/app/full_system; chown app:app /home/app/full_system
RUN wget https://gitlab.com/pdftk-java/pdftk/-/jobs/1507074845/artifacts/raw/build/libs/pdftk-all.jar
RUN mv pdftk-all.jar usr/lib/pdftk.jar
COPY docker/build/pdftk /usr/local/bin/pdftk
COPY docker/build/run /home/app/run

# Install gems and binstubs to run without bundler
RUN mkdir -p /home/app/system_gems/et_full_system && chmod 0777 /home/app/system_gems/et_full_system && chown -R app:app /home/app/system_gems

#RUN usermod -o -u $user_id app
#RUN groupmod -o -g $user_id app
WORKDIR /home/app/full_system
#RUN echo "app ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/user && chmod 0440 /etc/sudoers.d/user
USER app
RUN gem install dotenv bundler:1.17.3 invoker
CMD /home/app/run

#RUN bash --login -c "gem install bundler --version 1.17.3"

# Install gems required outside of any bundle.
#RUN bash --login -c "rvm use 2.7.4 && gem install dotenv et_fake_acas_server invoker && gem install et_full_system --version=$GEM_VERSION"

#WORKDIR /home/app/full_system

#RUN cd /home/app
#ENV HOME /home/app
