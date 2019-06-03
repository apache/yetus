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

# Robots: Semaphore CI

TRIGGER: ${CI}=true and ${SEMAPHORE}=true

Semaphore CI requires that `checkout --use-cache` has been used prior to trigging test-patch. It is HIGHLY recommended to use a helper script checked into the repository to control precommit options to avoid problems with Semaphore CI's parsing of long lines in the YAML file.

The GitHub repo and the Pull Request in use are automatically detected.  However, some personalities may override the auto-detected Github repository information.  It may be necessary to manually configure it in your `semaphore.yml` file.

See also:

* Apache Yetus' source tree [semaphore.yml](https://github.com/apache/yetus/blob/main/.semaphore/semaphore.yml) for some tips and tricks.
* Apache Yetus' helper script [semaphore-build.sh](https://github.com/apache/yetus/blob/main/.semaphore/semaphore-build.sh)
