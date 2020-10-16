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

# Basic Precommit

<!-- MarkdownTOC levels="1,2,3" autolink="true" indent="  " bullets="*" bracket="round" -->

* [Purpose](#purpose)
* [Goals](#goals)
* [Pre-requisites](#pre-requisites)
  * [Base Requirements](#base-requirements)
  * [Plug-ins](#plug-ins)
    * [Bundled Plug-ins](#bundled-plug-ins)
    * [Optional Plug-ins](#optional-plug-ins)
* [Related Utilities](#related-utilities)
* [More information](#more-information)

<!-- /MarkdownTOC -->

# Purpose

Performing reviews can be an overwhelming process.  The more complex the base, the more comprehensive reviews end up.  Building that functionality into the build itself is a full time job. When a new check is added there is a good chance the existing code has problems and often maintainers just want to prevent new bits from making the existing problem worse.

This is where Apache Yetus' precommit utilities come into the picture.

All patches to the source base go through a test that does some (relatively) light checking to make sure the proposed change does not break unit tests and/or passes some other prerequisites such as code formatting guidelines.  This is meant as a preliminary check for reviewers so that the basic patch is in a known state and for contributors to know if they have followed the project's guidelines.  This check may also be used by individual developers to verify a patch prior to sending to the QA systems.

# Goals

* Everyone's time is valuable.  The quicker contributors can get feedback and iterate, the more likely and faster their contribution will get checked in.  A committer should be able to focus on the core issues of a contribution rather than details that can be determined automatically.
* Checks should be fast.  There is no value in testing parts of the source tree that are not immediately impacted by a change.  Unit testing is the target. They are not a replacement for full builds or integration tests.
* In many build systems (e.g., maven), a modular design has been picked.  This modularity should be exploited to reduce the amount of checks that need to be performed.
* Projects that use the same language will, with a high degree of certainty, benefit from the same types of checks.
* Portability matters.  Tooling should be as operating system and language agnostic as possible.

# Pre-requisites

Almost all of the precommit components are written in bash for maximum portability.  As such, it mostly assumes the locations of commands to be in the file path. However, in many cases, this assumption may be overridden via command line options.

## Base Requirements

These components are expected to be in-place for basic execution:

* git-based project (and git 1.7.3 or higher installed)
* bash v3.2 or higher (bash v4.0 or higher is recommended)
* GNU diff
* GNU patch
* POSIX awk
* POSIX grep
* POSIX sed
* [curl](https://curl.haxx.se/) command
* file command

For Solaris and Solaris-like operating systems, the default location for the POSIX binaries is in `/usr/xpg4/bin` and the default location for the GNU binaries is `/usr/gnu/bin`.

## Plug-ins

Features are plug-in based and enabled either individually or collectively on the command line. From there, these are activated based upon tool availability, the languages being tested, etc.  The external dependencies of plug-ins may have different licensing requirements than Apache Yetus.

### Bundled Plug-ins

These plug-ins are native to Apace Yetus and are (usually!) always available:

* [author](plugins/author)
* [blanks](plugins/blanks)
* [briefreport](plugins/briefreport)
* [dupname](plugins/dupname)
* [htmlout](plugins/htmlout)
* [nobuild](plugins/nobuild)
* [pathlen](plugins/pathlen)
* [slack](plugins/slack)
* [unitveto](plugins/unitveto)
* [xml](plugins/xml)

### Optional Plug-ins

[Bug Systems](bugsystems):

* [Bugzilla](plugins/bugzilla)-based issue tracking (Read Only)
* [GitHub](plugins/github)-based issue tracking
* [Gitlab](plugins/gitlab)-based issue tracking
* [JIRA](plugins/jira)-based issue tracking

[Build Tools](buildtools):

* [ant](plugins/ant)
* [autoconf](plugins/autoconf)
* [cmake](plugins/cmake)
* [gradle](plugins/gradle)
* [maven](plugins/maven)
* [make](plugins/make)

Automation and Isolation:

* [Azure Pipelines](robots/azurepipelines)
* [Circle CI](robots/circleci)
* [Cirrus CI](robots/cirrusci)
* [Docker](docker) version 1.7.0+
* [Github Actions](robots/githubactions)
* [Gitlab CI](robots/gitlabci)
* [Jenkins](robots/jenkins)
* [Semaphore CI](robots/semaphoreci)
* [Travis CI](robots/travisci)

[Unit Test Formats](testformats):

* [ctest](plugins/ctest)
* JUnit, as [input](plugins/junit-testformat) and [output](plugins/junit-bugsystem)
* [TAP](plugins/tap)

Compiler Support:

* [C/C++](plugins/cc)
* [Go](plugins/golang)
* Java, both [javac](plugins/javac) and [javadoc](plugins/javadoc)
* Scala, both [scalac](plugins/scalac) and [scaladoc](plugins/scaladoc)

Language Support, Licensing, and more:

* [Apache Creadur Rat](plugins/asflicense)
* [buf](plugins/buf)
* [checkmake](plugins/checkmake)
* [checkstyle](plugins/checkstyle)
* [FindBugs](plugins/findbugs)
* [golangci-lint](plugins/golangcilint)
* [hadolint](plugins/hadolint)
* [jshint](plugins/jshint)
* [markdownlint-cli](plugins/markdownlint)
* [Perl::Critic](plugins/perlcritic)
* [pylint](plugins/pylint)
* [revive](plugins/revive)
* [rubocop](plugins/rubocop)
* [shellcheck](plugins/shellcheck)
* [SpotBugs](plugins/spotbugs)
* [yamllint](plugins/yamllint)

# Related Utilities

`precommit` also comes with some utilities that are useful in various
capacities without needing to use the full `test-patch` runtime:

* [docker-cleanup](docker-cleanup) - safe removal of Docker resources for multi-executor CI systems
* [jenkins-admin](admin) - Jenkins<->JIRA patch bridge
* [qbt](qbt) - Quality Build Tool, for branch-specific testing
* [smart-apply-patch](smart-apply-patch) - CLI manipulation and query of patch files, PRs, and more

# More information

* [Usage Introduction](usage-intro)
* [Advanced Usage Guide](advanced)
* [Internal Architecture](architecture)
* Various Subsystems:
  * [build systems](buildtools)
  * [bug systems](bugsystems)
  * [continuous integration system support](robots)
  * [test formats](testformats)
* Detailed [Docker](docker) information
* [Generated API documentation](apidocs/)
* [Glossary](glossary)
