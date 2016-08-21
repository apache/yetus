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

Test Format Support
==================

test-patch has the ability to support multiple test formats. Test formats have some extra hooks to process the output of test tools and write the results to some tables. Every test format plug-in must have one line in order to be recognized:

```bash
add_test_format <pluginname>
```

Test format plugins can provide following two methods, which will be called by test-patch if defined.

* pluginname\_process\_tests

    - Given a path to the log file and tested module name, parse that file and store the test result into global variables and/or files.

* pluginname\_finalize\_results

    - Using the results stored by pluginname\_process\_tests, write them to the test result table and/or the footer table for reporting.

For an example of how to write a test-format plugin, you can look at [junit plugin](https://github.com/apache/yetus/blob/master/precommit/test-patch.d/junit.sh) bundled in Apache Yetus.