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

# Bug System Support

<!-- MarkdownTOC levels="1,2" autolink="true" -->

* [Bugzilla Specific](#bugzilla-specific)
* [GitHub Specific](#github-specific)
* [GitLab Specific](#gitlab-specific)
* [JIRA Specific](#jira-specific)

<!-- /MarkdownTOC -->

test-patch has the ability to support multiple bug systems.  Bug tools have some extra hooks to fetch patches, line-level reporting, and posting a final report. Every bug system plug-in must have one line in order to be recognized:

```bash
add_bugsystem <pluginname>
```

* pluginname\_locate\_patch
  * Given input from the user, download the patch if possible.

* pluginname\_determine\_branch
  * Using any heuristics available, return the branch to process, if possible.

* pluginname\_determine\_issue
  * Using any heuristics available, set the issue, bug number, etc, for this bug system, if possible.  This is typically used to fill in supplementary information in the final output table.

* pluginname\_write\_comment
  * Given text input, write this output to the bug system as a comment.  NOTE: It is the bug system's responsibility to format appropriately.

* pluginname\_linecomments
  * This function allows for the system to write specific comments on specific lines if the bug system supports code review comments.

* pluginname\_finalreport
  * Write the final result table to the bug system.

# Bugzilla Specific

Currently, Bugzilla support is read-only.  To use it, the Bug ID must be preferenced with 'BZ:'.  For example:

```bash
$ test-patch (other options) BZ:4
```

... will pull down Bugzilla ID #4.

Using the `--bugzilla-base-url` on the command line or BUGZILLA\_BASE\_URL in a project's personality will define the location of the Bugzilla instance.  By default, it is <https://bz.apache.org/bugzilla>.

# GitHub Specific

GitHub supports the full range of functionality, including putting comments on individual lines.  Be aware, however, that `test-patch` will (generally) require that GitHub PRs be fully squashed and rebased (i.e., a single commit) in many circumstances.

By default, the GitHub plug-in assumes that <https://github.com> is the base URL for GitHub.  Enterprise users may override this with the `--github-base-url` for the normal web user interface and `--github-api-url` for the API URL.  Personalities may use GITHUB\_API\_URL and GITHUB\_BASE\_URL.

The specific repository on GitHub is defined with either `--github-repo` on the command line or GITHUB\_REPO in a personality.  It should take the form of "user/repo".

GitHub pull requests may be directly processed on the command line in two ways:

* GH:(PR number)
* GHSHA:(PR SHA1 number)

The GitHub bugsystem plugin will attempt to download the unified diff that the pull request references.
Pull requests that are made off of a specific branch will switch the test repo to that branch, if permitted.  If the pull request references a JIRA issue that matches the given JIRA issue regexp in the Subject, the JIRA plug-in will also be invoked as needed.

## GitHub Authentication

In order to comment on issues or, depending upon the security setup of the repo, authentication credentials.  The GitHub plug-in supports authentication via token or user name/passphrase.

### GitHub Token

The token is provided via the `--github-token` option.

### GitHub Username/password (Deprecated)

The user name is provided via the `--github-user` option or the GITHUB\_USER environment variable.  The default value for  GITHUB\_USER is the value of `--project` suffixed with QA.  For example,
`--project=yetus` will set `GITHUB_USER=yetusqa`.

The password is provided via the `--github-password` or GITHUB\_PASSWD environment variable.

Both username and password options must be provided.

# GitLab Specific

GitLab supports the full range of functionality, including putting comments on individual lines.  Be aware, however, that `test-patch` will (generally) require that GitLab MRs be fully squashed and rebased (i.e., a single commit) in many circumstances.

By default, the GitLab plug-in assumes that <https://gitlab.com> is the base URL for GitLab.  Enterprise users may override this with the `--gitlab-base-url` for the normal web user interface and `--gitlab-api-url` for the API URL.  Personalities may use GITLAB\_API\_URL and GITLAB\_BASE\_URL.

The specific repository on GitLab is defined with either `--gitlab-repo` on the command line or GITLAB\_REPO in a personality.  It should take the form of "user/repo".

In order to comment on issues or, depending upon the security setup of the repo, authentication credentials.  The GitLab plug-in supports tokens via the `--gitlab-token` option or GITLAB\_TOKEN environment variable.

GitLab merge requests may be directly processed on the command line in two ways:

* GL:(MR number)
* GLSHA:(MR SHA1 number)

The GitLab bugsystem plugin will attempt to download the unified diff that the merge request references.
Merge requests that are made off of a specific branch will switch the test repo to that branch, if permitted.  If the merge request references a JIRA issue that matches the given JIRA issue regexp in the Subject, the JIRA plug-in will also be invoked as needed.

# JIRA Specific

JIRA support allows both patch downloads and summary writes.  It also supports branch detection-based upon the name of the attached patch file.

JIRA issues are invoked by matching the command line option to a specific regular expression as given by the `--jira-issue-re` option or via the JIRA\_ISSUE\_RE personality variable.  By default, the plug-in uses <https://issues.apache.org/jira> as the JIRA instance to use.  However that may be overwritten via the `--jira-base-url` option or personalities may define via JIRA\_URL.

In order to write information on the issue, JIRA requires username and password authentication using the `--jira-user`/`--jira-password` options or the JIRA\_USER and JIRA\_PASSWORD variables in a personality.

The default value for JIRA\_USER is the value of `--project` suffixed with QA.  For example,
`--project=yetus` will set `JIRA_USER=yetusqa`.