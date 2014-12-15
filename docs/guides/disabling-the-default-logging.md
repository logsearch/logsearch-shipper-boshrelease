---
title: "Disabling the Default Logging"
---

If you dislike the built-in behaviors (log file selection and `bosh_*`/`stream` fields) and prefer to manage all your
own settings, you can disable them with the following:

    properties:
      logsearch:
        logs:
          _builtin_defaults: ~
