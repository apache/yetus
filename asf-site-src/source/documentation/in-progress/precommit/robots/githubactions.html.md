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

## Workflow Action

The Apache Yetus community makes available a built-in action that may be executed as part of a standard GitHub Action workflow.
The basic workflow file should look like this, changing [VERSION] to either be a released version (or `main` to use the
bleeding edge, untested, and potentially unstable release):

```yaml
---
name: Apache Yetus

on: [push, pull_request]  # yamllint disable-line rule:truthy

jobs:
  build:

    runs-on: ubuntu-latest

    steps:
      - name: checkout
        uses: actions/checkout@v2
        with:
          path: src
          fetch-depth: 0
      - name: Apache Yetus test-patch
        uses: apache/yetus-test-patch-action@[VERSION]
        with:
          basedir: ./src
          patchdir: ./out
          buildtool: nobuild
      - name: Artifact output
        if: ${{ always() }}
        uses: actions/upload-artifact@v2
        with:
          name: apacheyetuspatchdir
          path: ${{ github.workspace }}/out
```

Currently, not all arguments and parameters that can be set on the `test-patch` command line are available to set via the workflow action.
Options currently supported are:

| Option  |        Notes                 | Default |
|:-------:|:----------------------------:|:-------:|
| basedir | same as `--basedir`          | NONE    |
| buildtool | same as `--build-tool`     | `nobuild` |
| continuousimprovement | same as `--continuous-improvement` | true |
| excludes | same as `--excludes`        | `.yetus-excludes.txt` |
| githubtoken | same as `--github-token` | NONE    |
| patchdir | same as `--patch-dir`       | NONE    |
| pip | same as `--pylint-pip`           | pip3 |
| plugins | same as `--plugins`          | all,-asflicense,-author,-findbugs,-gitlabcilint,-shelldocs |
| pylint | same as `--pylint`            | pylint3 |
| reapermode | same as `--reapermode`    | kill |

Items marked NONE *MUST* be provided in the workflow yaml file.

Some options are hard-coded to make `test-patch` easier to use:

| Argument | Value |
|:--------:|:------:|
| `--brief-report-file` | patchdir/brief.txt |
| `--console-report-file` | patchdir/console.txt |
| `--html-report-file` | patchdir/report.html |
| `--junit-report-xml` | patchdir/junit-report.xml |
| `--pylint-requirements` | true |

## Manual Configuration

Manual configuration is recommended if one needs significant customization over the test environment and `test-patch` flags.

TRIGGER: ${GITHUB_ACTIONS}=True

GitHub Actions support has only been tested on the ubuntu-latest image. It automatically configures `--patch-dir` to be `${GITHUB_WORKSAPCE}/yetus` if not previously set.

See also:

* Apache Yetus' [workflow action source](https://github.com/apache/yetus/test-patch-action) for lower level details on the workflow action implementation.
* Apache Yetus' source tree [yetus.yaml](https://github.com/apache/yetus/blob/main/.github/workflows/yetus.yml) for some tips and tricks.
