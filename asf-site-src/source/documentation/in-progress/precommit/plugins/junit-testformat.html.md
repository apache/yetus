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

junit

# Category

Test Format

# Description

The `junit` test format attempts to process test data as documented in [junit](https://svn.apache.org/repos/asf/ant/core/trunk/src/main/org/apache/tools/ant/taskdefs/optional/junit/XMLJUnitResultFormatter.java) format.

NOTE:

* there is no formal specification of the format so results parsing the output may be mixed.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--junit-test-output=<directory>` | Directory to search for the test output TEST-*.xml files, relative to the module directory |
| `--junit-test-prefix=<prefix to trim>` | Prefix to trim from test names to reduce the amount of output |

# Docker Notes

None

# Developer Notes

None
