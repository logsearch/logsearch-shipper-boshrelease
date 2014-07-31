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

The first configuration source is through manifest properties. You can use the `plugin.logs._defaults` property to
define default configuration. By default, all `/var/vcap/sys/log/**/*.log` files are included. As an example, you could
add the following to your manifest to include the director name on all log messages:

    properties:
      plugin:
        logs:
          _defaults: |
            ---
            "**/*.log":
              fields:
                bosh_director: "prod--aws--us-west-1"

The second configuration source is template-specific configuration files. When starting, the plugin will look for
`/var/vcap/jobs/{job-name}/logsearch/logs.yml` files to load. This allows you to define default fields for all logs
involved with your job. By default, non-absolute paths are relative to `/var/vcap/sys/log`. As an example, if you are
using [nginx](http://nginx.org/) you might put the following in `/var/vcap/jobs/nginx/plugin/logsearch/logs.yml`:

    files:
      "nginx/access.log":
        fields:
          type: "nginx_access"
      "nginx/error.log":
        fields:
          type: "nginx_error"

The third configuration source is overrides. If you are using an upstream release and need to change some fields they
specify, you can use the `plugin.logs._overrides` property. As an example, if your filters rely on a different type
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

As an example, the plugin [automatically adds](./jobs/logsearch-shipper/spec) several fields to log messages:

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

 * property `plugin.logs._builtin_defaults`
 * property `plugin.logs._defaults`
 * files `/var/vcap/jobs/*/logsearch/logs.yml`
 * property `plugin.logs._overrides`

**Job Properties**

There are several configurable properties used by all forwarders (in the `plugin.logs` namespace):

 * `server` - the upstream server in the format of `host:port` (`string`, required)
 * `ssl_ca_certificate` - the upstream SSL certificate to use for authentication (`string`, optional)
 * `ssl_certificate` - a SSL certificate to use for authentication (`string`, optional)
 * `ssl_key` - a SSL key to use for authentication (`string`, optional)
 * `start_delay` - delay startup commands by this number of seconds (`integer`, optional)
 * `transport` - transport to use with upstream server (tcp|udp) (`string`, default `tcp`)
 * `_defaults` - default log forwarding YAML configuration applied to all forwarders (`string`, optional)
 * `_overrides` - override template configuration applied to all forwarded files (`string`, optional)


## Notes

If you dislike the built-in behaviors (log file selection and `bosh_*`/`stream` fields) and prefer to manage all your
own settings, you can disable them with the following:

    properties:
      plugin:
        logs:
          _builtin_defaults: ~


## Open Source

[Apache License 2.0](./LICENSE)
