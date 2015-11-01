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
   * Upload the YETUS-1.00.patch file to the aformenentioned JIRA

The naming of the patch should be in (JIRA).(patch number).patch or, if it needs to apply to a specific branch, (JIRA).(branch name).(patch number).patch format. For example, YETUS-9.00.patch, YETUS-500.02.patch, or YETUS-23.cmake.11.patch. This way, if you need to upload another version  of the patch, you should keep the file name the same and JIRA will sort them according to date/time if multiple files have the same name. This feature is also useful to traceback the history of a patch and roll-back to an earlier version if needed.

## Website

We use middleman to generate the website content from markdown and other
dynamic templates. The following steps assume you have a working
ruby 2.x environment setup:

```bash
gem install bundler
bundle install
```

### Make changes in asf-site-src/source
Make any changes in the source directory:

```bash
cd asf-site-src/source
vi contribute.html.md
```

### Make changes to API Docs
Optionally, you can update the generated API docs from other parts of the project. If they have been updated then the middleman build will pick up the changes.

e.g. Precommit changes will be picked up by the Middleman build.

```bash
cd ../precommit/core.d
vi 01-common.sh
```


e.g. Audience Annotations requires running Maven.

```bash
cd ../audience-annotations-component
mvn -DskipTests -Pinclude-jdiff-module javadoc:aggregate
cd -
```

### Generating the website
To generate the static wesbite for Apache Yetus run the following commands at the root asf-site-src directory:

```bash
bundle exec middleman build
```

### Live Development
Live development of the site enables automatic reload when changes are saved.
To enable run the following command and then open a browser and navigate to
[http://localhost:4567](http://localhost:4567/)

	bundle exec middleman

### Publishing the Site
Commit the publish directory to the asf-site branch.
