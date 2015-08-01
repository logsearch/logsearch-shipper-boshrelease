The goal of these conventions is to make it easier for releases to expose their logging and monitoring configurations, primarily for use within a logsearch+logsearch-shipper environment. In summary...

 0. Annotate your logs with details about how they're formatted.
 0. Include those details alongside your release version tarballs.
 0. Use hooks in your deployment processes to extract the configuration and update your logsearch deployment.

This stuff is an idea in progress...


## Release

These scripts use and expect the following conventions...

### Logs

For inspection...

 * every log format MUST be defined in `jobs/{job-name}/logsearch/logs/{log-reference-name}/` where:
    * the `{log-reference-name}` SHOULD be `{log-name}-{version}`
    * there SHOULD be `logstash-filters.conf` which SHOULD describe how to parse every line, and
    * there SHOULD be `elasticsearch-mappings.json` which SHOULD describe all the elasticsearch mappings for every extracted field, and
    * there SHOULD be `expected.testdata` listing sample log lines and their parsed values, and
    * there MAY be custom `*spec.rb` files containing more extensive tests
 * every log format MUST have a fully unique name to distinguish between releases and jobs with similar, but different formats
    * log formats SHOULD be named with the template `{release-name}-{job-name}-{log-name}-{version}`
    * log formats MAY use a custom name by writing it to `jobs/{job-name}/logsearch/logs/{log-reference-name}/name`
 * if the log format changes or mappings were defined incorrectly, versioning MUST be incremented

### Dashboards

For visualizing...

 * dashboards MUST be defined as job-specific, or deployment-specific in the following directories:
    * job-specific dashboards MUST be defined in `jobs/{job-name}/logsearch/dashboards/{dashboard-name}/`
    * deployment dashboards MUST be defined in `src/logsearch/dashboards/{dashboard-name}/`
 * the dashboard directories SHOULD be structured:
    * with a `README.md` file which:
       * MUST provide an brief abstract describing the dashboard
       * SHOULD be followed by helpful information about the dashboard for end users
    * with a `thumbnail.png` file providing a preview of the dashboard
    * at least one interface-specific file MUST exist which conforms to its respective dashboard configuration format
 * interface-specific dashboards MAY assume interpolation for the following variables which SHOULD be implemented by installation tools:
    * `director`
    * `deployment`
    * `job` (`{job_name}/{job_index}`)
    * `job_name`
    * `job_index`

### Monitors

For avoidance...


## Docker

All of these scripts can be compiled into a Docker image which is based on the current logstash version which logsearch uses.

    $ docker build -t dpb587/logsearch-shipper-release-utils .
    $ docker run -v "$RELEASE_DIR:/release" -t -i dpb587/logsearch-shipper-release-utils


## Concourse

There's a sample task you can use in your build pipelines called [`append-logsearch-config`](./ci/tasks/append-logsearch-config). It can be used to test and append a `logsearch-config` directory to the release tarballs which makes it easier to reference your configurations. For example...

    $ RELEASE_NAME=myrelease ; RELEASE_VERSION=20 ; RELEASE_URL=https://...
    $ RELEASE_FILE="${RELEASE_NAME}-${RELEASE_VERSION}.tgz"
    $ wget -nc -O "${RELEASE_FILE}" "${RELEASE_URL}"
    $ bosh upload release "${RELEASE_FILE}"
    $ tar -xzf "${RELEASE_FILE}" -C ~/deployments/logsearch/filters/ --strip-components=3 logsearch-config/logs/logstash-filters
    $ bosh -d ~/deployments/logsearch/bosh.yml deploy
    $ bosh deploy
