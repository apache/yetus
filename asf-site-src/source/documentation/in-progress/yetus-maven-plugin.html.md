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

# Yetus Maven Plug-in

<!-- MarkdownTOC levels="1,2" autolink="true" indent="  " bullets="*" bracket="round" -->

* [Introduction](#introduction)
* [File Utility Goals](#file-utility-goals)
  * [bin4libs](#bin4libs)
  * [symlink](#symlink)
  * [parallel-mkdirs](#parallel-mkdirs)

<!-- /MarkdownTOC -->

# Introduction

Apache Yetus a plug-in built for Apache Maven and compatible build tools.  This plug-in offers an easy way to integrate some of Apache Yetus' functionality in addition to offering a way to get some additional functionality that is missing from the base Maven environment.

    NOTE: This functionality should be considered experimental. Defaults, in particular, are likely to change in future revisions.

# File Utility Goals

As part of building Apache Yetus, we needed some portable functionality that we couldn't find elsewhere.  Just so others don't have to re-invent the wheel, we offer these goals as part of the plug-in:

## bin4libs

Apache Yetus builds wrappers in `bin/` that point to executables in `lib/`.  This goal provides a way to do this generically, including providing the capability to put a license file in the wrapper.

```xml
      <plugin>
        <groupId>org.apache.yetus</groupId>
        <artifactId>yetus-maven-plugin</artifactId>
        <executions>
          <execution>
            <id>bins4libs</id>
            <phase>prepare-package</phase>
            <goals>
              <goal>bin4libs</goal>
            </goals>
            <configuration>
              <libdir>lib/shelldocs</libdir>
              <basedir>${project.build.directory}/dist/</basedir>
            </configuration>
          </execution>
        </executions>
      </plugin>
```

This example will take all the files located in `${project.build.directory}/dist/lib/shelldocs/` and create wrappers in `${project.build.directory}/dist/bin` with any extensions stripped off.  If the `${project.build.directory}/dist/lib/shelldocs/` contains the file `shelldocs.py`, then the `bin/shelldocs` wrapper will look like this:

```bash
#!/usr/bin/env bash
[LICENSE TEXT]
exec "$(dirname -- "${BASH_SOURCE-0}")/../lib/shelldocs/shelldocs.py" "$@"
```

The wrapper as written above makes sure that nearly all forms of referencing (relative, absolute, bash -x, etc.) locates the real executable, passing along any options.

| Option | Description | Default |
|--------|-------------|---------|
| `basedir` | parent dir of `bindir` and `lib` to create relative paths | `${project.build.directory}/${project.artifactId}-${project.version}` |
| `bindir` | where to create wrapper | `bin` |
| `encoding` | encoding to use when reading license files | `${project.build.sourceEncoding}` |
| `goal` | the goal to use when creating the wrappers | `package` |
| `lib` | where the actual executable is located | `lib` |
| `license` | the license to put into the wrapper. See below. | `ASL20` |
| `wrapper` | the bash wrapper to actually use | `exec "$(dirname -- "${BASH_SOURCE-0}")/../"` |

### Licenses

The `license` field translates to `licenses/NAME.txt` as the name of the file to load from the CLASSPATH.
The `ASL20` license is the Apache Software License v2.0.

If no license is wanted, then set `license` to the string `none`.

## symlink

Since Java 7, there has been a portable way to build symlinks.  Unfortunately, standard plug-ins like the `maven-antrun-plugin` have not been updated to include the symlink task. The `yetus-maven-plugin` now exposes this functionality via the `symlink` goal:

```xml
      <plugin>
        <groupId>org.apache.yetus</groupId>
        <artifactId>yetus-maven-plugin</artifactId>
        <executions>
          <execution>
            <id>exec-id</id>
            <phase>compile</phase>
            <goals>
              <goal>symlink</goal>
            </goals>
            <configuration>
              <basedir>${project.build.directory}</basedir>
              <target>existing-file-or-dir</target>
              <newLink>link-to-create</newLink>
              <ignoreExist>true</ignoreExist>
            </configuration>
          </execution>
        </plugin>
```

Available configuration options:

| Option | Description | Default |
|--------|-------------|---------|
| `basedir` | where to create the symlink, if `newLink` is not absolute | `${project.build.directory}` |
| `goal` | the goal to use when to create the symlink | `package` |
| `ignoreExist` | a boolean that determines whether the goal should fail if the `newLink` already exists. | `true`. |
| `target` | the file or directory to link to | none |
| `newLink` | the symlink to create | none |

## parallel-mkdirs

Maven surefire (as of at least 2.x and earlier versions) has calculations to determine the number of tests to run in parallel.  However, the result is not shared in a way that allows creating directory structures before execution.  For specific build flows, this is problematic.

```xml
      <plugin>
        <groupId>org.apache.yetus</groupId>
        <artifactId>yetus-maven-plugin</artifactId>
        <executions>
          <execution>
            <id>parallel-mkdirs</id>
            <phase>compile</phase>
            <goals>
              <goal>parallel-mkdirs</goal>
            </goals>
            <configuration>
              <buildDir>${project.build.directory}/test-dir</buildDir>
            </configuration>
          </execution>
        </plugin>
```

Available configuration options:

| Option | Description | Default |
|--------|-------------|---------|
| `buildDir` | where to create the directories | `${project.build.directory}/test-dir` |
| `forkCount` | the number of directories to create| see blow |
| `goal` | the goal to use to create the directories | `generate-test-resources` |

By default, `forkCount` is inherited from surefire and therefore follows the same rules as described in its [documentation](https://maven.apache.org/surefire/maven-surefire-plugin/examples/fork-options-and-parallel-execution.html).  Of special note is that 'C' (aka core) values are honored.
