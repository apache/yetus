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

Bug System

# Description

The `junit` Bug System provides output of failed tests in [junit](https://svn.apache.org/repos/asf/ant/core/trunk/src/main/org/apache/tools/ant/taskdefs/optional/junit/XMLJUnitResultFormatter.java) format.

NOTE:

* there is no formal specification of the format so results parsing the output may be mixed.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--junit-report-style=[full|line]` | Style of the junit report |
| `--junit-report-xml=<file>` | Name of the output file |

## JUnit Style

The JUnit report type has two formats:

* `full` - summarizes per-test and provides a link to the report for that test
* `line` - summarizes per-file and works better with integrated CI systems and with external readers such as Jenkins WarningNG plug-in

# Docker Notes

None

# Developer Notes

None
