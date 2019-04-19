FROM phusion/passenger-customizable:0.9.34
# Set correct environment variables.
ENV HOME /root
ARG APP_UID

# Use baseimage-docker's init process.
CMD ["/sbin/my_init"]

# If you're using the 'customizable' variant, you need to explicitly opt-in
# for features.
#
# N.B. these images are based on https://github.com/phusion/baseimage-docker,
# so anything it provides is also automatically on board in the images below
# (e.g. older versions of Ruby, Node, Python).
#
# Uncomment the features you want:
#
#   Ruby support

# The following 2 lines are temporary - see https://github.com/phusion/passenger-docker/issues/234
# Try to remove and build from scratch maybe after january 2019
RUN curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
RUN curl -sSL https://rvm.io/mpapis.asc -o /pd_build/ruby_support/mpapis-pubkey.asc
#RUN /pd_build/ruby-2.0.*.sh
#RUN /pd_build/ruby-2.1.*.sh
#RUN /pd_build/ruby-2.2.*.sh
#RUN /pd_build/ruby-2.3.*.sh
#RUN /pd_build/ruby-2.4.*.sh
RUN /pd_build/ruby-2.5.*.sh
#RUN /pd_build/jruby-9.1.*.sh
#   Python support.
#RUN /pd_build/python.sh
#   Node.js and Meteor standalone support.
#   (not needed if you already have the above Ruby support)
#RUN /pd_build/nodejs.sh

# Get latest rubygems
RUN bash --login -c "rvm --default use 2.5.1"
RUN gem update --system

# ...put your own build instructions here...
RUN apt-get update && apt-get -y install pdftk tzdata postgresql gettext-base wget sudo libmcrypt-dev mcrypt

RUN /pd_build/nodejs.sh

# Enable the Redis service.
RUN rm -f /etc/service/redis/down

# Install forego (for Procfile running)
RUN bash -lc "wget https://bin.equinox.io/c/ekMN3bCZFUn/forego-stable-linux-amd64.deb && apt install ./forego-stable-linux-amd64.deb && rm ./forego-stable-linux-amd64.deb"

# Install traefik (For front end reverse proxy)
RUN bash -lc "wget https://github.com/containous/traefik/releases/download/v1.7.10/traefik_linux-amd64 && mv ./traefik_linux-amd64 /usr/bin/traefik && chmod +x /usr/bin/traefik"

# Install minio
RUN bash -lc "cd /usr/local/bin && wget https://dl.minio.io/server/minio/release/linux-amd64/minio && chmod +x minio"

# Install azurite
RUN bash -lc "npm install -g azurite"

# Install Mailhog
RUN bash -lc "cd /usr/local/bin && wget https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64 -O mailhog && chmod +x mailhog"

RUN mkdir /etc/service/s3
COPY ./docker/s3.sh /etc/service/s3/run
RUN chmod +x /etc/service/s3/run

RUN mkdir /etc/service/azure_storage
COPY ./docker/azure_storage.sh /etc/service/azure_storage/run
RUN chmod +x /etc/service/azure_storage/run

RUN mkdir /etc/service/smtp
COPY ./docker/smtp.sh /etc/service/smtp/run
RUN chmod +x /etc/service/smtp/run

# Install gems and binstubs to run without bundler
RUN mkdir -p /home/app/dummy_app/vendor/gems/et_full_system && chown -R app /home/app/dummy_app

# Create the minio_data directory for the minio server
RUN mkdir -p /home/app/minio_data; chown app:app /home/app/minio_data; chmod 0777 /home/app/minio_data

# Create the azure_storage_data directory for the azure storage server
RUN mkdir -p /home/app/azure_storage_data; chown app:app /home/app/azure_storage_data; chmod 0777 /home/app/azure_storage_data

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN mkdir -p /home/app/full_system; chown app:app /home/app/full_system
WORKDIR /home/app/full_system
RUN echo "app ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/user && chmod 0440 /etc/sudoers.d/user
RUN usermod -u $APP_UID app
USER app



RUN bash --login -c "rvm --default use 2.5.1"
RUN bash --login -c "gem install bundler --version=1.17.3"

# Bundle install the gem itself to include its dependencies defined in the Gemfile (which ar github so must be done like this)
COPY . /home/app/dummy_app/vendor/gems/et_full_system
WORKDIR /home/app/dummy_app
RUN bash --login -c  "git init"
RUN bash --login -c "echo -e \"source 'https://rubygems.org'\ngem 'et_full_system', path: 'vendor/gems/et_full_system'\" > Gemfile"
RUN bash --login -c "rvm use && bundle install --binstubs"


WORKDIR /home/app/full_system


RUN cd /home/app
ENV HOME /home/app
