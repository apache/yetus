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

# Name

spotbugs

# Category

Test

# Description

Runs the Java-based [SpotBugs](https://spotbugs.github.io/) utility.

# Environment Variables

| Variable | Passed to Docker | Notes |
|:---------|:-----------------|:------|
| `SPOTBUGS_HOME` | NO | Used to determine the location of the SpotBugs installation |

# Options

| Option | Notes |
|:---------|:------|
| `--spotbugs-home==<dir>` | SpotBugs home directory. There is no default. |
| `--spotbugs-strict-precheck` | Fail patch testing if `spotbugs` determines a failure before even applying the patch |

# Docker Notes

None

# Developer Notes

None
