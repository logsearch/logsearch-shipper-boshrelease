The goal of these conventions is to make it easier for releases to expose their logging and monitoring configurations, primarily for use within a logsearch+logsearch-shipper environment. In summary...

 0. Annotate your logs with details about how they're formatted.
 0. Include those details alongside your release version tarballs.
 0. Add hooks to your deployment processes to extract the configuration and ship them to your logsearch deployment.
 0. Deploy your actual release (colocated with logsearch-shipper).


## Release

These scripts expect the following conventions...

 * every log format MUST be named by `{release-name}-{job-name}-{log-name}-{version}`
 * every log format MUST be documented in `jobs/{job-name}/logsearch/logs/{log-name}-{version}/` where:
    * there MUST be `logstash-filters.conf` which SHOULD describe how to parse every line, and
    * there SHOULD be `elasticsearch-mappings.json` which SHOULD describe all the elasticsearch mapping for every extracted field, and
    * there SHOULD be `expected.testdata` listing sample log lines and their parsed values
 * if the log format changes or mappings were defined incorrectly, the version MUST be incremented


## Docker

All of these scripts can be compiled into a Docker image which is based on the current logstash version which logsearch uses.

    $ docker build -t dpb587/logsearch-shipper-release-utils .
    $ docker run -v "$RELEASE_DIR:/release" -t -i dpb587/logsearch-shipper-release-utils


## Concourse

There's a sample task you can use in your build pipelines called [`append-logsearch-config`](./ci/tasks/append-logsearch-config). It can be used to test and append a `logsearch-config` directory to the release tarballs which makes it easier to reference your configurations; for example...

    $ RELEASE_NAME=myrelease ; RELEASE_VERSION=20 ; RELEASE_URL=https://...
    $ RELEASE_FILE="${RELEASE_NAME}-${RELEASE_VERSION}.tgz"
    $ wget -nc -O "${RELEASE_FILE}" "${RELEASE_URL}"
    $ bosh upload release "${RELEASE_FILE}"
    $ tar -xzf "${RELEASE_FILE}" -C ~/deployments/logsearch/filters/ --strip-components=3 logsearch-config/logs/logstash-filters
    $ bosh -d ~/deployments/logsearch/bosh.yml deploy
    $ bosh deploy
