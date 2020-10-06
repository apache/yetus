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

# Robots: Travis CI

TRIGGER: ${TRAVIS}=true

Travis CI support will update the local checked out source repository to include references to all branches and tags

If `${ARTIFACTS_PATH}` is configured, then `--patch-dir` is set to the first listed directory path.  However, links to the location logs must still be configured manually.

Personalities will override the auto-detected Github repository information.  It may be necessary to manually configure it in your `.travis.yml` file.

As of this writing, it is not possible to make the Travis CI build environment use the Apache Yetus pre-built docker images without using `docker run` in the before_install phase.  Therefore, using the image is the same as described in the [Apache Yetus Docker Hub Images](/yetus-docker-image) page.

See also:

* Apache Yetus' source tree [.travis.yml](https://github.com/apache/yetus/blob/main/.travis.yml) for some tips and tricks.
