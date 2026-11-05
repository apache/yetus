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

github

## Category

Bug System

## Description

Enables support for reading and writing back to [GitHub](https://github.com/) and compatible systems such as GitHub Enterprise.  See also the [Bugsystems](../../bugsystems) documentation for more information.

## Environment Variables

None

## Options

| Option                                  | Notes                                              |
| :-------------------------------------- | :------------------------------------------------- |
| `--github-annotations-limit=<int>`      | Max number of GitHub Checks Annotations to attempt |
| `--github-api-url=<url>`                | REST API URL (for GitHub Enterprise)               |
| `--github-base-url=<url>`               | Non-REST API URL (for GitHub Enterprise)           |
| `--github-repo=<repo>`                  | `username/repository` identifier                   |
| `--github-status-use-htmlreport=<bool>` | Use htmlout for Github Status 'Details' link       |
| `--github-token=<token>`                | Token used to perform read and write operations    |
| `--github-update-comment[=<key>]`       | Update the PR comment instead of adding a new one  |
| `--github-write-comment`                | Write the final report as a PR comment             |

## Updating The PR Comment

`--github-write-comment` adds a new comment with every run. `--github-update-comment` implies it, and instead
updates the comment the same GitHub user previously wrote with the same key (default: `default`). The key may only
contain `A-Z`, `a-z`, `0-9`, `.`, `_` and `-`. Use a different key per job when one build writes several reports,
e.g., one per OS.

1. The report carries a hidden `<!-- yetus-report:<key> -->` marker and a `Tested commit` row.
1. The token's user comes from `GET /user`. Under GitHub Actions, where that call is denied, `github-actions[bot]`
   is assumed.
1. Hidden (minimized) comments are not updated.
1. If the PR head moved past the tested commit, the comment is skipped so a slow build cannot replace the report of
   a newer one. Statuses are still written.
1. If looking up or updating the comment fails, a new comment is written.

## HTML Details LInk

By default, if Apache Yetus is under conditions when it would normally write a Github Status (e.g., Jenkins processing
a GitHub PR using the Github Multibranch Plug-in), the Details will link to the [htmlout](../htmlout) report rather than
the robot's console after the run is complete. The report file must either be relative to the normal `--patch-dir` or
be forcibly set using the `--html-report-url`.

## Docker Notes

None

## Developer Notes

All of the command line settings may also be set via internal environment variables.  However care must be taken to not step on [robots](../../robots) that will also set some of these variables.
