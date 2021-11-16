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

# test-patch Docker Support

<!-- MarkdownTOC levels="1,2" autolink="true" indent="  " bullets="*" bracket="round" -->

* [The Basics](#the-basics)
* [Docker Base Images](#docker-base-images)
  * [Default Image](#default-image)
  * [Using a Dockerfile](#using-a-dockerfile)
  * [Pulling a Docker tag](#pulling-a-docker-tag)
  * [Using a cache](#using-a-cache)
  * [Platforms](#platforms)
  * [Container Directory](#container-directory)
* [BuildKit](#buildkit)
* [Resource Controls](#resource-controls)
* [Privileged Mode](#privileged-mode)
* [Docker in Docker](#docker-in-docker)
* [Cleaning the Docker Environment](#cleaning-the-docker-environment)
  * [Images](#images)
  * [Containers](#containers)
  * [Dry Running Cleaning](#dry-running-cleaning)
  * [Standalone Facility](#standalone-facility)

<!-- /MarkdownTOC -->

# The Basics

By default, test-patch runs in the same shell where it was launched.  It can alternatively use Docker to launch itself in a Linux container by using the `--docker` parameter.  This is particularly useful if running under a QA environment that does not provide all the necessary binaries. For example, if the patch requires a newer version of Java than what is installed on a CI instance.

Each run will spawn two Docker images, one that contains some sort of base image and one specific to each run.  The base image is described further in this text.  The run-specific image is a small one that passes parameters and settings that are dedicated to that run, with "tp-" as part of the Docker image tag.  It should be removed automatically after the run upon test-patch completion.

# Docker Base Images

## Default Image

By default, test-patch will try to pull apache/yetus:VERSION from the default repository, where VERSION matches the version of Apache Yetus being utilized.  If that fails, it will then build an image based upon the built-in Dockerfile.  Both images contain all of the basic requirements for all of the plug-ins that test-patch supports.  As a result, it is a fairly hefty image!  It may take several minutes to either download or build, dependent upon processor, network speed, etc.

## Using a Dockerfile

The `--dockerfile` parameter allows one to provide a custom Dockerfile instead. The Dockerfile should contain all of the necessary binaries and tooling needed to build and test.  test-patch will process this file up until the text "YETUS CUT HERE".  Be aware that will always fail the build if the Dockerfile itself fails the build.  This makes it ideal to use to test any tools Dockerfile that is also used for development.

Dockerfile images will be named with a test-patch prefix and suffix with either a date or a git commit hash. By using this information, test-patch will automatically manage broken/stale container images that are hanging around if it is run in `--robot` mode.  In this way, if Docker fails to build the image, the disk space should eventually be cleaned and returned back to the system.  The docker mode can also be run in a "safe" mode that prevents deletions via the `--dockerdelrep` option.  Specifying this option will cause test-patch to only report what it would have deleted, but not actually remove anything.

If you are using a system such as [Travis CI](../robots/travisci) that has strict limits on logging, the `--docker-build-output`
option can control whether the `docker build` process is sent to the screen.

### COPY and ADD in Dockerfiles

In order to use both 'YETUS CUT HERE' and a Dockerfile that uses COPY and ADD directives, the Docker API must be version 18 or higher.  If the API version is 17 or lower, the Dockerfile will be copied to a temporary directory to be processed, thus removing the Docker build context in the process.

## Pulling a Docker tag

Instead of processing a Dockerfile, test-patch can pull a tag from a repository using the `--docker-tag` parameter. Note that the repository must already be logged into and configured prior to executing test-patch.

## Using a cache

With the `--docker-cache-from` parameter, other images may be utilized to provide a cache when building a Dockerfile. This comma delimited list will automatically be pulled (errors are ignored) and given to the docker command line to use.

## Platforms

When either building or pull an image, test-patch supports the `--docker-platform` flag to pass in the Docker `--platform` flag.  This allows you full control over what kind of image the software either creates or fetches.

## Container Directory

By default, precommit will use `/precommit` as the directory where it will store any necessary components that are
not provided by other flags in system (such as `--basedir` or `--patch-dir`).  If that directory conflicts with some other
need, then the `--docker-work-dir` option may be provided to set a different path.

# BuildKit

By default, precommit will enable [Docker BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/)
unless told otherwise with `--docker-buildkit=false` or if the CI system has known limitations.

# Resource Controls

Docker's `--memory` flag is supported via the `--dockermemlimit` option.  This enables the container's memory size to be limited.  This may be important to set to prevent things like broken unit tests bringing down the entire build server.  See [the Docker documentation](https://docs.docker.com/engine/admin/resource_constraints/) for more details. Apache Yetus also sets the `--oom-score-adj` to 500 in order to offer itself as the first processes to be killed if memory is low.

Additionally, if bash v4 and Linux is in use, a separate process is launched to keep a rolling count of the maximum number of threads (not processes!) in use at one time. This number will be reported at the end of the test-patch run.  Depending upon the build, languages, features enabled, etc, this number may be helpful in determining what the value of `--proclimit`

# Privileged Mode

In some cases, the work being performed inside the Docker container requires extra permissions.  Using the `--docker-privd` option enables Docker's extended privileges to the container.

# Docker in Docker

With the usage of the `--dockerind` flag, test-patch will mount the `/var/run/docker.sock` UNIX socket into the container to enable Docker-in-Docker mode.  Additionally, the `--docker-socket` option will let one set the socket to mount in situations where that isn't the location of the socket, such as a dockerd proxy providing authentication.

    NOTE: Using --dockerind requires the availability of the `stat` command that supports either -c '%g' (GNU form) or -f '%g' (BSD form).

# Cleaning the Docker Environment

With the growing use of Docker for CI purposes, so is the growing need to help manage the Docker environment.  Stale, large
caches and stuck containers are a common problem when tests go haywire.  In order to help combat that, Apache Yetus includes
facilities as part of precommit to help keep these things under control.  By default, none of these cleaning actions occur.
However if the system is in [Robot](../robots)-mode or `--sentinel` is used, carefully controlled cleaning will happen.

    NOTE: Docker volumes are not managed by Apache Yetus.

## Images

For container images, there are three modes.  Each mode increases the amount of coverage that Apache Yetus will use to
remove images.

| Mode | Images Types | Time Frame |
|:----:|:------------:|:----------:|
| default | all | NA |
| `--robot` | dangling, label=org.apache.yetus | 1 week |
| `--sentinel` | all | 1 week |

Before it begins, Apache Yetus will show the contents of `docker images` so that there is a history of what was in
the cache. This also helps determine what was deleted later.  Next, it finds images that fall within the time frame of
the given mode. Then it will untag those images and followed by trying to remove them by sha.  If an
image is in use, an error will be reported but ignored by Apache Yetus. It is an information message to help give the user
an idea of what is happening under the hood.

## Containers

For containers there are two modes:

| Mode | Images Types | Time Frame |
|:----:|:------------:|:----------:|
| default | all | NA |
| `--sentinel` | all | 24 hours |

Under just plain `--robot`, containers are left alone.  Under `--sentinel`, containers (regardless of state) are
killed after 24 hours.

Just as with images, Apache Yetus will report all the running containers on the system.  Then it will, if
necessary, send a `docker kill` followed by a `docker rm` remove any containers that are over the runtime
limit.

## Dry Running Cleaning

To see what the system would have done, the `--dockerdelrep` option is provided to report, but not act, on deletions.

## Standalone Facility

By popular demand, Apache Yetus provides the [docker-cleanup](../docker-cleanup) program to perform these functions
outside of running jobs.  This program is useful for CI systems that do not regularly run Apache Yetus or for
simply consolidating the maintenance into one location.
