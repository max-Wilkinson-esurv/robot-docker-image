###########
# BUILDER #
###########

# pull official base image
FROM python:3.9.7-slim-buster as builder

# set work directory
WORKDIR /usr/src/app

# install core dependencies
RUN apt update && \
    apt-get upgrade -y && \
    apt install -y --no-install-recommends git curl gnupg2 gcc g++ libc-dev python3-dev unixodbc unixodbc-dev && \
    apt-get clean

# install Microsoft ODBC 17 dependencies
RUN curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
    curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql17 && \
    ACCEPT_EULA=Y apt-get install -y mssql-tools

ENV PATH $PATH:/opt/mssql-tools/bin

RUN apt-get install -y unixodbc-dev && \
    apt-get install -y libgssapi-krb5-2

# install chromedriver
RUN apt-get install -yqq unzip wget && \
    wget -O /tmp/chromedriver.zip http://chromedriver.storage.googleapis.com/`curl -sS chromedriver.storage.googleapis.com/LATEST_RELEASE`/chromedriver_linux64.zip && \
    unzip /tmp/chromedriver.zip chromedriver -d /usr/local/bin/ 

# get esurv repos
ARG GITHUB_ACCESS_TOKEN
RUN git clone -b develop --single-branch https://$GITHUB_ACCESS_TOKEN@github.com/esurv/esurv_db_manager.git
RUN git clone -b develop --single-branch https://$GITHUB_ACCESS_TOKEN@github.com/esurv/esurv_rpa.git

# install pip dependencies
RUN mkdir requirements && touch requirements/requirements.txt
RUN sed -e '$s/$/\n/' -s esurv_rpa/requirements.txt esurv_db_manager/requirements.txt > requirements/requirements.txt

RUN pip3 wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements/requirements.txt

#########
# FINAL #
#########

# pull official base image
FROM python:3.9.7-slim-buster

# create directory for the app user
WORKDIR /app

# install pip dependencies
COPY --from=builder /usr/src/app/wheels /wheels
COPY --from=builder /usr/src/app/requirements/requirements.txt requirements.txt
RUN pip3 install --no-cache /wheels/*

# install chrome
RUN apt-get update && apt-get install -y gnupg2 wget
RUN echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list && \
    apt-get install -y wget && \
    wget https://dl.google.com/linux/linux_signing_key.pub && \
    apt-key add linux_signing_key.pub && \
    apt update && \
    apt install -y google-chrome-stable

# copy chromedriver and set display port to avoid crash
COPY --from=builder /usr/local/bin/chromedriver /usr/local/bin/chromedriver
ENV DISPLAY=:99

# copy esurv folders
COPY --from=builder /usr/src/app/esurv_rpa/ esurv_rpa/
COPY --from=builder /usr/src/app/esurv_db_manager/ esurv_db_manager/