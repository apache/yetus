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

#How To Contribute

## Submitting Changes

We use git as our version control system. To streamline the process of giving proper credit to the contributors when committing patches, we encourage contributors to submit patches generated using git format-patch. This has many benefits:

   * Committers can't forget to attribute proper credit to the contributor
   * The contributors name and email address shows up in git log
   * When viewing Yetus's source code on https://github.com/apache/yetus , the commits from the contributor are linked to their github.com account if it's linked to the same email address they used when generating the git format-patch

Long story short, it makes both the contributors' and committers' lives easier, so please generate your patches using git format-patch.

Here are some instructions on how to generate patches:

   * Ensure that you have all of your change as 1 commit which has the correct commit message - something like `YETUS-1. Update shellcheck plug-in to support bats files`
   * Then run a command like: `git format-patch HEAD^..HEAD --stdout > YETUS-1.00.patch`
   * Upload the YETUS-1.00.patch file to the aforementioned JIRA

The naming of the patch should be in (JIRA).(patch number).patch or, if it needs to apply to a specific branch, (JIRA).(branch name).(patch number).patch format. For example, YETUS-9.00.patch, YETUS-500.02.patch, or YETUS-23.cmake.11.patch. This way, if you need to upload another version of the patch, you should keep the file name the same and JIRA will sort them according to date/time if multiple files have the same name. This feature is also useful to traceback the history of a patch and roll-back to an earlier version if needed.

## Task Specific Guidance

Below are guides meant to give you help accomplishing specific tasks for the project:

   * [Maintaining the Yetus Website](website) - walks through how to view the website locally, update various static and generated pages, and render the html for publishing.
   * [Working with Release Candiates](releases) - covers managing the release process, validating proposed release candidates, and publishing project approved artifacts.
