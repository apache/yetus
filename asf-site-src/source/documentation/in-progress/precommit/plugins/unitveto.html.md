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

unitveto

# Category

One or more of:

Test

# Description

Automatically fail a patch if matching files are touched.  This test is useful for code that absolutely requires human intervention.

# Environment Variables

| Variable | Passed to Docker | Notes |
|:---------|:-----------------|:------|
| `UNITVETO_RE` | NO | Same as `--unitveto-re` |

# Options

| Option | Notes |
|:---------|:------|
| `--unitveto-re=<regex>` | Regular expression of the files/directories to fail. |

# Docker Notes

None

# Developer Notes

None
