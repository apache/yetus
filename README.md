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
# Apache Yetus

Apache Yetus is a collection of libraries and tools that enable
contribution and release process for software projects.

## Components

Here is a list of the major components:

* [Website source](asf-site-src/)
Holds our documentation, which is presented via [our website](https://yetus.apache.org/).
* [Precommit](precommit/)
Precommit provides robust tools to deal with contributions, including applying patches from a variety of project sources and evaluating them against project norms via a system of plugins. See the [precommit overview](asf-site-src/source/documentation/in-progress/precommit-architecture.md) to get started working with precommit.
* [Audience Annotations](audience-annotations-component/)
Audience Annotations allows projects to use Java Annotations to delineate public and non-public parts of their APIs. It also provides doclets to generate javadocs filtered by the intended audience. Currently builds with Maven 3.2.0+.
* [Shelldocs](shelldocs/)
Shelldocs processes comments on Bash functions for annotations similar to Javadoc. It also includes built-in audience scoping functionality similar to the doclet from Audience Annotations.
* [Release Doc Maker](release-doc-maker/)
Release Doc Maker analyzes Jira and Git information to produce Markdown formatted release notes.
* [yetus-maven-plugin](yetus-maven-plugin/)
Builds a maven plugin that provides some small utilities for some uncommon maven requirements (such as symlinks) in addition to being mavenized versions of some of the Apache Yetus functionality.

## Building Quickstart

For full instructions on how to build releases and the website, see the [guide to contributing](asf-site-src/source/contribute.html.md) for requirements and instructions.

```bash
# Launch a Docker container that has all of the project's dependencies and a working build environment
./start-build-env.sh

# Build the binary tarball, located in yetus-dist/target/artifacts:
mvn clean install

# Build the binary and source tarballs and sign the content:
mvn clean install -Papache-release

# Same, but if outside the container and need to let the system know that the OS uses 'gpg2' instead of 'gpg':
mvn clean install -Papache-release -Pgpg2

# Build the binary and source tarballs, but skip signing them:
mvn clean install -Papache-release -Dgpg.sign=skip

# Build the website (requires a mvn install first)
mvn site site:stage
```

After executing one or more of the Apache Maven commands, artifacts will be in `yetus-dist/target/artifacts` or ready for a `mvn deploy`.