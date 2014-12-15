---
title: "About Logs"
---

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
