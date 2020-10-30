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

codespell

# Category

Test

# Description

Runs [codespell](https://github.com/codespell-project/codespell) on the repository.

Due to how `codespell` executes, `./` is prefixed onto paths at runtime.  This prefixing is
to be a bit more consistent with how one would run it from the command line such
that `.codespellrc` is easier to manage.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--codespell-exclude-lines=<file>` | File of lines that codespell should ignore (defaults to `.codespellignorelines`) |

# Docker Notes

None

# Developer Notes

None
