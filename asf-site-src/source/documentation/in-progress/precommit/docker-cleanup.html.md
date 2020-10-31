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

# docker-cleanup

<!-- MarkdownTOC levels="1,2" autolink="true" indent="  " bullets="*" bracket="round" -->

* [Description](#description)
* [Usage](#usage)
  * [Default Mode](#default-mode)
  * [Sentinel Mode](#sentinel-mode)

<!-- /MarkdownTOC -->

# Description

`docker-cleanup` is a command to perform precommit's Docker cleanup functionality outside of patch and build testing.
It is designed to be run as a regularly automated job on CI systems that do not have their own Docker cleanup
facilities.  It is built from the perspective that nothing on the system is permanent.  It supports many of the same
options as `test-patch`'s [docker](../docker)-mode. Please see that page for more details.

# Usage

## Default Mode

Executing `docker-cleanup` with no additional options will perform the same work as the `--robot` option.

```bash
$ docker-cleanup

...
        Removing old images
...
Untagged: hadoop/createrelease:3.0.0-alpha3-SNAPSHOT_10600
Deleted: sha256:1a96c79a0a9ab538c6c7765dc908eca3e689270b778d6ae2add558e89792a7d8
...
                       Docker Container Maintenance
...

```

## Sentinel Mode

`docker-cleanup` also supports the `--sentinel` mode to kill and remove stale running containers:

```bash
$ docker-cleanup --sentinel

...
                            Removing old images
...
Untagged: hadoop/createrelease:3.0.0-alpha3-SNAPSHOT_10600
Deleted: sha256:1a96c79a0a9ab538c6c7765dc908eca3e689270b778d6ae2add558e89792a7d8
...

                       Docker Container Maintenance
...
Attempting to remove docker container /big_kowalevski [5ffd22a56ebcfe38d72b9078e0e7133ab6dc054115a4804e504c910bdbdeea45]
...
```
