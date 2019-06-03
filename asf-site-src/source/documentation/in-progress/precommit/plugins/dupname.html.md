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

dupname

# Category

Test

# Description

Checks for file system objects in the git repository that conflict due to case.  For example, if the source repository contains:

```git
dir1/file
DIR1/file
dir1/File
```

All three would be flagged as only one could exist on a case insensitive file system, such as Mac OS X's HFS+.

NOTE: This test is ALWAYS enabled.

# Environment Variables

None

# Options

None

# Docker Notes

None

# Developer Notes

None
