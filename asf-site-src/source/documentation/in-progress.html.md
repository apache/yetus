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

# Yetus Precommit

The Yetus Precommit Patch Tester allows projects to codify their patch acceptance criteria and then evaluate incoming contributions prior to review by a committer.

* Take a quick look at [our glossary of terms](precommit-glossary) to ensure you are familiar with the ASF and Maven jargon we'll use as terminology specific to this project.
* For an overview of Yetus' philosophy on testing contributions and how evaluation is performed, see our [overview](precommit-architecture).
* To get started on your project, including an explanation of what we'll expect in a runtime environment and what optional utilities we'll leverage, read through the [basic usage guide](precommit-basic).
* Customize how precommit interacts with your project by choosing amongst [build systems](precommit-buildtools), [bug systems](precommit-bugsystems) and [test formats](precommit-testformats).
* If your project has advanced requirements such as module relationships not expressed in Maven, special profiles, or a need on os-specific prerequisites not managed by Maven then you'll need to use our [advanced usage guide](precommit-advanced).

For a complete guide to the Precommit API, see [the generated API documentation](precommit-apidocs/).

# Yetus Release Doc Maker

The Release Documentation Maker allows projects to generate nicely formated Markdown Changelogs and Release Notes based upon JIRA. You can view that
documenation [here](releasedocmaker).

# Yetus Shelldocs

Shelldocs provides generation of html formatted api documentation based on comments on Bash functions. Currently supports documenting API status (public / private) as well as parameters and return values.

See the shelldocs cli help for more information on usage.

```bash
$ ./shelldocs/shelldocs.py --help
Usage: shelldocs.py --skipprnorep --output OUTFILE --input INFILE [--input INFILE ...]

Options:
  -h, --help            show this help message and exit
  -o OUTFILE, --output=OUTFILE
                        file to create
  -i INFILE, --input=INFILE
                        file to read
  --skipprnorep         Skip Private & Not Replaceable
```

You can mark a file to be ignored by shelldocs by adding "SHELLDOC-IGNORE" as a comment in its own line.

# Yetus Audience Annotations

Audience Annotations allows you to use Java Annotations to denote which parts of your Java library is publicly consumable and which parts are reserved for a more restricted use. It also provides doclets and examples for generating javadocs limited by audience.
You can refer the user documentation [here](interface-classification) and the javadocs [here](audience-annotations-apidocs/).
