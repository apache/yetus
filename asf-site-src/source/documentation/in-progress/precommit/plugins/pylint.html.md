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

pylint

# Category

Test

# Description

Runs [pylint](http://pylint.org/) against Python code.

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--pylint=<file>` | Location of the `pylint` binary if it is not on the path.  Default is 'pylint'. |
| `--pylint-ignore-bad-option-value=<bool>` | Ignore `bad-option-value` errors. Default is 'true' |
| `--pylint-pip-cmd=<file>` | Location of the `pip` binary for install requirements.txt files.  Default is 'pip'. |
| `--pylint-rcfile=<file>` | Location of the `.pylintrc` file to override `pylint` default. |
| `--pylint-requirements=<bool>` | Process any `requirements.txt` file.  Default is 'false'. |
| `--pylint-use-user=<bool>` | Use `--user` for processing the `requirements.txt` file.  Default is 'true'. |

# Docker Notes

None

# Developer Notes

None
