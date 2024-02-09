ARG RESTACK_PRODUCT_VERSION=2.8.0
FROM apache/airflow:${RESTACK_PRODUCT_VERSION}-python311
RUN mkdir -p dags && \
    mkdir -p config && \
    mkdir -p logs && \
    mkdir -p plugins


COPY --chown=airflow:root dags/ /opt/airflow/dags
COPY --chown=airflow:root config/ /opt/airflow/config
COPY --chown=airflow:root plugins/ /opt/airflow/plugins

USER root
ENV CRYPTOGRAPHY_DONT_BUILD_RUST=1
ENV DEBIAN_FRONTEND noninteractive

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138 0E98404D386FA1D9 DCC9EFBF77E11517 112695A0E562B32A 54404762BBB6E853
RUN apt-get update; apt-get -y install build-essential software-properties-common chromium-driver gnupg2  libnss3 vim libpq-dev git  wget xvfb
RUN apt-get update &&  apt-get -y install unzip
RUN apt-get update; apt-get -y install default-libmysqlclient-dev
RUN apt-get update; apt-get -y install gcc-11-base libgcc-11-dev libc6-dev gcc g++
RUN apt-get update; apt-get -y install chromium-driver gnupg2  libnss3
RUN apt-get update; apt-get -y install vim libpq-dev git rsync
#RUN apt-get update; apt-get -y install postgresql-14 postgresql-client-14 python3-tk libglib2.0-0 readline-common 
RUN apt-get update; apt-get -y install python3-tk libglib2.0-0 readline-common 
RUN apt-get update && apt-get -y install python-dev-is-python3 python3-dev libpython3-dev apt-utils python3-pip python3-setuptools  
#RUN apt-get update; apt-get -y install mariadb-client-core-10.5 mariadb-client-10.5 default-mysql-client
RUN apt-get update; apt-get remove --auto-remove python3-debian
RUN apt-get update; apt-get install -y --no-install-recommends freetds-bin krb5-user ldap-utils libsasl2-2 libsasl2-modules libssl3 locales  lsb-release sasl2-bin sqlite3 unixodbc
COPY ./sources.list /etc/apt/sources.list

ARG CHROMEDRIVER_DIR="/opt/chromedriver"
ARG CHROMEDRIVER_VERSION="108.0.5359.71"
ARG CHROME_VERSION="108.0.5359.124-1"
RUN wget --no-verbose -O /tmp/chrome.deb https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROME_VERSION}_amd64.deb \
  && apt install -y /tmp/chrome.deb \
  && rm /tmp/chrome.deb

RUN curl -sS -o /tmp/chromedriver_linux64.zip http://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip && \
    unzip -qq /tmp/chromedriver_linux64.zip -d ${CHROMEDRIVER_DIR} && \
    #rm -rf  /tmp/chromedriver_linux64.zip && \
    chmod +x ${CHROMEDRIVER_DIR}/chromedriver && \
    ln -fs ${CHROMEDRIVER_DIR}/chromedriver /usr/bin/chromedriver

COPY ./worker_start.sh /usr/local/bin
RUN usermod -u 1001 airflow
#RUN sed -i "/^# deb.*multiverse/ s/^# //" /etc/apt/sources.list
COPY ./unrar_5.5.8-1_amd64.deb .
RUN dpkg -i unrar_5.5.8-1_amd64.deb
COPY ./ta-lib/libta* /usr/local/lib/
RUN mkdir /usr/local/include/ta-lib
COPY ./ta-lib/*.h /usr/local/include/ta-lib

USER airflow
RUN pip install --upgrade pip
RUN pip uninstall torch --yes
COPY ./requirements-core.txt ./requirements.txt
# no-deps hack or try --use-deprecated-legacy-resolver
EXPOSE 8080
RUN cd /home/airflow
COPY ./celery_config.py .
RUN pip3 install ta-lib
RUN pip install "apache-airflow[celery]==2.8.1" --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-2.8.1/constraints-3.11.txt"
RUN pip3 install --upgrade ray[default,rllib]
RUN pip3 install -r ./requirements.txt
RUN pip install connexion[swagger-ui]
# bug fix for numpy deprecation of np.alen function replace with arr.shape[0]
COPY ./prg.py /home/airflow/.local/lib/python3.11/site-packages/prg/prg.py


COPY requirements.txt /
RUN pip install --no-cache-dir "apache-airflow==${AIRFLOW_VERSION}" -r /requirements.txt
