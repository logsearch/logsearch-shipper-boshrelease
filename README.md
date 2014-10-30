A [BOSH](http://docs.cloudfoundry.org/bosh/) release to help centralize the logs and metrics of your deployments.

Use this in conjunction with your own [logsearch](https://github.com/logsearch/logsearch-boshrelease) deployment.


---


## Usage

Upload the latest version to your director...

    $ bosh upload release https://logsearch-shipper-boshrelease.s3.amazonaws.com/release/latest.tgz

Update your deployment manifest to add the release, add the templates, and add your logsearch properties...

    releases:
      ...snip...
      - name: "logsearch-shipper"
        version: "latest"
    jobs:
      - name: "nginx"
        templates:
          ...snip...
          - release: "logsearch-shipper"
            name: "logsearch-shipper"
    properties:
      ...snip...
      logsearch:
        logs:
          server: "192.0.2.1:5514"

Ensure your logsearch deployment includes the parser rule for the metrics that logsearch-shipper sends:

    if [@type] == "metric" {
        grok {
            match => [ "@message", "%{NOTSPACE:name} %{NUMBER:value:float} %{INT:timestamp}" ]
            tag_on_failure => [ "fail/metric" ]
            add_tag => [ "metric" ]
            remove_tag => "raw"
            remove_field => [ "@message" ]
        }

        if "metric" in [tags] {
            date {
                match => [ "timestamp", "UNIX" ]
                remove_field => "timestamp"
            }
        }
    }

Deploy your changes...

    $ bosh deploy

And now all `/var/vcap/sys/log/**/*.log` log messages will be forwarded to logsearch, including fields about the
deployment, job, and template. Continue reading to learn more about how you can customize and improve the default
forwarding behaviors.


## Logs

Logs are configured with [YAML](http://www.yaml.org/) documents from several different sources. The YAML document
currently uses the following format:

    files:
      {path-to-file}:
        fields:
          {key1}: {value1}

The first configuration source is through manifest properties. You can use the `logsearch.logs._defaults` property to
define default log files and fields (by default, all `/var/vcap/sys/log/**/*.log` files are included and non-absolute
paths are relative to `/var/vcap/sys/log`). As an example, you could add the following to your manifest to tag every
log message with a configuration version:

    properties:
      logsearch:
        logs:
          _defaults: |
            ---
            "**/*.log":
              fields:
                manifest_version: "b5816e7fb0"

The second configuration source is template-specific configuration files. When starting, the job will look for other
`/var/vcap/jobs/{template-name}/logsearch/logs.yml` files to load. This allows you to define default fields for all
logs involved with your job. As an example, if you are using [nginx](http://nginx.org/) you might put the following in
`/var/vcap/jobs/nginx/logsearch/logs.yml`:

    files:
      "nginx/access.log":
        fields:
          type: "nginx_access"
      "nginx/error.log":
        fields:
          type: "nginx_error"

The third configuration source is overrides. If you are using an upstream release and need to change some fields they
specify, you can use the `logsearch.logs._overrides` property. As an example, if your filters rely on a different type
name for nginx logs, you might put the following in your manifest:

    files:
      "nginx/access.log":
        fields:
          type: "nginx_ouraccess"

There are several keywords you can use for dynamic interpolation in field values:

 * `{{director}}` - the director name (as configured by `logsearch.logs.director`)
 * `{{deployment}}` - the deployment name (e.g. `wordpress`)
 * `{{index}}` - the index of the job hosting the processes (e.g. `1`)
 * `{{job}}` - the name of the job hosting the processes (e.g. `webserver`)
 * `{{file_path}}` - the raw path of the file (e.g. `/var/vcap/sys/log/nginx/access.log`)
 * `{{file_template}}` - a guess of the template generating the log (e.g. `nginx`)

As an example, the job [automatically adds](./jobs/logsearch-shipper/spec) several fields to log messages:

    files:
      "**/*.log":
        fields:
          bosh_deployment: "{{deployment}}"
          bosh_job: "{{job}}/{{index}}"
          bosh_template: "{{file_template}}"
      "**/*.stdout.log":
        fields:
          stream: "stdout"
      "**/*.stderr.log":
        fields:
          stream: "stderr"

If a field value is empty (empty string or null), it is removed from the field map before being forwarded.

You can exclude a log file by specifying the path and using a null value. Once a log file has been excluded from
forwarding, it cannot be re-included. As an example, the log shipper
[excludes its own log files](./jobs/logsearch-shipper/templates/logsearch/logs.yml) with the following:

    files:
      "logsearch-shipper/logs.*.log": ~

Configuration files and their fields are processed in the following order (you should generally avoid setting the
`_builtin_*` properties since they're internally managed by the release):

 * property `logsearch.logs._builtin_defaults`
 * property `logsearch.logs._defaults`
 * files `/var/vcap/jobs/*/logsearch/logs.yml`
 * property `logsearch.logs._overrides`


### Job Properties

There are several configurable properties (in the `logsearch.logs` namespace):

 * `director` - the name of the BOSH director (not dynamically accessible; `string`, default `default`)
 * `enabled` - whether to enable log forwarding functionality (`boolean`, default `true`)
 * `server` - the upstream server in the format of `host:port` (`string`, required)
 * `ssl_ca_certificate` - the upstream SSL certificate to use for authentication (`string`, optional)
 * `ssl_certificate` - a SSL certificate to use for authentication (`string`, optional)
 * `ssl_key` - a SSL key to use for authentication (`string`, optional)
 * `start_delay` - delay startup commands by this number of seconds to help catch newly-created logs (`integer`, default `60`)
 * `transport` - transport to use with upstream server (tcp|udp) (`string`, default `tcp`)
 * `_defaults` - default log forwarding YAML configuration applied to all forwarders (`string`, optional)
 * `_overrides` - override template configuration applied to all forwarded files (`string`, optional)


## Metrics

By default, metrics are collected every 5 minutes, but you can adjust it with the `logsearch.metrics.frequency`
property. As an example, if you wanted to check once a minute, you could use the following:

    properties:
      logsearch:
        metrics:
          frequency: 60

If you prefer to completely disable this functionality, you can set `logsearch.metrics.enabled` to `false`.

Internally, metrics are treated as log file messages, so they use the same configuration documented in the Logs
section. This means the measurements will have several fields added, according to your defaults (e.g. `bosh_deployment`
and `bosh_job`). By default, metrics are also set with a `type` field set to `metric`.

Metrics are collected from several sources. The first set of metrics are enabled by default and come from the host:

 * `cpu` - idle, interrupt, nice, soft IRQ, steal, system, user, and wait (by core)
 * `disk` - merges, bytes, operations, and time (by read, write; by disk); disk space used, free, and reserved (by disk)
 * `loadavg` - short, mid, and long-term
 * `memory` - buffered, cached, free and used bytes
 * `network` - errors, bytes, and packets (by received, transmitted; by interface)
 * `processes` - blocked, paging, running, sleeping, stopped, and zombie states; fork rate
 * `swap` - cached, free, and used; I/O in and out
 * `users` - logged in

You can optionally disable those metrics by setting the respective `logsearch.metrics.host.{source}` property to
`false` (e.g. `logsearch.metrics.host.cpu: false`). These metrics are all named with a `host.` prefix.

A second set of metrics are automatically generated from the monit-managed processes and they include the following
(per process):

 * `children` - number of child processes
 * `cpu` - CPU usage of the parent and child processes
 * `memory` - memory (in bytes) of the parent and child processes
 * `status` - process status (0 = active, 1 = inactive, 2 = ignored)
 * `uptime` - seconds the process has been running

These metrics are enabled by default and are prefixed with `monit.` and the monit process name (e.g.
`monit.logsearch-logs.uptime`). If you prefer to disable these metrics, you can set the
`logsearch.metrics.monit` property to `false`.

The third set of metrics are generated by custom scripts. These scripts are run in an empty environment except for a
`METRIC_FREQUENCY` indicating how frequently it should collect metrics (in seconds). They should run indefinitely until
they receive an `INT` signal and they must output measurements to `STDOUT` in the following simple format:

    {metric-name:string} {metric-value:number} {unix-timestamp:integer}

By default, this release will auto-discover collector scripts which are named with the following convention:
`/var/vcap/jobs/{template-name}/logsearch/metric-collector/{collector-name}/collector`. Alternatively, you can use YAML
configuration documents using the following format to specify scripts in different locations, or override individual
settings per collector:

    collectors:
      {name}:
        enabled: {boolean=true}
        frequency: {integer=logsearch.metrics.frequency}
        exec: {string} # script executable path

Auto-discovered scripts are named using `{template-name}--{collector-name}`. As an example, take a look at the
[built-in `metrics.yml` file](./jobs/logsearch-shipper/templates/logsearch/metrics.yml.erb) which controls whether the
[built-in monit collector](./jobs/logsearch-shipper/templates/logsearch/metric-collector/monit/collector) (mentioned
earlier) is run.

Similar to configuring logs, you may store YAML configuration in the following locations:

 * property `logsearch.metrics._defaults`
 * files `/var/vcap/jobs/*/logsearch/metrics.yml`
 * property `logsearch.metrics._overrides`


#### Metric Names

When you're writing metric collectors, you should follow these recommendations for metric names:

 * use namespaces, starting with the template and collector name
 * use `.` to separate namespace levels
 * use the character range of `a-z0-9._`


### Job Properties

There are several configurable properties (in the `logsearch.metrics` namespace):

 * `enabled` - whether to enable metrics functionality (`boolean`, default `true`)
 * `frequency` - check metrics every interval of this number of seconds (`integer`, default `300`)
 * `host.cpu` - gather host CPU metrics (`boolean`, default `true`)
 * `host.disk` - gather host disk metrics (`boolean`, default `true`)
 * `host.loadavg` - gather host load average metrics (`boolean`, default `true`)
 * `host.memory` - gather host memory metrics (`boolean`, default `true`)
 * `host.network` - gather host network metrics (`boolean`, default `true`)
 * `host.processes` - gather host process metrics (`boolean`, default `true`)
 * `host.swap` - gather host swap metrics (`boolean`, default `true`)
 * `host.users` - gather host user metrics (`boolean`, default `true`)
 * `monit` - gather monit process metrics (`boolean`, default `true`)


## Additional Notes

### Disable Logging Defaults

If you dislike the built-in behaviors (log file selection and `bosh_*`/`stream` fields) and prefer to manage all your
own settings, you can disable them with the following:

    properties:
      logsearch:
        logs:
          _builtin_defaults: ~


### Kibana Dashboards

You'll find several sample Kibana dashboards in `share/kibana-dashboards`. Many of them use query arguments, so the
easiest way to import them into kibana is with an elasticsearch curl request like the following:

    $ cat share/kibana-dashboards/metrics-job.json \
      | jq -c -r '{ "title" : "metrics-job", "group" : "guest", "user" : "guest", "dashboard" : (. | tostring) }' \
      | curl -XPUT -d @- http://logsearch/kibana-int/dashboard/metrics-job

The following sample dashboards are available:

 * [`metrics-job.json`](./share/kibana-dashboards/metrics-job.json) - shows standard host metrics (e.g. load, network,
   disks). It requires the `director`, `deployment`, and `job` query arguments.


## Open Source

[Apache License 2.0](./LICENSE)
