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

# Maintaining the Yetus Website

We use [Middleman](https://middlemanapp.com/) to generate the website content from markdown and other
dynamic templates.If you're interested in digging into how our site makes use of Middleman, or if you run into a problem, you should start
by reading [Middleman's excellent documentation](https://middlemanapp.com/basics/install/).

    NOTE: The Docker container launched by `./start-build-env.sh` should have everything you need to maintain the website.

    NOTE: You MUST have run `mvn install` at least once prior to running `mvn site`.

The following steps assume you have a working ruby 2.x environment setup:

```bash
$ sudo gem install bundler
$ cd asf-site-src
$ bundle install
```
and a working python 2.x environment for [releasedocmaker](../in-progress/releasedocmaker/).

## Make changes in asf-site-src/source
Make any changes in the source directory:

```bash
cd asf-site-src/source
vi contribute.html.md
```

## Make changes to API Docs
Optionally, you can update the generated API docs from other parts of the project. If they have been updated then the middleman build will pick up the changes.

e.g. Precommit changes will be picked up by the Middleman build.

```bash
cd ../precommit/core.d
vi 01-common.sh
```

## Generating the website
To generate the static website for Apache Yetus run the following command at the root directory:

```bash
mvn --batch-mode install
mvn --batch-mode site
```

Apache Yetus uses itself to build parts of its website. ('Flying our own airplanes')  This command will first generate a full build of Apache Yetus and create a static website in the `asf-site-src/target/site` sub directory and a tarball of the site in yetus-dist/target/. You can load it in a web browser, e.g. assuming you are still in the asf-site-src directory on OS X:

```bash
open asf-site-src/target/site/index.html
```

## Live Development
Live development of the site enables automatic reload when changes are saved.
To enable, run the following commands and then open a browser and navigate to
[http://localhost:4567](http://localhost:4567/)

```bash
cd asf-site-src
bundle exec middleman
```

## Publishing the Site
Commit the publish directory to the asf-site branch. Presuming we start in a directory that holds your normal Yetus check out:

```bash
$ git clone --single-branch --branch asf-site https://git-wip-us.apache.org/repos/asf/yetus.git yetus-site
$ # Now build in the normal yetus check out
$ cd yetus
$ git fetch origin
$ git checkout master
$ git reset --hard origin/master
$ git clean -xdf
$ mvn --batch-mode install
$ mvn --batch-mode site
$ rsync --quiet --checksum --inplace --recursive yetus-dist/target/apache-yetus-${project.version}-SNAPSHOT-site/ ../../yetus-site/
$ cd ../../yetus-site
$ # check the set of differences
$ git add -p
$ # Verify any new files are also added
$ git status
$ # Try to reference the commit hash on master that this publication assures we include
$ git commit -m "git hash 6c6f6f6b696e6720746f6f20686172642c20796f"
$ # Finally publish
$ git push origin asf-site
```

Publishing the website should be possible from the HEAD of the master branch under most circumstances. (See the [Guide for Release Managing](releases) for a notable time period where this won't be true.)
Documentation changes will be reviewed as they make their way into the master branch; updates to the `asf-site` branch are handled without further review.
