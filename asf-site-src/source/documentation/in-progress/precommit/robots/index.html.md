<!---
  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
-->

# Robots: Continuous Integration Support

<!-- MarkdownTOC levels="1,2" autolink="true" indent="  " bullets="*" bracket="round" -->

* [Intro](#intro)
* [Automated Robot Detection](#automated-robot-detection)
* [Manual Configuration](#manual-configuration)
* [Sentinel Mode](#sentinel-mode)
* [Continuous Improvement](#continuous-improvement)

<!-- /MarkdownTOC -->

# Intro

`test-patch` works hand-in-hand with various CI and other automated build systems.  `test-patch` will attempt to auto-determine if it is running under such a system and change its defaults to match known configuration parameters automatically. When robots are activated, there is generally some additional/changed behavior:

* display extra information in the footer
* change log entries from file names to URLs
* activate `--resetrepo` to keep the directory structure clean
* enable the running of unit tests and run them in parallel
* if possible, write comments to bug systems
* attempt to determine the build tool in use
* activate Docker maintenance when `--docker` is passed
* attempt to determine whether this is a full build (`qbt`) or testing a patch/merge request/pull request.

# Automated Robot Detection

The following systems are detected automatically when run in one of these environments:

* [Azure Pipelines](azurepipelines)
* [Circle CI](circleci)
* [Cirrus CI](cirrusci)
* [GitHub Actions](githubactions)
* [Gitlab CI](gitlabci)
* [Jenkins](jenkins)
* [Semaphore CI](semaphoreci)
* [Travis CI](travisci)

# Manual Configuration

For automated systems that are not directly supported, `--robot` tells `test-patch` that this is an automated system.  This will trigger many of the above settings.

The `--build-url` option is also useful when running in `--robot` mode so that emails and such
have a location to look at the output artifacts:

```bash
$ test-patch --robot --build-url=https://server.example.name:80/${buildnumber}/
```

Some plug-ins such as Maven have special handling if there are multiple executions of `test-patch` happening at once.  It is very common when using automation systems to have multiple runs on the same host. In order to assist these plug-ins, an instance identifier may be provided:

```bash
$ test-patch --robot --instance=1
```

If `--robot` is specified without an instance, a random number is generated and used.

# Sentinel Mode

If stuck Docker containers are a problem, a more aggressive robot may be enabled with the `--sentinel` option.  This option
enables killing containers that have been running for over 24 hours as well. See the documentation on [docker](../docker)
for more information.

# Continuous Improvement

It isn't unusual when adding a new linter to an existing source repository to be overwhelmed with new errors.
Most projects want to start out where all new patches cannot add new errors, but the existing ones are
acceptable.  In order to enable branches to build with errors but patches/PRs to fail on robots,
`test-patch` supports the `--continuous-improvement` flag:

Normally, `test-patch` execute with this flag set to false:

```bash
$ test-patch --continuous-improvement=false (other options)
```

This setting will fail branches and PRs if any errors are found. However, if this value is set to true:

```bash
$ test-patch --continuous-improvement=true (other options)
```

then branches will still report errors but the return code will be successful.  Using this mode is ideal for
many CI/CD systems that are using repositories with known problems.
