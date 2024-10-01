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

make

# Category

Build Tool

# Description

Enables using the various forms of make as the build tool.  This includes [GNU make](https://www.gnu.org/software/make/) and [BSD make](https://www.freebsd.org/cgi/man.cgi?make(1)).

Currently, this plugin makes assumptions about what are valid targets:

| Target | Function |
|:-------|:---------|
| clean | Clean the directory, keeping any configuration objects such as from `autoconf`.  (See also `--make-use-git-clean`) |
| distclean | Clean the directory back to a pristine shape. (See also `--make-use-git-clean`) |
| test | Perform unit testing |

# Environment Variables

None

# Options

| Option | Notes |
|:---------|:------|
| `--make-cmd=<cmd>` | Executable location |
| `--make-file=<filename>` | Filename to use instead of the default `Makefile` |
| `--make-use-git-clean` | Instead of `make clean`, use `git clean` to wipe the repository |

# Docker Notes

None

# Developer Notes

See [build tools](../../buildtools) for more information.
