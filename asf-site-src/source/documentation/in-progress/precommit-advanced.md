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

* [Docker Support](#docker-support)
* [Plug-ins](#plug-ins)
* [Personalities](#personalities)
* [Important Variables](#important-variables)

# Docker Support

By default, test-patch runs in the same shell where it was launched.  It can alternatively use Docker to launch itself in a container.  This is particularly useful if running under a QA environment that does not provide all the necessary binaries. For example, if the patch requires a newer version of Java than what is installed on a Jenkins instance.

The `--docker` parameter tells test-patch to run in Docker mode. The `--dockerfile` parameter allows one to provide a custom Dockerfile. The Dockerfile should contain all of the necessary binaries and tooling needed to run the test.  test-patch will copy this file up until the text "YETUS CUT HERE" to a different directory and then append its necessary hooks to re-launch itself prior to executing docker.

If a custom Dockerfile cannot be used or the docker executable does not work, test-patch will attempt to recover by switching to its bundled Dockerfile or disabling docker support and running locally.  This behavior can be changed with the `--dockeronfail` option.  It takes a list of comma-delimited settings:

  * fallback - Use the bundled Dockerfile
  * continue - Turn off docker support
  * fail - fail the test

The 'fail' setting is always the last option that test-patch will use and may be omitted unless it is the only option.

For example, `--dockeronfail=continue` means if the Dockerfile can't be found, just turn off Docker support and continue running.  `--dockeronfail=fallback` will switch to the bundled Dockerfile and then fail the build if docker fails to work. `--dockeronfail=fail` means to just fail the build and do not try any other mechanisms of recovery. The default is 'fallback,continue,fail' which will allow test-patch to try to continue executing as much as it possibily can.

Be aware that if the Dockerfile is found and the docker command works, test-patch will always fail the build if the Dockerfile itself fails the build.  It will not attempt to continue in the non-Docker mode.

NOTE: If you are using Boot2Docker, you must use directories under /Users (OSX) or C:\Users (Windows) as the base and patchprocess directories (specified by the --basedir and --patch-dir options respectively), because automatically mountable directories are limited to them. See [the Docker documentation](https://docs.docker.com/userguide/dockervolumes/#mount-a-host-directory-as-a-data-volume).

Dockerfile images will be named with a test-patch prefix and suffix with either a date or a git commit hash. By using this information, test-patch will automatically manage broken/stale container images that are hanging around if it is run in --robot mode.  In this way, if Docker fails to build the image, the disk space should eventually be cleaned and returned back to the system.  The docker mode can also be run in a "safe" mode that prevents deletions via the `--dockerdelrep` option.  Specifying this option will cause test-patch to only report what it would have deleted, but not actually remove anything.

# Plug-ins

test-patch allows one to add to its basic feature set via plug-ins.  There is a directory called test-patch.d inside the directory where test-patch.sh lives.  Inside this directory one may place some bash shell fragments that, if setup with proper functions, will allow for test-patch to call it as necessary.  Different plug-ins have specific functions for that particular functionality.  In this document, the common functions available to all/most plug-ins are covered.  Test plugins are covered below. See other documentation for pertinent information for the other plug-in types.

## Common Plug-in Functions

Every plug-in must have one line in order to be recognized, usually an 'add' statement.  Test plug-ins, for example, have this statement:

```bash
add_test_type <pluginname>
```

This function call registers the `pluginname` so that test-patch knows that it exists.  Plug-in names must be unique across all the different plug-in types.  Additionally, the 'all' plug-in is reserved.  The `pluginname` also acts as the key to the custom functions that you can define. For example:

```bash
function pluginname_filefilter
```

defines the filefilter for the `pluginname` plug-in.

Similarly, there are other functions that may be defined during the test-patch run:

    HINT: It is recommended to make the pluginname relatively small, 10 characters at the most.  Otherwise, the ASCII output table may be skewed.

* pluginname\_usage
    - executed when the help message is displayed. This is used to display the plug-in specific options for the user.

* pluginname\_parse\_args
    - executed prior to any other above functions except for pluginname\_usage. This is useful for parsing the arguments passed from the user and setting up the execution environment.

* pluginname\_initialize
    - After argument parsing and prior to any other work, the initialize step allows a plug-in to do any precursor work, set internal defaults, etc.

* pluginname\_docker\_support
    - Perform any necessary setup to configure Docker support for the given plugin.  Typically this means adding parameters to the docker run command line via adding to the DOCKER\_EXTRAARGS array.

* pluginname\_precheck
    - executed prior to the patch being applied but after the git repository is setup.  Returning a fail status here will exit test-patch.

* pluginname\_patchfile
    - executed prior to the patch being applied but after the git repository is setup. This step is intended to perform tests on the content of the patch itself.

* pluginname\_precompile
    - executed prior to the compilation part of the lifecycle. This is useful for doing setup work required by the compilation process.

* pluginname\_postcompile
    - This step happens after the compile phase.

* pluginname\_rebuild
    - Any non-unit tests that require the source to be rebuilt in a destructive way should be run here.


## Plug-in Importation

Plug-ins are imported from several key directories:

* core.d is an internal-to-Yetus directory that first loads the basic Apache Yetus library, followed by the common routines used by all of the precommit shell code.  This order is dictated by prefixing the plug-in files with a number.  Other files in this directory are loaded in shell collated order.

* personality contains bundled personalities for various projects.  These will be imported individually based upon either a project name or if specifically identified with the `--personality` flag.

* test-patch.d contains all of the optional, bundled plug-ins.  These are imported last and in shell collated order.

If the `--skip-system-plugins` flag is passed, then only core.d is imported.

## Test Plug-ins

Plug-ins geared towards independent tests are registered via:


```bash
add_test_type <pluginname>
```

+ pluginname\_filefilter
    - executed while determining which files trigger which tests.  This function should use `add_test pluginname` to add the plug-in to the test list.

* pluginname\_compile
    - executed immediately after the actual compilation. This step is intended to be used to verify the results and add extra checking of the compile phase and it's stdout/stderr.

* pluginname\_tests
    - executed after the unit tests have completed.

* pluginname\_clean
    - executed to allow the plugin to remove all files that have been generate by this plugin.

* pluginname\_logfilter
    - This functions should filter all lines relevant to this test from the logfile. It is called in preparation for the `calcdiffs` function.

* pluginname\_calcdiffs

    - This allows for custom log file difference calculation used to determine the before and after views.  The default is to use the last column of a colon delimited line of output and perform a diff.  If the plug-in does not provide enough context, this may result in error skew. For example, if three lines in a row have "Missing period." as the error, test-patch will not be able to determine exactly which line caused the error.  Plug-ins that have this issue will want to use this or potentially modify the normal tool's output (e.g., checkstyle) to provide a more accurate way to determine differences.

  NOTE: If the plug-in has support for maven, the maven_add_install `pluginname` should be executed. See more information in Custom Maven Tests in the build tool documentation.

# Personalities

## Configuring for Other Projects

It is impossible for any general framework to be predictive about what types of special rules any given project may have, especially when it comes to ordering and Maven profiles.  In order to direct test-patch to do the correct action, a project `personality` should be added that enacts these custom rules.

A personality consists of two functions. One that determines which test types to run and another that allows a project to dictate ordering rules, flags, and profiles on a per-module, per-test run.

There can be only **one** of each personality function defined.

## Global Definitions

Globals for personalities should be defined in the `personality_globals` function.  This function is called *after* the other plug-ins have been imported.  This allows one to configure any settings for plug-ins that have been imported safely:

```bash
function personality_globals
{
  PATCH_BRANCH_DEFAULT=master
  GITHUB_REPO="apache/yetus"
}
```

## Test Determination

The `personality_file_tests` function determines which tests to turn on based upon the file name.  It is relatively simple.  For example, to turn on a full suite of tests for Java files:

```bash
function personality_file_tests
{
  local filename=$1

  if [[ ${filename} =~ \.java$ ]]; then
    add_test findbugs
    add_test javac
    add_test javadoc
    add_test mvninstall
    add_test unit
  fi

}
```

The `add_test` function is used to activate the standard tests.  Additional plug-ins (such as checkstyle), will get queried on their own.

## Module & Profile Determination

Once the tests are determined, it is now time to pick which [modules](precommit-glossary.md#genericoutside-definitions) should get used.  That's the job of the `personality_modules` function.

```bash
function personality_modules
{

    clear_personality_queue

...

    personality_enqueue_module <module> <flags>

}
```

It takes exactly two parameters `repostatus` and `testtype`.

The `repostatus` parameter tells the `personality` function exactly what state the source repository is in.  It can only be in one of two states:  `branch` or `patch`.  `branch` means the patch has not been applied.  The `patch` state is after the patch has been applied.

The `testtype` state tells the personality exactly which test is about to be executed.

In order to communicate back to test-patch, there are two functions for the personality to use.

The first is `clear_personality_queue`. This removes the previous test's configuration so that a new module queue may be built. Custom `personality_modules` will almost always want to do this as the first action.

The second is `personality_enqueue_module`.  This function takes two parameters.  The first parameter is the name of the module to add to this test's queue.  The second parameter is an option list of additional flags to pass to Maven when processing it. `personality_enqueue_module` may be called as many times as necessary for your project.

    NOTE: A module name of . signifies the root of the repository.

For example, let's say your project uses a special configuration to skip unit tests (-DskipTests).  Running unit tests during a javadoc build isn't very useful and wastes a lot of time. We can write a simple personality check to disable the unit tests:

```bash
function personality_modules
{
    local repostatus=$1
    local testtype=$2

    if [[ ${testtype} == 'javadoc' ]]; then
        personality_enqueue_module . -DskipTests
        return
    fi
    ...

```

This function will tell test-patch that when the javadoc test is being run, do the documentation build at the base of the source repository and make sure the -DskipTests flag is passed to our build tool.

## Enabling Plug-ins

Personalities can set the base list of plug-ins to enable and disable for their project via the `personality_plugins` function. Just call it with the same pattern as the `--plugins` command line option:

```bash
personality_plugins "all,-checkstyle,-findbugs,-asflicense"
```

This list is used if the user does not provide a list of plug-ins.

# Important Variables

There are a handful of extremely important system variables that make life easier for personality and plug-in writers.  Other variables may be provided by individual plug-ins.  Check their development documentation for more information.

* BUILD\_NATIVE will be set to true if the system has requested that non-JVM-based code be built (e.g., JNI or other compiled C code). Under Jenkins, this is always true.

* BUILDTOOL specifies which tool is currently being used to drive compilation.  Additionally, many build tools define xyz\_ARGS to pass on to the build tool command line. (e.g., MAVEN\_ARGS if maven is in use).  Projects may set this in their personality.  NOTE: today, only one build tool at a time is supported.  This may change in the future.

* CHANGED\_FILES[@] is an array of all files that appear to be added, deleted, or modified in the patch.

* CHANGED\_MODULES[@] is an array of all modules that house all of the CHANGED\_FILES[@].  Be aware that the root of the source tree is reported as '.'.

* DOCKER\_EXTRAARGS[@] is an array of command line arguments to apply to the `docker run` command.

* GITHUB\_REPO is to help test-patch when talking to Github.  If test-patch is given just a number on the command line, it will default to using this repo to determine the pull request.

* JIRA\_ISSUE\_RE is to help test-patch when talking to JIRA.  It helps determine if the given project is appropriate for the given JIRA issue.

* MODULE and other MODULE\_\* are arrays that contain which modules, the status, etc, to be operated upon. These should be treated as read-only by plug-ins.

* PATCH\_BRANCH\_DEFAULT is the name of the branch in the git repo that is considered the master.  This is useful to set in personalities.

* PATCH\_DIR is the name of the temporary directory that houses test-patch artifacts (such as logs and the patch file itself)

* PATCH\_NAMING\_RULE should be a URL that points to a project's on-boarding documentation for new users. It is used to suggest a review of patch naming guidelines. Since this should be project specific information, it is useful to set in a project's personality.

* TEST\_PARALLEL if parallel unit tests have been requested. Project personalities are responsible for actually enabling or ignoring the request. TEST\_THREADS is the number of threads that have been requested to run in parallel.
