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

# Convenience Docker Hub Images

<!-- MarkdownTOC levels="1,2" autolink="true" -->

* [File Access](#file-access)
* [A Note About Precommit](#a-note-about-precommit)

<!-- /MarkdownTOC -->

While not official releases, the Apache Yetus project makes available two types of images on hub.docker.com:

* apache/yetus-base

  This image is the same as the 'built-in' Dockerfile when `--docker` is used without `--dockerfile`  on the precommit command line.  It includes all of the pre-requisites as needed by the various Apache Yetus components. It is located in `precommit/src/main/shell/test-patch-docker/`.

* apache/yetus

  This image is the same as apache/yetus-base but includes a pre-built version of Apache Yetus as part of the base OS image. In other words, qbt, releasedocmaker, shelldocs, test-patch, etc., are in /usr/bin and available in the default path. It is generated from the Dockerfile located in the root of the source and is built with the options provided in the hooks directory.

Both images should be suitable to be used as a building block or even directly if your build environment needs no other dependencies.  These images are especially useful for various CI systems that require a Docker image to be used.

Images are tagged such that 'master' represents the last successful Docker image build of the master branch.  Images based off of the official source releases are tagged with a matching version number (e.g., 0.9.0).  There is no 'latest' tagged image.  It is recommended that users choose a stable tag so as not to be surprised by incompatible changes.

# File Access

All of the executables that Apache Yetus provides requires access to one or more directories.  These directories should be provided on the command line via the volume flags to docker run. For example, to run shelldocs against test-patch.sh:

```bash
docker run \
  --rm \
  -v /tmp/out:/output \
  -v /src/precommit/src/main/shell:/input:ro \
  apache/yetus:0.9.0 \
    shelldocs --output /output/test-patch.md --input /input/test-patch.sh
```

In this example, we mount two volumes: one for input (marked read-only), one for output.  After execution, shelldocs has processed test-patch.sh and generated a test-patch.md file in /tmp/out on our local machine.

Precommit also works, assuming that Apache Yetus image has all of your project's dependencies.  For example:

```bash
docker run \
  --rm \
  -v /tmp/patchdir:/patchdir \
  -v /src:/basedir \
  apache/yetus:0.9.0 \
  qbt \
    --plugins=all \
    --basedir=/basedir \
    --patch-dir=/patchdir \
    --project=yetus
```

If your project needs additional dependencies, it is trivial to build off of the Apache Yetus image:

```Dockerfile
FROM apache/yetus:0.9.0
RUN apt-get -q update && apt-get -q install -y \
      clang \
      libssl-dev \
      valgrind \
      zlib1g-dev
```

```bash
docker build -t project/build:0.9.0 -f .
```

This example builds a docker image based off of Apache Yetus 0.9.0 but with the additions of clang, some development libraries, and valgrind.  Now project/build:0.9.0 can be used instead of apache/yetus:0.9.0 since it has all of Apache Yetus and the additions needed by our project.

# A Note About Precommit

test-patch and friends have direct support for Docker outside of the convenience images.  That information is covered in-depth in the[precommit-docker](../precommit-docker) section.
