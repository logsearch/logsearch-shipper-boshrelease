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
define default configuration. By default, all `/var/vcap/sys/log/**/*.log` files are included. As an example, you could
add the following to your manifest to include the director name on all log messages:

    properties:
      logsearch:
        logs:
          _defaults: |
            ---
            "**/*.log":
              fields:
                bosh_director: "prod--aws--us-west-1"

The second configuration source is template-specific configuration files. When starting, the job will look for other
`/var/vcap/jobs/{template-name}/logsearch/logs.yml` files to load. This allows you to define default fields for all
logs involved with your job. By default, non-absolute paths are relative to `/var/vcap/sys/log`. As an example, if you
are using [nginx](http://nginx.org/) you might put the following in `/var/vcap/jobs/nginx/logsearch/logs.yml`:

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

 * `server` - the upstream server in the format of `host:port` (`string`, required)
 * `ssl_ca_certificate` - the upstream SSL certificate to use for authentication (`string`, optional)
 * `ssl_certificate` - a SSL certificate to use for authentication (`string`, optional)
 * `ssl_key` - a SSL key to use for authentication (`string`, optional)
 * `start_delay` - delay startup commands by this number of seconds (`integer`, optional)
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
`logsearch.metrics.monit.poll` property to `false`.

The third set of metrics can be created by individual job templates using the following conventions. First, metric
collectors should be a script which writes to `STDOUT` in the following simple format:

    {metric-name:string} {metric-value:number} {unix-timestamp:integer}

Each of the three values must be separated by a single space, and each tuple must end in a new line. The script runs in
an empty environment except for a `METRIC_FREQUENCY` indicating how frequently it should poll metrics (in seconds). The
script should be long-running, only exiting when it receives an `INT` signal.

Each metric collector should have its own directory inside `{job-dir}/logsearch/metric-collector` and the script should
be named `collector`. When the shipper process is starting up, it will automatically discover the metric collectors it
needs to run. As an example, take a look at the
[built-in metric collector](./jobs/logsearch-shipper/templates/logsearch/metric-collector/monit/collector) responsible
for generating the monit metrics mentioned above.

Here are some recommendations for naming metrics:

 * namespace them by the template name
 * use `.` to separate namespace levels
 * use the character range of `A-Za-z0-9._`


### Job Properties

There are several configurable properties (in the `logsearch.metrics` namespace):

 * `enabled` - Whether to enable metrics functionality (`boolean`, default `true`)
 * `frequency` - Check metrics every interval of this number of seconds (`integer`, default `300`)
 * `host.cpu` - Gather host CPU metrics (`boolean`, default `true`)
 * `host.disk` - Gather host disk metrics (`boolean`, default `true`)
 * `host.loadavg` - Gather host load average metrics (`boolean`, default `true`)
 * `host.memory` - Gather host memory metrics (`boolean`, default `true`)
 * `host.network` - Gather host network metrics (`boolean`, default `true`)
 * `host.processes` - Gather host process metrics (`boolean`, default `true`)
 * `host.swap` - Gather host swap metrics (`boolean`, default `true`)
 * `host.users` - Gather host user metrics (`boolean`, default `true`)
 * `monit.poll` - Gather monit process metrics (`boolean`, default `true`)


## Notes

If you dislike the built-in behaviors (log file selection and `bosh_*`/`stream` fields) and prefer to manage all your
own settings, you can disable them with the following:

    properties:
      logsearch:
        logs:
          _builtin_defaults: ~


## Open Source

[MIT License](./LICENSE)
