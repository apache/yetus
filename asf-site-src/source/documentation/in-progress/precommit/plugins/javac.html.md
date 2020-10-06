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

javac

# Category

Test (Compile)

# Description

Provides support for [Java](https://java.net) compilation.

The location of Java must be configured either via the command line (--) or via the `JAVA_HOME` environment variable.  On Mac OS X, `/usr/libexec/java_home` may also be used.

The `JAVA_HOME`/`--java-home` JDK is considered the base JDK and will always be used last when `--multijdk` options are used. Therefore, it should **always** be the earliest version so that bytecode remains compatible between versions.

# Environment Variables

`JAVA_HOME` may be used to set the location of the JDK.

# Options

| Option | Notes |
|:---------|:------|
| `--java-home` | The base JDK to use for Java work |
| `--multijdkdirs=<dir1,dir2,..>` | Comma delimited list of directories to treat as JDKs |
| `--multijdktests=<test1,test2,..>` | Comma delimited list of tests that support MultiJDK mode that should actually be run in MultiJDK mode |

# Docker Notes

Locations should be local to the Docker container image.

# Developer Notes

* Options are actually handled by `test-patch` directly due to intertwined nature of them.
