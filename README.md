A flexible and reusable [BOSH](http://docs.cloudfoundry.org/bosh/) release to forward logs from jobs to an upstream log
server using various forwarding protocols.


---


## Usage

Upload the latest version to your director...

    $ bosh upload release https://dpb587-bosh-release-plugin-logs.s3.amazonaws.com/release/latest.tgz

Update your deployment manifest to add the release, add the forwarding template to your jobs, and add the forwarding
properties...

    releases:
      ...snip...
      - name: "plugin-logs"
        version: "latest"
    jobs:
      - name: "nginx"
        templates:
          ...snip...
          - release: "plugin-logs"
            name: "plugin-logs-syslog"
    properties:
      ...snip...
      plugin:
        logs:
          syslog:
            server: "192.0.2.1:5514"

Deploy your changes...

    $ bosh deploy

And now all `/var/vcap/sys/log/**/*.log` log messages will be forwarded to your logging server, including fields about
the deployment, job, and template. Continue reading to learn more about how you can customize and improve the default
forwarding behaviors.


## Log Forwarding

Log forwarding is configured with [YAML](http://www.yaml.org/) documents from several different sources. The YAML
document currently uses the following format:

    ---
    files:
      {path-to-file}:
        fields:
          {key1}: {value1}

The first configuration source is through manifest properties. You can use the `plugin.logs._defaults` property to
define global configuration (applied to all forwarders), or you can use the equivalent forwarder-specific property
(e.g. `plugin.logs.syslog._defaults`). By default, the plugin automatically includes all
`/var/vcap/sys/log/**/*.log` files and excludes the forwarder's own log files (to avoid recursion). As an example, you
could add the following to your manifest to include the director name on all log messages:

    properties:
      plugin:
        logs:
          _defaults: |
            ---
            "**/*.log":
              fields:
                bosh_director: "prod--aws--us-west-1"

The second configuration source is template-specific configuration files. When starting, forwarders will look for
`/var/vcap/jobs/{job-name}/plugin/logs/config.yml` files to load. This allows you to define default fields for all
logs involved with your job. By default, non-absolute paths are relative to `/var/vcap/sys/log`. As an example, if
you are using [nginx](http://nginx.org/) you might put the following in `/var/vcap/jobs/nginx/plugin/logs/config.yml`:

    ---
    files:
      "nginx/access.log":
        fields:
          type: "nginx_access"
      "nginx/error.log":
        fields:
          type: "nginx_error"

The third configuration source is overrides. If you are using an upstream release and need to change some fields they
specify in their template-specific configuration file, you can use the `plugin.logs._overrides` property (or
forwarder-specific property, e.g. `plugin.logs.syslog._overrides`).

There are several keywords you can use for dynamic interpolation in field values:

 * `{{deployment}}` - the deployment name (e.g. `wordpress`)
 * `{{index}}` - the index of the job hosting the processes (e.g. `1`)
 * `{{job}}` - the name of the job hosting the processes (e.g. `webserver`)
 * `{{file_path}}` - the raw path of the file (e.g. `/var/vcap/sys/log/nginx/access.log`)
 * `{{file_template}}` - a guess of the template generating the log (e.g. `nginx`)

As an example, the plugin automatically adds several fields to log messages:

    ---
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
forwarding, it cannot be re-included. As an example, the `syslog` forwarder excludes its own log files using the
following:

    ---
    files:
      "plugin-logs-syslog/*.log": ~

Configuration files and their fields are processed in the following order (you should generally avoid setting the
`_builtin_*` properties since they're internally managed by the release):

 * property `plugin.logs._builtin_defaults`
 * property `plugin.logs.{forwarder}._builtin_defaults`
 * property `plugin.logs._defaults`
 * property `plugin.logs.{forwarder}._defaults`
 * glob `/var/vcap/jobs/*/plugin/logs/config.yml`
 * property `plugin.logs._overrides`
 * property `plugin.logs.{forwarder}._overrides`

**Job Properties**

There are several configurable properties used by all forwarders (in the `plugin.logs` namespace):

 * `start_delay` - delay startup commands by this number of seconds (`integer`, optional)
 * `_defaults` - default log forwarding YAML configuration applied to all forwarders (`string`, optional)
 * `_overrides` - override template configuration applied to all forwarded files (`string`, optional)


### Syslog

The [syslog](http://en.wikipedia.org/wiki/Syslog) protocol can be used to send messages to a compatible syslog server.

**Job Properties**

There are several configurable properties (in the `plugin.logs.syslog` namespace):

 * `server` - the upstream server in the format of `host:port` (`string`, required)
 * `transport` - transport to use with upstream server (tcp|udp) (`string`, default `tcp`)
 * `ssl_ca_certificate` - the upstream SSL certificate to use for authentication (`string`, optional)
 * `ssl_certificate` - a SSL certificate to use for authentication (`string`, optional)
 * `ssl_key` - a SSL key to use for authentication (`string`, optional)
 * `_defaults` - default log forwarding configuration applied to syslog files (`string`, optional)
 * `_overrides` - override template configuration applied to syslog-forwarded files (`string`, optional)


### Lumberjack

The lumberjack protocol is primarily used by [logstash-forwarder](https://github.com/elasticsearch/logstash-forwarder),
a project maintained by the [elasticsearch](https://github.com/elasticsearch) team.

**Job Properties**

There are several configurable properties (in the `plugin.logs.lumberjack` namespace):

 * `field_prefix` - a prefix added to all field names (`string`, default `@source_`)
 * `servers` - an array of upstream servers with values in the format of `host:port` (`string[]`, required)
 * `idle_flush_time` - maximum time to wait for a full spool before flushing anyway (`string`, optional)
 * `spool_size` - maximum number of events to spool before a flush is forced (`integer`, optional)
 * `ssl_ca_certificate` - the upstream SSL certificate to use for authentication (`string`, required)
 * `ssl_certificate` - a SSL certificate to use for authentication (`string`, optional)
 * `ssl_key` - a SSL key to use for authentication (`string`, optional)
 * `_defaults` - default log forwarding configuration applied to lumberjack files (`string`, optional)
 * `_overrides` - override template configuration applied to lumberjack-forwarded files (`string`, optional)


## Notes

If you dislike the built-in behaviors (log file selection and `bosh_*`/`stream` fields) and prefer to manage all your
own settings, you can disable them with the following:

    properties:
      plugin:
        logs:
          _builtin_defaults: ~


## Open Source

[MIT License](./LICENSE)
