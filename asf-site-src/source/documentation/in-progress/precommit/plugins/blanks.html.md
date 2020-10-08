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

blanks

# Category

Test

# Description

Provides a test to do two things:

* Fail patches that use tabs instead of spaces (where appropriate)
* End of line blank space

By default, blanks will automatically ignore tabs in Makefiles and Go-related files.  However, if a file is provided, that file must also include the appropriate regexs for Makefiles and Go.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--blanks-eol-ignore-file=<file>` | File containing regexs of files/dirs to ignore EOL blanks. Defaults to `.yetus/blanks-eol.txt` |
| `--blanks-tabs-ignore-file=<file>` | File containing regexs of files/dirs to ignore tabs. Defaults to `.yetus/blanks-eol.txt` |

# Docker Notes

None

# Developer Notes

None
