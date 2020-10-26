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

# releasedocmaker

<!-- MarkdownTOC levels="1,2" autolink="true" indent="  " bullets="*" bracket="round" -->

* [Purpose](#purpose)
* [Requirements](#requirements)
* [Basic Usage](#basic-usage)
* [Authentication](#authentication)
* [Changing the Header](#changing-the-header)
* [Versioned Files and Directories](#versioned-files-and-directories)
* [Multiple Versions](#multiple-versions)
* [Unreleased Dates](#unreleased-dates)
* [Sorted Output](#sorted-output)
  * [Resolution Date-base Sort](#resolution-date-base-sort)
  * [Issue Number-based Sort](#issue-number-based-sort)
* [Backward Incompatible Changes](#backward-incompatible-changes)
* [Lint Mode](#lint-mode)
* [Index Mode](#index-mode)
* [Release Version](#release-version)

<!-- /MarkdownTOC -->

# Purpose

Building changelog information in a form that is human digestible but still containing as much useful information is difficult.  Many attempts over the years have resulted in a variety of methods that projects use to solve this problem:

* JIRA-generated release notes from the "Release Notes" button
* Manually modified CHANGELOG file
* Processing git log information

All of these methods have their pros and cons.  Some have issues with accuracy.  Some have issues with lack of details. None of these methods seem to cover all of the needs of many projects and are full of potential pitfalls.

In order to solve these problems, `releasedocmaker` was written to automatically generate a changelog and release notes by querying Apache's JIRA instance.

# Requirements

* Python 2.7 with dateutil extension

dateutil may be installed via pip:  `pip2 install python-dateutil`

# Basic Usage

Minimally, the name of the JIRA project and a version registered in JIRA must be provided:

```bash
$ releasedocmaker --project (project) --version (version)
```

This will query Apache JIRA, generating two files in a directory named after the given version in an extended markdown format which can be processed by both mvn site and GitHub.

* CHANGELOG.md

This is similar to the JIRA "Release Notes" button but is in tabular format and includes the priority, component, reporter, and contributor fields.  It also highlights Incompatible Changes so that readers know what to look out for when upgrading. The top of the file also includes the date that the version was marked as released in JIRA.

* RELEASENOTES.md

If your JIRA project supports the release note field, this will contain any JIRA mentioned in the `CHANGELOG` that is either an incompatible change or has a release note associated with it.  If your JIRA project does not support the release notes field, this will be the description field.

For example, to build the release documentation for HBase v1.2.0:

```bash
$ releasedocmaker --project HBASE --version 1.2.0
```

By default, release notes are expected to be in plain text.  However, you can write them in markdown if you include a header at the top of your release note:

```xml
<!-- markdown -->
remaining text
```

# Authentication

`releasedocmaker` supports very simple Basic authentication.  This is accomplished by adding two environment variables to your shell environment:

```bash
RDM_JIRA_USERNAME='jirausername'
RDM_JIRA_PASSWORD='jirapassword'
```

These values will be added to all requests destined for the JIRA server.

# Changing the Header

By default, it will use a header that matches the project name.  But that is kind of ugly and the case may be wrong.  Luckily, the title can be changed:

```bash
$ releasedocmaker --project HBASE --version 1.2.0 --projecttitle "Apache HBase"
```

Now instead of "HBASE", it will use "Apache HBase" for some titles and headers.

# Versioned Files and Directories

It is sometimes useful to create the `CHANGELOG` and `RELEASENOTES` with versions attached.  `releasedocmaker` supports both independently.

```bash
$ releasedocmaker --project HBASE --version 1.2.0 --fileversions
```

This command line will now create `CHANGELOG.1.2.0.md` and `RELEASENOTES.1.2.0.md` files.

```bash
$ releasedocmaker --project HBASE --version 1.2.0 --dirversions
```

This command line will now create a directory called 1.2.0 and inside will be the `CHANGELOG.md` and `RELEASENOTES.md` files.

Using both at the same time...

```bash
$ releasedocmaker --project HBASE --version 1.2.0 --fileversions --dirversions
```

... results in `1.2.0/CHANGELOG.1.2.0.md` and `1.2.0/RELEASENOTES.1.2.0.md` files.

# Multiple Versions

Using either `--dirversions` or `--fileversions` or both simultaneously, `releasedocmaker` can also generate multiple versions at once

```bash
$ releasedocmaker --project HBASE --version 1.0.0 --version 1.2.0 --dirversions
```

This will create the files for versions 1.0.0 and versions 1.2.0 in their own directories.

But what if the version numbers are not known?  `releasedocmaker` can also generate version data based upon ranges:

```bash
$ releasedocmaker --project HBASE --version 1.0.0 --version 1.2.0 --range --fileversions
```

In this form, `releasedocmaker` will query JIRA, discover all versions that alphabetically appear to be between 1.0.0 and 1.2.0, inclusive, and generate all of the relative release documents.  This is especially useful when bootstrapping an existing project.

# Unreleased Dates

For released versions, releasedocmaker will pull the date of the release from JIRA.  However, for unreleased versions it marks the release as "Unreleased". This can be inconvenient when actually building a release and wanting to include it inside the source package.

The `--usetoday` option can be used to signify that instead of using Unreleased, `releasedocmaker` should use today's date.

```bash
$ releasedocmaker --project HBASE --version 1.0.0 --usetoday
```

After using this option and release, don't forget to change JIRA's release date to match!

# Sorted Output

Different projects may find one type of sort better than another, depending upon their needs.  `releasedocmaker` supports two types of sorts and each provides two different options in the direction for that sort.

## Resolution Date-base Sort

By default, `releasedocmaker` will sort the output based upon the resolution date of the issue starting with older resolutions.  This is the same as giving these options:

```bash
$ releasedocmaker --project falcon --version 0.6 --sorttype resolutiondate --sortorder older
```

The order can be reversed so that newer issues appear on top by providing the 'newer' flag:

```bash
$ releasedocmaker --project falcon --version 0.6 --sorttype resolutiondate --sortorder newer
```

In the case of multiple projects given on the command line, the projects will be interspersed.

## Issue Number-based Sort

An alternative to the date-based sort is to sort based upon the issue id.  This may be accomplished via:

```bash
$ releasedocmaker --project falcon --version 0.6 --sorttype issueid --sortorder asc
```

This will now sort by the issue id, listing them in lowest to highest (or ascending) order.

The order may be reversed to list them in highest to lowest (or descending) order by providing the appropriate flag:

```bash
$ releasedocmaker --project falcon --version 0.6 --sorttype issueid --sortorder desc
```

In the case of multiple projects given on the command line, the projects will be grouped and then sorted by issue id.

# Backward Incompatible Changes

To check if an issue is backward-incompatible the `releasedocmaker` script first checks the "Hadoop Flags" field in the
issue. If this field is found to be blank then it searches for the 'backward-incompatible' label. You can override the
default value for this label by using `--incompatiblelabel` option e.g.

```bash
$ releasedocmaker --project falcon --version 0.6 --incompatiblelabel not-compatible
```

or equivalently using the shorter `-X` option

```bash
$ releasedocmaker --project falcon --version 0.6 -X not-compatible
```

# Lint Mode

In order to ensure proper formatting while using mvn site, `releasedocmaker` puts in periods (.) for fields that are empty or unassigned.  This can be unsightly and not proper for any given project.  There are also other things, such as missing release notes for incompatible changes, that are less than desirable.

In order to help release managers from having to scan through potentially large documents, `releasedocmaker` features a lint mode, triggered via `--lint`:

```bash
$ releasedocmaker --project HBASE --version 1.0.0 --lint
```

This will do the normal JIRA querying, looking for items it considers problematic.  It will print the information to the screen and then exit with either success or failure, depending upon if any issues were discovered.

# Index Mode

There is basic support for an autoindexer.  It will create two files that contain links to all directories that have a major.minor\*-style
version numbering system.
For example directories with names like 0.6, 1.2.2, 1.2alpha etc. will all be linked.

* `index.md`: a file suitable for conversion to HTML via mvn site
* `README.md`: a file suitable for display on Github and other Markdown rendering websites

# Release Version

You can find the version of the `releasedocmaker` that you are using by giving the `-V` option. This may be helpful in finding documentation for the version you are using.

```bash
$ releasedocmaker -V
```
