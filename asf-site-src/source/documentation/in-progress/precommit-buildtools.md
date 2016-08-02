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

Build Tool Support
===================

test-patch has the ability to support multiple build tools.  Build tool plug-ins have some extra hooks to do source and object maintenance at key points. Every build tool plug-in must have one line in order to be recognized:

```bash
add_build_tool <pluginname>
```

# Global Variables

* BUILDTOOLCWD

    - This variable determines where the build tool's command (as returned by pluginname\_executor) should actually execute.  It should be one of three values:

    * basedir  - always execute at the root of the source tree
    * module   - switch to the directory as given by the module being processed
    * /(path)  - change to the directory as given by this absolute path. If the path does not exist, it will be created.

  If /(path) is used, two special substitutions may be made:

  * @@@BASEDIR@@@ will be replaced with the root of the source tree
  * @@@MODULEDIR@@@ will be replaced with the module name

  This allows for custom directories to be created and used as necessary.


    The default is module.

* UNSUPPORTED\_TEST

    - If pluginname\_modules\_worker is given a test type that is not supported by the build system, set UNSUPPORTED\_TEST=true.  If it is supported, set UNSUPPORTED\_TEST=false.

For example, the gradle build tool does not have a standard way to execute checkstyle. So when checkstyle is requested, gradle\_modules\_worker sets UNSUPPORTED\_TEST to true and returns out of the routine.

# Required Functions

* pluginname\_buildfile

    - This should be an echo of the file that controls the build system.  This is used for module determination. If the build system wishes to disable module determination, it should echo with no args.

* pluginname\_executor

    - This should be an echo of how to run the build tool, any extra arguments, etc.

* pluginname\_modules\_worker

    - Input is the branch and the test being run.  This should call `modules_workers` with the generic parts to run that test on the build system.  For example, if it is convention to use 'test' to trigger 'unit' tests, then `module_workers` should be called with 'test' appended onto its normal parameters.

* pluginname\_builtin_personality\_modules

    - Default method to determine how to enqueue modules for processing.  Note that personalities may override this function. Requires two arguments: repo status and test desired. For example, in a maven build, values may be 'branch' and 'mvninstall'.

* pluginname\_builtin_personality\_file\_tests

    - Default method to determine which tests to trigger.  Note that personalities may override this function. Requires a single argument: the file in which the tests exist.

# Optional Functions

* pluginname\_parse\_args

    - executed prior to any other above functions except for pluginname\_usage. This is useful for parsing the arguments passed from the user and setting up the execution environment.

* pluginname\_initialize

    - After argument parsing and prior to any other work, the initialize step allows a plug-in to do any precursor work, set internal defaults, etc.

* pluginname\_reorder\_modules

    - This functions allows the plugin to (re-)order the modules (e.g. based on the output of the maven dependency plugin). When called CHANGED\_MODULES[@] already contains all changed modules. It must be altered to have an effect.

* pluginname\_(test)\_logfilter

    - This functions should filter all lines relevant to this test from the logfile. It is called in preparation for the `calcdiffs` function. The test plug-in name should be in the (test) part of the function name.

* pluginname\_(test)_calcdiffs

    - Some build tools (e.g., maven) use custom output for certain types of compilations (e.g., java).  This allows for custom log file difference calculation used to determine the before and after views.

* pluginname\_docker\_support

    - If this build tool requires extra settings on the `docker run` command line, this function should be defined and add those options into an array called `${DOCKER_EXTRAARGS[@]}`. This is particularly useful for things like mounting volumes for repository caches.

       **WARNING**: Be aware that directories that do not exist MAY be created by root by Docker itself under certain conditions.  It is HIGHLY recommend that `pluginname_initialize` be used to create the necessary directories prior to be used in the `docker run` command.

# Ant Specific

## Command Arguments

test-patch always passes -noinput to Ant.  This forces ant to be non-interactive.

## Docker Mode

In Docker mode, the `${HOME}/.ivy2` directory is shared amongst all invocations.

# autoconf Specific

autoconf requires make to be enabled.  autoreconf is always used to rebuild the configure scripte.

## Command Arguments

autoconf will always run configure with prefix set to a directory in the patch processing directory.  To configure other flags, set the AUTCONF_CONF_FLAGS environment variable.

# CMAKE Specific

By default, cmake will create a 'build' directory and perform all work there.  This may be changed either on the command line or via a personality setting.  cmake requires make to be enabled.

# Gradle Specific

The gradle plug-in always rebuilds the gradlew file and uses gradlew as the method to execute commands.

In Docker mode, the `${HOME}/.gradle` directory is shared amongst all invocations.

# Make Specific

No notes.

# Maven Specific

## Command Arguments

test-patch always passes --batch-mode to maven to force it into non-interactive mode.  Additionally, some tests will also force -fae in order to get all of messages/errors during that mode. Some tests are executed with -DskipTests.  Additional arguments should be handled via the personality.

##  Per-instance Repositories

Under many common configurations, maven (as of 3.3.3 and lower) may not properly handle being executed by multiple processes simultaneously, especially given that some tests require the `mvn install` command to be used.

To assist, `test-patch` supports a `--mvn-custom-repo` option to set the `-Dmaven.repo.local` value to a per-instance repository directory keyed to the project and branch being used for the test.  If the `--jenkins` flag is also passed, the instance will be tied to the Jenkins `${EXECUTOR_NUMBER}` value.  Otherwise, the instance value will be randomly generated via `${RANDOM}`.  If the repository has not been used in 30 days, it will be automatically deleted when any test run for that project (regardless of branch!).

By default, `test-patch` uses `${HOME}/yetus-m2` as the base directory to store these custom maven repositories.  That location may be changed via the `--mvn-custom-repos-dir` option.

The location of the `settings.xml` may be changed via the `--mvn-settings` option.

## Docker Mode

In Docker mode, `${HOME}/.m2` is shared amongst all invocations.  If `--mvn-custom-repos` is used, all of `--mvn-custom-repos-dir` is shared with all invocations.  The per-instance directory will be calculated and configured after Docker has launched.

## Test Profile

By default, test-patch will pass -Ptest-patch to Maven. This will allow you to configure special actions that should only happen when running underneath test-patch.

## Custom Maven Tests

Maven will test eclipse and site if maven is being used as the build tool and appropriate files trigger them.

Maven will trigger add a maven install test when the `maven_add_install` function has been used and the related tests are requierd. Plug-ins that need to run maven before MUST call it as part of their respective initialize functions, otherwise maven may fail unexpectedly.  All Apache Yetus provided plug-ins that require maven will trigger the maven install functionality.
