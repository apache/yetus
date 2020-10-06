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

# Overview

<!-- MarkdownTOC levels="1,2" autolink="true" indent="  " bullets="*" bracket="round" -->

* [Project-Specifc Builds](#project-specifc-builds)
* [Jenkins Job Tokens](#jenkins-job-tokens)

<!-- /MarkdownTOC -->

The jenkins-admin script is an automated way to submit JIRA issues to the Apache Yetus precommit testing framework.  It works by:

* Grab the XML output of a JIRA filter that contains all the issues that should be tested by the system. In general, the filter should comprise issues from relevant JIRA projects that are currently in Patch Available state.
* Process the XML into a list of `<project-issue>, <attachment id>` pairs, where attachment id is the id for the _newest_ attachment on the issue.  Pulling the newest attachment implies that if multiple attachments are uploaded to an issue, the last one is the one that will be processed and other attachments will be _ignored_.
* Grab the single build artifact that this job keeps, `patch_tested.txt`. This file contains the list of `<project-issue>, <attachment id>` pairs that have already been submitted for testing.
* For each pair from the processed XML, see if the pair is in `patch_tested.txt`. If not, start a new project build and append the pair to the file.
* When this admin job completes, archive the latest `patch_tested.txt` file.

All communication to Jenkins is currently done with the Remote Access API using tokens where necessary (see below).  JIRA communication is currently unauthenticated.

The JIRA filter is a required value provided via the `--jira-filter` parameter. It should be the full URL as provided by the JIRA UI.

In order to prevent accidents, the `--live` parameter is required when jenkins-admin is used for production purposes.  Without this flag, jobs are not launched but the `patch_tested.txt` file is created/updated.

By default, jenkins-admin expects that the `JOB_NAME` environment variable will be set by Jenkins.  If it is not or it needs to be overridden, that can be done with the `--jenkins-jobname` parameter.

Additionally, the URL of the Jenkins server is expected to be in the `JENKINS_URL` environment variable, also usually set by Jenkins.  This value may be overridden with the `--jenkins-url` option.

The very first run of the job should be done with the `--initialize` parameter to create the first `patch_tested.txt` file.  Otherwise, the job will fail because a previous version of it cannot be downloaded from previous runs.

# Project-Specifc Builds

New builds are started via buildWithParameters call. Three parameters are added to the URL:

* token = Jenkins security token (see below)
* ISSUE\_NUM = JIRA issue number
* ATTACHMENT\_ID = JIRA attachment id

 By default, the Jenkins job name is expected to be `PreCommit-{project}`, where the project name matches the JIRA project name. Using the JIRA issue YETUS-1 with an attachment number of 2345 would result in the following URL:

   {JENKINS\_URL}/job/PreCommit-YETUS/buildWithParameters?token=YETUS-token&ISSUE_NUM=1&ATTACHMENT_ID=2345

 The `{JENKINS_URL}` can be overridden on a per project basis using the `--jenkins-url-override` option.  This parameter allows for one job on one Jenkins server to direct different projects to different Jenkins servers.  For example:

```bash
   jenkins-admin --jenkins-url-override=PROJ1=https://example.com/1 --jenkins-url-override=PROJ2=https://example.com/1
```

would send all PROJ1 Jenkins jobs to the first URL and all PROJ2 jobs to the second URL.  The `--jenkins-url-override` option may be listed as many times as necessary.

The job name can be overridden via the `--jenkins-project-template` option.  For example, using `--jenkins-project-template='{project}-Build'`would change the above URL to be:

   .../job/PreCommit-YETUS-Build/buildwithParameters?...

# Jenkins Job Tokens

Currently, jenkins-admin supports the usage of Jenkins tokens for authentication via the `--jenkins-token` option.  This option provides two ways to do tokens

* Flat tokens
* Template tokens

Flat tokens are a simple string.  For example, `--jenkins-tokens=yetus` would require the `yetus` string to be listed as the token in the Jenkins job configuration that is being requested.

On the other hand, template tokens perform some simple string substitution before being used. This exchange includes:

* {project} for the JIRA project name
* {issue} for the JIRA issue number
* {attachment} for the JIRA issue attachment id

For example, if JIRA issue YETUS-1 has an attachment of 2345, then `{project}` becomes `YETUS`, `{issue}` becomes `1`, and `{attachment}` becomes 2345.

By default, the token is set to `{project}-token`.  The token then becomes `YETUS-token` using the above values.
