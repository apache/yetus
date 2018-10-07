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

Robots: Continuous Integration Support
======================================

test-patch works hand-in-hand with various CI and other automated build systems.  test-patch will attempt to auto-determine if it is running under such a system and change its defaults to match known configuration parameters automatically. When robots are activated, there is generally some additional/changed behavior:

  * display extra information in the footer
  * change log entries from file names to URLs
  * automatically activate --resetrepo
  * automatically enable the running of unit tests and run them in parallel
  * if possible, write comments to bug systems
  * activate Docker maintenance when --docker is passed

Jenkins
=======

(See also [precommit-admin](precommit-admin), for special utilities built for Jenkins.)

Jenkins support is automatically triggered by the existance of the JENKINS_URL environment variable.  When in this mode, the test-patch will automatically configure the console to show URLs and configure some per-executor settings to prevent multiple instances from bumping into each other.  Additionally, some extra information will now be added to some error messages.

Jenkins does not differentiate between full builds and patch testing/pull requests.  test-patch requires the location of what to test to be provided on the command line.