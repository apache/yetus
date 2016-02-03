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

We use middleman to generate the website content from markdown and other
dynamic templates. The following steps assume you have a working
ruby 2.x environment setup:

```bash
gem install bundler
bundle install
```

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
To generate the static wesbite for Apache Yetus run the following commands at the root asf-site-src directory:

```bash
bundle exec middleman build
```

## Live Development
Live development of the site enables automatic reload when changes are saved.
To enable run the following command and then open a browser and navigate to
[http://localhost:4567](http://localhost:4567/)

```bash
bundle exec middleman
```

## Publishing the Site
Commit the publish directory to the asf-site branch.

