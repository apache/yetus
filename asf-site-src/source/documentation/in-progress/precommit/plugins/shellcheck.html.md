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

shellcheck

# Category

Test

# Description

Runs [shellcheck](https://www.shellcheck.net) when the presence of a shell script is found.

* A locale with UTF-8 support is required.  If the locale is not UTF-8 compliant, the locale will be forcibly set to C.UTF-8.
* The `-x` option is always passed to `shellcheck` if the version is greater than 0.4.1.
* Versions of `shellcheck` that are earlier than 0.3.5 will generate a warning that the tool is very buggy.

# Environment Variables

None

# Options

None

# Docker Notes

None

# Developer Notes

None
