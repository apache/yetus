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

test-patch
==========

* [Purpose](#purpose)
* [Pre-requisites](#pre-requisites)
* [Basic Usage](#basic-usage)
* [Automation](#automation)
* [Build Tool](#build-tool)
* [Providing Patch Files](#providing-patch-files)
* [Project-Specific Capabilities](#project-specific-capabilities)
* [MultiJDK](#multijdk)
* [Docker](#docker)
* [In Closing](#in-closing)

# Purpose

As part of Apache Hadoop's commit process, all patches to the source base go through a precommit test that does some (relatively) light checking to make sure the proposed change does not break unit tests and/or passes some other prerequisites such as code formatting guidelines.  This is meant as a preliminary check for committers so that the basic patch is in a known state and for contributors to know if they have followed the project's guidelines.  This check, called test-patch, along with a helper program, called smart-apply-patch, may also be used by individual developers to verify a patch prior to sending to the Apache Hadoop QA systems.

Other projects have adopted a similar methodology after seeing great success in the Apache Hadoop model.  Some have even gone as far as forking Apache Hadoop's precommit code and modifying it to meet their project's needs.

One of the key facets of Apache Yetus is to bring together all of these forks under a common code base to help software development
as a whole.


# Pre-requisites

test-patch and smart-apply-patch are written in bash for maximum portability.  As such, it mostly assumes the locations of commands to be in the file path. However, in many cases, this assumption may be overridden via command line options.

For Solaris and Solaris-like operating systems, the default location for the POSIX binaries is in /usr/xpg4/bin and the default location for the GNU binaries is /usr/gnu/bin.

## Base Requirements

test-patch requires these installed components to execute:

* git-based project (and git 1.7.3 or higher installed)
* bash v3.2 or higher
* GNU diff
* GNU patch
* POSIX awk
* POSIX grep
* POSIX sed
* [curl](http://curl.haxx.se/) command
* file command

## Optional Requirements

Features are plug-in based and enabled either individually or collectively on the command line. From there, these are activated based upon tool availability, the languages being tested, etc.  The external dependencies of plug-ins may have different licensing requirements than Apache Yetus.

Bug Systems:

* [GitHub](https://github.com/)-based issue tracking
* [JIRA](https://www.atlassian.com/software/jira)-based issue tracking
* [Bugzilla](https://www.bugzilla.org/)-based issue tracking (Read Only)

Build Tools:

* [ant](https://ant.apache.org)
* [autoconf](https://www.gnu.org/software/autoconf/autoconf.html)
* [cmake](https://www.cmake.org)
* [gradle](https://www.gradle.org)
* make
* [maven](https://maven.apache.org)

Automation and Isolation:

* [Docker](https://www.docker.com) version 1.6.0+
* [Jenkins](https://www.jenkins-ci.org)

Unit Test Formats:

* [ctest](https://cmake.org/Wiki/CMake/Testing_With_CTest)
* [JUnit](http://junit.org/)
* [TAP](https://testanything.org/)

Language Support, Licensing, and more:

* [Apache Creadur Rat](http://creadur.apache.org/rat/) entries in build system
* [checkstyle](http://checkstyle.sourceforge.net/) entries in build system (ant and maven only)
* [FindBugs](http://findbugs.sourceforge.net/) entries in build system and 3.x executables
* [Perl::Critic](http://perlcritic.com/) installed
* [pylint](http://www.pylint.org/) installed
* [rubocop](http://batsov.com/rubocop/) installed
* [ruby-lint](https://github.com/YorickPeterse/ruby-lint) installed
* [shellcheck](https://github.com/koalaman/shellcheck) installed, preferably 0.3.6 or higher

# Basic Usage

The first step for a successful deployment is determining which features/plug-ins to enable:

```bash
$ test-patch.sh --list-plugins
```

This option will list all of the available plug-ins that are installed in the default location.  From this list, the specific plug-ins can be enabled:

```bash
$ test-patch.sh --plugins="ant,maven,shellcheck,xml" <other options>
```

As a short-cut, every plug-in may be enabled via the special 'all' type:

```bash
$ test-patch.sh --plugins="all" <other options>
```

`--plugins` also allows some basic "arithmetic":

```bash
$ test-patch.sh --plugins="all,-checkstyle,-findbugs" <other options>
```

This will enable all plug-ins for potential usage, except for checkstyle and findbugs.

**NOTE: The examples in this section will assume that the necessary `--plugins` option has been set on the command line as appropriate for your particular installation.**

This command will execute basic patch testing against a patch file stored in "filename":

```bash
$ cd <your repo>
$ test-patch.sh --dirty-workspace --project=projectname <filename>
```

The `--dirty-workspace` flag tells test-patch that the repository is not clean and it is ok to continue.  By default, unit tests are not run since they may take a significant amount of time.

To do turn them on, we need to provide the --run-tests option:


```bash
$ cd <your repo>
$ test-patch.sh --dirty-workspace --run-tests <filename>
```

This is the same command, but now runs the unit tests.

A typical configuration is to have two repositories.  One with the code you are working on and another, clean repository.  This means you can:

```bash
$ cd <workrepo>
$ git diff master > /tmp/patchfile
$ cd ../<testrepo>
$ test-patch.sh --basedir=<testrepo> --resetrepo /tmp/patchfile
```

We used two new options here.  --basedir sets the location of the repository to use for testing.  --resetrepo tells test patch that it can go into **destructive** mode.  Destructive mode will wipe out any changes made to that repository, so use it with care!

# Automation

After the tests have run, there is a directory that contains all of the test-patch related artifacts.  This is generally referred to as the patchprocess directory.  By default, test-patch tries to make something off of /tmp to contain this content.  Using the `--patch-dir` option, one can specify exactly which directory to use.  This is helpful for automated precommit testing so that Jenkins or other automated workflow system knows where to look to gather up the output.

For example:

```bash
$ test-patch.sh --robot --patch-dir=${WORKSPACE}/patchprocess --basedir=${WORKSPACE}/source ${WORKSPACE}/patchfile
```

... will trigger test-patch to run in fully automated mode, using ${WORKSPACE}/patchprocess as its scratch space, ${WORKSPACE}/source as the source repository, and ${WORKSPACE}/patchfile as the name of the patch to test against.  This will always run the unit tests, write answers back to bug systems, remove old, stopped/exited Docker containers after 24 hours and images after 1 week, forcibly use --resetrepo, and more.

**NOTE: Make sure to add the patch directory to `.gitignore` if the directory is inside the source tree to avoid deleting it, as `test-patch` does a `git clean` to remove untracked files from previous runs.**

The --build-url option is also useful when running in --robot mode so that emails and such
have a location to look at the output artifacts:

```bash
$ test-patch.sh --robot --build-url=http://server.example.name:80/${buildnumber}/
```

Some plug-ins such as Maven have special handling if there are multiple executions of test-patch happening at once.  It is very common when using automation systems to have multiple runs on the same host. In order to assist these plug-ins, an instance identifier may be provided:

```bash
$ test-patch.sh --robot --instance=1
```

If --robot is specified without an instance, a random number is generated and used.

There is some special handling if Jenkins is actually your automation tool.  Instead of using --robot, use --jenkins:

```bash
$ test-patch.sh --jenkins --patch-dir=${WORKSPACE}/patchprocess --basedir=${WORKSPACE}/source ${WORKSPACE}/patchfile
```

This will enable --robot, set the --build-url option from the ${BUILD_URL} environment variable, and the instance identifier is set to the ${EXECUTOR_NUMBER}.

If stuck containers are a problem, a more aggressive robot may be enabled with the --sentinel option.  This option enables killing containers that have been running for over 24 hours as well.

# Build Tool

Out of the box, test-patch is built to use maven.  But what if the project is built using something else, such as ant?

```bash
$ test-patch.sh (other options) --build-tool=ant
```

will tell test-patch to use ant instead of maven to drive the project.

# Providing Patch Files

## JIRA

It is a fairly common practice within the Apache community to use Apache's JIRA instance to store potential patches.  As a result, test-patch supports providing just a JIRA issue number.  test-patch will find the *last* attachment, download it, then process it.

**NOTE: test-patch expects the patch files to follow a particular naming convention. For complete details
 on the naming convention please refer to [patch-naming-conventions](./precommit-patchnames/)**

For example:

```bash
$ test-patch.sh (other options) HADOOP-9905
```

... will process the patch file associated with this JIRA issue.

If the Apache JIRA system is not in use, then override options may be provided on the command line to point to a different JIRA instance.

```bash
$ test-patch.sh --jira-issue-re='^PROJECT-[0-9]+$' --jira-base-url='https://example.com/jira' PROJECT-90
```

... will process the patch file attached to PROJECT-90 on the JIRA instance located on the example.com server.

## GITHUB

test-patch has some basic support for Github.  test-patch supports many forms of providing pull requests to work on:

```bash
$ test-patch.sh --github-repo=apache/pig GH:99
```

or

```bash
$ test-patch.sh https://github.com/apache/pig/pulls/99
```

or

```bash
$ test-patch.sh https://github.com/apache/pig/pulls/99.patch
```

... will process PR #99 on the apache/pig repo.

## Generic URLs

Luckily, test-patch supports ways to provide unified diffs via URLs.

For example:

```bash
$ test-patch.sh (other options) https://example.com/webserver/file.patch
```

... will download and process the file.patch from the example.com webserver.

# Project-specific Capabilities

Due to the extensible nature of the system, test-patch allows for projects to define project-specific rules which we call personalities.  (How to build those rules is covered elsewhere.) There are two ways to specify which personality to use:

## Direct Method

```bash
$ test-patch.sh (other options) --personality=(filename)
```

This tells test-patch to use the personality in the given file.

## Project Method

However, test-patch can detect if it is a personality that is in its "personality" directory based upon the project name:

```bash
$ test-patch.sh (other options) --project=(project)
```

# MultiJDK

For many projects, it is useful to test Java code against multiple versions of JDKs at the same time.  test-patch can do this with the --multijdkdirs option:

```bash
$ test-patch.sh (other options) --multijdkdirs="/j/d/k/1,/j/d/k/2"
```

Not all Java tests support this mode, but those that do will now run their tests with all of the given versions of Java consecutively (e.g., javac--the Java compliation test).  Tests that do not support MultiJDK mode (e.g., checkstyle, mvn install) will use JAVA\_HOME.

NOTE: JAVA\_HOME is always appended to the list of JDKs in MultiJDK mode.  If JAVA\_HOME is in the list, it will be moved to the end.

# Docker

test-patch also has a mode to utilize Docker:

```bash
$ test-patch.sh (other options) --docker
```

This will do some preliminary setup and then re-execute itself inside a Docker container.  For more information on how to provide a custom Dockerfile, see the advanced guide.

## In Closing

test-patch has many other features and command line options for the basic user.  Many of these are self-explanatory.  To see the list of options, run test-patch.sh without any options or with --help.
