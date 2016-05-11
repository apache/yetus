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

# Maintaing the Yetus Website

We use [Middleman](https://middlemanapp.com/) to generate the website content from markdown and other
dynamic templates. The following steps assume you have a working
ruby 2.x environment setup:

```bash
gem install bundler
bundle install
```

If you're interested in digging into how our site makes use of Middleman, or if you run into a problem, you should start
by reading [Middleman's excellent documentation](https://middlemanapp.com/basics/install/).

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


e.g. Audience Annotations requires running Maven.

```bash
cd ../audience-annotations-component
mvn -DskipTests -Pinclude-jdiff-module javadoc:aggregate
cd -
```

## Generating the website
To generate the static website for Apache Yetus run the following commands at the root asf-site-src directory:

```bash
bundle exec middleman build
```

This command will create a static website in the `publish` sub directory. You can load it in a web browser, e.g. assuming you are still in the asf-site-src directory on OS X:

```bash
open publish/index.html
```

## Live Development
Live development of the site enables automatic reload when changes are saved.
To enable run the following command and then open a browser and navigate to
[http://localhost:4567](http://localhost:4567/)

```bash
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
$ cd asf-site-src
$ bundle exec middleman build
$ rsync --quiet --checksum --inplace --recursive publish/ ../../yetus-site/
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
