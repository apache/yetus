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

detsecrets

# Category

Test

# Description

Runs [detect-secrets](https://github.com/yelp/detect-secrets).

NOTE: This test also requires a working Python 3.4+ interpreter available on the path.  It will be called first
as `python3` and secondarily as `python`.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--detsecrets=<file>` | Location of the `detect-secrets` binary if it is not on the path.  Default is 'detect-secrets'. |
| `--detsecrets-files=<regex>` | Regex of files to ignore. |
| `--detsecrets-hashes-to-ignore=<file>` | Filename of a list of hashes to ignore Default is .yetus/detsecrets-ignored-hashes.txt' |
| `--detsecrets-lines=<regex>` | Regex of lines to ignore. |
| `--detsecrets-secrets=<regex>` | Regex of secrets to ignore. |

# Docker Notes

The IBM version is based upon 0.13 and is slightly incompatible with the Yelp version.  The docker container includes
the Yelp version.  Using the IBM version may result in some weirdness.

# Developer Notes

None
