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

# shelldocs

<!-- MarkdownTOC levels="1,2" autolink="true" indent="  " bullets="*" bracket="round" -->

* [Purpose](#purpose)
* [Requirements](#requirements)
* [Function Annotations](#function-annotations)
  * [Audience / Stability](#audience--stability)
  * [Multiple Parameters](#multiple-parameters)
  * [Return Values](#return-values)
  * [Code Example](#code-example)
* [Basic Usage](#basic-usage)
* [Skipping Files](#skipping-files)
* [Avoiding Private or Non-Replaceable Functions](#avoiding-private-or-non-replaceable-functions)
* [Lint Mode](#lint-mode)

<!-- /MarkdownTOC -->

# Purpose

Some projects have complex shell functions that act as APIs. `shelldocs` provides an annotation system similar to JavaDoc. It allows a developer to auto-generate MultiMarkdown documentation files as input to other processing systems.

# Requirements

* Python 3.8

# Function Annotations

`shelldocs` works by doing simple parsing of shell scripts.  As such, it looks for code that matches these patterns:

```bash
## @annotation
function functioname() {
  ...
}
```

```bash
## @annotation
function functioname () {
  ...
}
```

```bash
## @annotation
function functioname {
  ...
}
```

```bash
## @annotation
function functioname
{
  ...
}
```

```bash
## @annotation
functioname() {
  ...
}
```

```bash
## @annotation
functioname () {
  ...
}
```

Note that the comment has two hash ('#') marks.  The content of the comment is key.  This is what `shelldocs` will turn into documentation.  The following annotations are supported:

| Annotation | Required | Description | Acceptable Values | Default |
|:---- |:---- |:--- |:--- |:-- |
| @description | No | What this function does, intended purpose, etc. | text | None |
| @audience | Yes | Who should use this function? | public, private,| None |
| @stability | Yes | Is this function going to change? | stable, evolving | None |
| @replaceable | No | Is this function safely 'monkeypatched'? |  yes or no | No |
| @param | No | A single parameter| A single keyword. e.g., 'seconds' to specify that this function requires a time in seconds | None |
| @return | No | What does this function return? | text | Nothing |

## Audience / Stability

This values are the shell equivalents to the Java versions present in Apache Yetus Audience Annotations.

## Multiple Parameters

Each parameter requires it's own `@param` line and they must be listed in order.

## Return Values

It is recommended that multiple `@return` entries should be used when multiple values are possible.  For example:

```bash
## @return 0 - success
## @return 1 - failure
```

## Code Example

```bash
## @description This is an example
## @description of what one can do.
## @audience public
## @stability stable
## @param integer
## @param integer
## @return sum
function add_two_numbers() {
  return (($1 + $2))
}
```

# Basic Usage

The `shelldocs` executable requires at least one input file and either an output file or to run in lint mode.  Lint mode is covered below.

```bash
$ shelldocs --output functions.md --input myshelldirectory
```

This will process all of the files in `myshelldirectory` that end in `sh` and generate an output file called `functions.md`.  This file will contain a table of contents of all of the functions arranged by audience, stability, and replace-ability.

# Skipping Files

When processing directories, it may be desirable to avoid certain files. This may be done by including a comment in the file:

```bash
# SHELLDOC-IGNORE
```

This comment tells `shelldocs` that this file should not be processed.

# Avoiding Private or Non-Replaceable Functions

Some functions are not meant to be used by 3rd parties or cannot be easily replaced.  These functions may be omitted from the documentation by using the `--skipprnorep` flag:

```bash
$ shelldocs --skipprnorep --input directory --output file.md
```

# Lint Mode

In order to ensure minimal documentation, `shelldocs` has a `--lint` mode that will point out functions that are missing required annotations:

```bash
$ shelldocs --input directory --lint
```

This will process `directory` and inform the user of any such problems.
