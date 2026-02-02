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

# Robots: GitHub Actions

GitHub Action support is available in two different ways.  There are some settings common to both:

* Annotations will be used to mark problems in the files for those plug-ins that support this feature and
if `--linecomments` has `github` as a configured bug system (the default).
* Statuses will be added if the GitHub Token gives permission.
* Job Summary will be written with a Markdown-formatted report of the test results, visible directly on the
workflow run page without downloading artifacts.

## Workflow Action

The Apache Yetus community makes available a built-in action that may be executed as part of a
standard GitHub Action workflow. The basic workflow file should look like this, changing [VERSION] to
either be a released version (or `main` to use the bleeding edge, untested, and potentially unstable release):

```yaml
---
name: Apache Yetus

on: [push, pull_request]  # yamllint disable-line rule:truthy

jobs:
  build:

    runs-on: ubuntu-latest

    steps:
      - name: checkout
        uses: actions/checkout@v3
        with:
          path: src
          fetch-depth: 0
      - name: Apache Yetus test-patch
        uses: apache/yetus-test-patch-action@[VERSION]
        with:
          basedir: ./src
          patchdir: ./out
          buildtool: nobuild
          githubtoken: ${{ secrets.GITHUB_TOKEN }}
      - name: Artifact output
        if: ${{ always() }}
        uses: actions/upload-artifact@v3
        with:
          name: apacheyetuspatchdir
          path: ${{ github.workspace }}/out
```

Currently, not all arguments and parameters that can be set on the `test-patch` command line are available to set via the workflow action.
Options currently supported are:

| Option  |        Notes                 | Default | More Information |
|:-------:|:----------------------------:|:-------:|:----------------:|
| basedir | same as `--basedir`          | NONE    | [Usage Introduction](../../usage-intro) |
| blankseolignorefile | same as `--blanks-eol-ignore-file`          | `.yetus/blanks-eol.txt`  | [blanks plug-in](../../plugins/blanks) |
| blankstabsignorefile | same as `--blanks-tabs-ignore-file`          | `.yetus/blanks-tabs.txt`  | [blanks plug-in](../../plugins/blanks) |
| bufbasedir | same as `--buf-basedir`      | `.`    | [buf plug-in](../../plugins/buf) |
| buildtool | same as `--build-tool`     | `nobuild`  | [Build Tools](../../buildtools) |
| continuousimprovement | same as `--continuous-improvement` | false  | [Robots](..) |
| excludes | same as `--excludes`        | `.yetus/excludes.txt`  | [Usage Introduction](../../usage-intro) |
| githubtoken | same as `--github-token` | NONE  | [GitHub plug-in](../../plugins/github) |
| javahome | same as `--java-home`          | `/usr/lib/jvm/java-11-openjdk-amd64`  | [Java-related plug-ins](../../plugins/javac) |
| patchdir | same as `--patch-dir`       | NONE  |[Usage Introduction](../../usage-intro) |
| pip | same as `--pylint-pip`              | pip3  |  [pylint plug-in](../../plugins/pylint) |
| plugins | same as `--plugins`             | all,-asflicense,-author,-findbugs,-gitlab,-jira,-shelldocs   | [Usage Introduction](../../usage-intro) |
| project | same as `--project`             | Auto-set based upon the repository name  | [Usage Introduction](../../usage-intro) |
| pylint | same as `--pylint`               | pylint3  | [pylint plug-in](../../plugins/pylint) |
| reapermode | same as `--reapermode`       | kill  | [Advanced Usage](../../advanced) |
| reviveconfig | same as `--revive-config`  | `.revive.toml`  | [revive plug-in](../../plugins/revive) |
| testsfilter | same as `--tests-filter`  | '' | [Usage Introduction](../../usage-intro) |

Items marked NONE *MUST* be provided in the workflow yaml file.

Some options are hard-coded to make `test-patch` easier to use:

| Argument | Value | More Information |
|:--------:|:------:|:----------------:|
| `--brief-report-file` | patchdir/brief.txt | [briefreport plug-in](../../plugins/briefreport) |
| `--console-report-file` | patchdir/console.txt | [QBT](../../qbt) |
| `--html-report-file` | patchdir/report.html | [htmlout plug-in](../../plugins/htmlout) |
| `--ignore-unknown-options` | true | [Usage Introduction](../../usage-intro) |
| `--junit-report-xml` | patchdir/junit-report.xml | [junit plug-in](../../plugins/junit-bugsystem) |
| `--pylint-requirements` | true | [pylint plug-in](../../plugins/pylint) |
| `--report-unknown-options` | false | [Usage Introduction](../../usage-intro) |

## Manual Configuration

Manual configuration is recommended if one needs significant customization over the test environment and `test-patch` flags.

TRIGGER: ${GITHUB_ACTIONS}=True

GitHub Actions support has only been tested on the ubuntu-latest image. It automatically configures `--patch-dir` to be `${GITHUB_WORKSAPCE}/yetus` if not previously set.

## Job Summary

When running under GitHub Actions, Apache Yetus automatically writes a summary of the test results to the
[Job Summary](https://github.blog/2022-05-09-supercharging-github-actions-with-job-summaries/). This provides
immediate visibility of pass/fail status and details directly on the workflow run page, without needing to
download artifacts or parse log files.

The Job Summary includes:

* Overall pass/fail status with vote counts
* Vote table showing each subsystem's result, runtime, and comments
* Failed tests section (if any tests failed)
* Links to log files (if artifact URLs are available)

This feature requires no configuration and is automatically enabled when the `GITHUB_STEP_SUMMARY` environment
variable is present (which GitHub Actions sets automatically).

See also:

* Apache Yetus' [workflow action source](https://github.com/apache/yetus-test-patch-action) for lower level details on the workflow action implementation.
* Apache Yetus' source tree [yetus.yaml](https://github.com/apache/yetus/blob/main/.github/workflows/yetus.yml) for some tips and tricks.
