FROM dpb587/logsearch-logstash-dev:v19
ADD . /usr/local/logsearch-shipper-release-utils
ENTRYPOINT /usr/local/logsearch-shipper-release-utils/bin/entrypoint
ENV RELEASE_DIR release
WORKDIR /
VOLUME /release
