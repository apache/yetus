
<!---
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
-->
  * Public/Stable/Replaceable
    * [relative\_dir](#relative_dir)
    * [verify\_multijdk\_test](#verify_multijdk_test)
  * Public/Stable/Not Replaceable
    * [add\_footer\_table](#add_footer_table)
    * [add\_header\_line](#add_header_line)
    * [add\_test\_table](#add_test_table)
    * [add\_vote\_table](#add_vote_table)
    * [big\_console\_header](#big_console_header)
    * [clock\_display](#clock_display)
    * [echo\_and\_redirect](#echo_and_redirect)
    * [generate\_stack](#generate_stack)
    * [module\_file\_fragment](#module_file_fragment)
    * [offset\_clock](#offset_clock)
    * [setup\_defaults](#setup_defaults)
    * [start\_clock](#start_clock)
    * [stop\_clock](#stop_clock)
  * Public/Stable/Not Replaceable
    * [write\_comment](#write_comment)
  * Public/Stable/Not Replaceable
    * [yetus\_usage](#yetus_usage)
  * Public/Evolving/Not Replaceable
    * [bugsystem\_linecomments](#bugsystem_linecomments)
    * [calcdiffs](#calcdiffs)
    * [clear\_personality\_queue](#clear_personality_queue)
    * [compile](#compile)
    * [compile\_cycle](#compile_cycle)
    * [distclean](#distclean)
    * [generic\_count\_probs](#generic_count_probs)
    * [generic\_post\_handler](#generic_post_handler)
    * [generic\_postlog\_compare](#generic_postlog_compare)
    * [generic\_pre\_handler](#generic_pre_handler)
    * [initialize](#initialize)
    * [module\_status](#module_status)
    * [modules\_messages](#modules_messages)
    * [modules\_reset](#modules_reset)
    * [modules\_workers](#modules_workers)
    * [patchfiletests](#patchfiletests)
    * [personality\_enqueue\_module](#personality_enqueue_module)
  * Private/Stable/Replaceable
    * [finish\_docker\_stats](#finish_docker_stats)
    * [prepopulate\_footer](#prepopulate_footer)
    * [report\_jvm\_version](#report_jvm_version)
  * Private/Evolving/Replaceable
    * [verify\_patchdir\_still\_exists](#verify_patchdir_still_exists)
  * Private/Evolving/Not Replaceable
    * [import\_core](#import_core)
    * [prechecks](#prechecks)

------

## Public/Stable/Replaceable
### `relative_dir`

* Synopsis

```
relative_dir path
```

* Description

is a given directory relative to BASEDIR?

* Returns

## @returns     1 - no, path

## @returns     0 - yes, path - BASEDIR

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `verify_multijdk_test`

* Synopsis

```
verify_multijdk_test test
```

* Description

Verify if a given test is multijdk

* Returns

1 = yes

0 = no

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

## Public/Stable/Not Replaceable
### `add_footer_table`

* Synopsis

```
add_footer_table subsystem string
```

* Description

Add to the footer of the display. @@BASE@@ will get replaced with the correct location for the local filesystem in dev mode or the URL for Jenkins mode.

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `add_header_line`

* Synopsis

```
add_header_line string
```

* Description

Add to the header of the display

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `add_test_table`

* Synopsis

```
add_test_table failurereason testlist
```

* Description

Special table just for unit test failures

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `add_vote_table`

* Synopsis

```
add_vote_table +1/0/-1/null subsystem string
```

* Description

Add to the output table. If the first parameter is a number that is the vote for that column and calculates the elapsed time based upon the last start_clock().  If it the string null, then it is a special entry that signifies extra content for the final column.  The second parameter is the reporting subsystem (or test) that is providing the vote.  The second parameter is always required.  The third parameter is any extra verbage that goes with that subsystem.

* Returns

Elapsed time display

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `big_console_header`

* Synopsis

```
big_console_header string
```

* Description

Large display for the user console

* Returns

large chunk of text

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `clock_display`

* Synopsis

```
clock_display seconds
```

* Description

Convert time in seconds to m + s

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `echo_and_redirect`

* Synopsis

```
echo_and_redirect filename command [..]
```

* Description

Print the command to be executing to the screen. Then run the command, sending stdout and stderr to the given filename This will also ensure that any directories in ${BASEDIR} have the exec bit set as a pre-exec step.

* Returns

## @returns      $?

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `generate_stack`

* Synopsis

```
generate_stack
```

* Description

generate a stack trace when in debug mode

* Returns

exits

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `module_file_fragment`

* Synopsis

```
module_file_fragment module
```

* Description

Convert the given module name to a file fragment

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `offset_clock`

* Synopsis

```
offset_clock seconds
```

* Description

Add time to the local timer

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `setup_defaults`

* Synopsis

```
setup_defaults
```

* Description

Setup the default global variables

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `start_clock`

* Synopsis

```
start_clock
```

* Description

Activate the local timer

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `stop_clock`

* Synopsis

```
stop_clock
```

* Description

Print the elapsed time in seconds since the start of the local timer

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

## Public/Stable/Not Replaceable
### `write_comment`

* Synopsis

```
write_comment ## @params filename
```

* Description

Write the contents of a file to all of the bug systems (so content should avoid special formatting)

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | None |

## Public/Stable/Not Replaceable
### `yetus_usage`

* Synopsis

```
yetus_usage
```

* Description

Print the usage information

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

## Public/Evolving/Not Replaceable
### `bugsystem_linecomments`

* Synopsis

```
bugsystem_linecomments filename
```

* Description

Write comments onto bug systems that have code review support. File should be in the form of "file:line:comment"

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `calcdiffs`

* Synopsis

```
calcdiffs
```

* Description

Calculate the differences between the specified files and output it to stdout.

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `clear_personality_queue`

* Synopsis

```
clear_personality_queue
```

* Description

Reset the queue for tests

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `compile`

* Synopsis

```
compile branch|patch
```

* Description

Execute the compile phase. This will callout to _compile

* Returns

0 on success

1 on failure

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `compile_cycle`

* Synopsis

```
compile_cycle branch|patch
```

* Description

Execute the static analysis test cycle. This will callout to _precompile, compile, _postcompile and _rebuild

* Returns

0 on success

1 on failure

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `distclean`

* Synopsis

```
distclean
```

* Description

Wipe the repo clean to not invalidate tests

* Returns

0 on success

1 on failure

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `generic_count_probs`

* Synopsis

```
generic_count_probs
```

* Description

Helper routine for plugins to ask projects, etc to count problems in a log file and output it to stdout.

* Returns

number of issues

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `generic_post_handler`

* Synopsis

```
generic_post_handler origlog testtype multijdkmode run commands
```

* Description

Generic post-patch handler

* Returns

0 on success

1 on failure

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `generic_postlog_compare`

* Synopsis

```
generic_postlog_compare origlog testtype multijdkmode
```

* Description

Generic post-patch log handler

* Returns

0 on success

1 on failure

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `generic_pre_handler`

* Synopsis

```
generic_pre_handler testype multijdk
```

* Description

Helper routine for plugins to do a pre-patch prun

* Returns

1 on failure

0 on success

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `initialize`

* Synopsis

```
initialize $@
```

* Description

Setup to execute

* Returns

0 on success

1 on failure

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `module_status`

* Synopsis

```
module_status module runtime
```

* Description

Add a test result

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `modules_messages`

* Synopsis

```
modules_messages repostatus testtype mvncmdline
```

* Description

Utility to print standard module errors

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `modules_reset`

* Synopsis

```
modules_reset
```

* Description

Reset the test results

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `modules_workers`

* Synopsis

```
modules_workers repostatus testtype mvncmdline
```

* Description

run the tests for the queued modules

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `patchfiletests`

* Synopsis

```
patchfiletests branch|patch
```

* Description

Execute the patch file test phase. Calls out to to _patchfile

* Returns

0 on success

1 on failure

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

### `personality_enqueue_module`

* Synopsis

```
personality_enqueue_module module profiles/flags/etc
```

* Description

Build the queue for tests

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

## Private/Stable/Replaceable
### `finish_docker_stats`

* Synopsis

```
finish_docker_stats
```

* Description

Put docker stats in various tables

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Private |
| Stability | Stable |
| Replaceable | Yes |

### `prepopulate_footer`

* Synopsis

```
prepopulate_footer
```

* Description

Put the opening environment information at the bottom of the footer table

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Private |
| Stability | Stable |
| Replaceable | Yes |

### `report_jvm_version`

* Synopsis

```
report_jvm_version ## @params       directory
```

* Description

Report the JVM version of the given directory

* Returns

## @returns      version

| Classification | Level |
| :--- | :--- |
| Audience | Private |
| Stability | Stable |
| Replaceable | Yes |

## Private/Evolving/Replaceable
### `verify_patchdir_still_exists`

* Synopsis

```
verify_patchdir_still_exists
```

* Description

Verify that the patch directory is still in working order since bad actors on some systems wipe it out. If not, recreate it and then exit

* Returns

## @returns     may exit on failure

| Classification | Level |
| :--- | :--- |
| Audience | Private |
| Stability | Evolving |
| Replaceable | Yes |

## Private/Evolving/Not Replaceable
### `import_core`

* Synopsis

```
import_core
```

* Description

import core library routines

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Private |
| Stability | Evolving |
| Replaceable | None |

### `prechecks`

* Synopsis

```
prechecks
```

* Description

perform prechecks

* Returns

exits on failure

| Classification | Level |
| :--- | :--- |
| Audience | Private |
| Stability | Evolving |
| Replaceable | None |
