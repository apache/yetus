
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
    * [add\_bugsystem](#add_bugsystem)
    * [add\_build\_tool](#add_build_tool)
    * [add\_test](#add_test)
    * [add\_test\_format](#add_test_format)
    * [add\_test\_type](#add_test_type)
    * [delete\_bugsystem](#delete_bugsystem)
    * [delete\_build\_tool](#delete_build_tool)
    * [delete\_test](#delete_test)
    * [delete\_test\_format](#delete_test_format)
    * [delete\_test\_type](#delete_test_type)
    * [personality\_plugins](#personality_plugins)
    * [verify\_needed\_test](#verify_needed_test)
    * [verify\_plugin\_enabled](#verify_plugin_enabled)
  * Public/Stable/Not Replaceable
    * [common\_defaults](#common_defaults)
    * [patchfile\_verify\_zero](#patchfile_verify_zero)
    * [yetus\_add\_entry](#yetus_add_entry)
    * [yetus\_debug](#yetus_debug)
    * [yetus\_delete\_entry](#yetus_delete_entry)
    * [yetus\_error](#yetus_error)
    * [yetus\_run\_and\_redirect](#yetus_run_and_redirect)
    * [yetus\_verify\_entry](#yetus_verify_entry)
  * Public/Evolving/Not Replaceable
    * [list\_plugins](#list_plugins)
  * None/None/Not Replaceable
    * [personality\_file\_tests](#personality_file_tests)
    * [personality\_modules](#personality_modules)
  * Private/Evolving/Not Replaceable
    * [generic\_locate\_patch](#generic_locate_patch)
    * [guess\_patch\_file](#guess_patch_file)

------

## Public/Stable/Replaceable
### `add_bugsystem`

* Synopsis

```
add_bugsystem bugsystem
```

* Description

Add the given bugsystem type

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `add_build_tool`

* Synopsis

```
add_build_tool build tool
```

* Description

Add the given build tool type

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `add_test`

* Synopsis

```
add_test test
```

* Description

Add the given test type

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `add_test_format`

* Synopsis

```
add_test_format test format
```

* Description

Add the given test format type

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `add_test_type`

* Synopsis

```
add_test_type plugin
```

* Description

Add the given test type

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `delete_bugsystem`

* Synopsis

```
delete_bugsystem bugsystem
```

* Description

Remove the given bugsystem type

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `delete_build_tool`

* Synopsis

```
delete_build_tool build tool
```

* Description

Remove the given build tool type

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `delete_test`

* Synopsis

```
delete_test test
```

* Description

Remove the given test type

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `delete_test_format`

* Synopsis

```
delete_test_format test format
```

* Description

Remove the given test format type

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `delete_test_type`

* Synopsis

```
delete_test_type plugin
```

* Description

Remove the given test type

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `personality_plugins`

* Synopsis

```
personality_plugins plug-in list string
```

* Description

Personality-defined plug-in list

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `verify_needed_test`

* Synopsis

```
verify_needed_test test
```

* Description

Verify if a given test was requested

* Returns

1 = yes

0 = no

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

### `verify_plugin_enabled`

* Synopsis

```
verify_plugin_enabled test
```

* Description

Determine if a plugin was enabeld by the user ENABLED_PLUGINS must be defined

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | Yes |

## Public/Stable/Not Replaceable
### `common_defaults`

* Synopsis

```
common_defaults
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

### `patchfile_verify_zero`

* Synopsis

```
patchfile_verify_zero log filename
```

* Description

if patch-level zero, then verify we aren't just adding files

* Returns

## @returns      $?

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `yetus_add_entry`

* Synopsis

```
yetus_add_entry
```

* Description

Given variable $1 add $2 to it

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `yetus_debug`

* Synopsis

```
yetus_debug string
```

* Description

Print a message to stderr if --debug is turned on

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `yetus_delete_entry`

* Synopsis

```
yetus_delete_entry
```

* Description

Given variable $1 delete $2 from it

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `yetus_error`

* Synopsis

```
yetus_error string
```

* Description

Print a message to stderr

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `yetus_run_and_redirect`

* Synopsis

```
yetus_run_and_redirect filename command [..]
```

* Description

run the command, sending stdout and stderr to the given filename

* Returns

## @returns      $?

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

### `yetus_verify_entry`

* Synopsis

```
yetus_verify_entry
```

* Description

Given variable $1 determine if $2 is in it

* Returns

## @returns      1 = yes, 0 = no

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

## Public/Evolving/Not Replaceable
### `list_plugins`

* Synopsis

```
list_plugins
```

* Description

List all installed plug-ins, regardless of whether they have been enabled

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Evolving |
| Replaceable | No |

## None/None/Not Replaceable
### `personality_file_tests`

* Synopsis

```
personality_file_tests
```

* Description

None

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | None |
| Stability | None |
| Replaceable | None |

### `personality_modules`

* Synopsis

```
personality_modules
```

* Description

None

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | None |
| Stability | None |
| Replaceable | None |

## Private/Evolving/Not Replaceable
### `generic_locate_patch`

* Synopsis

```
generic_locate_patch patchloc output
```

* Description

Use curl to download the patch as a last resort

* Returns

0 got something

1 error

| Classification | Level |
| :--- | :--- |
| Audience | Private |
| Stability | Evolving |
| Replaceable | None |

### `guess_patch_file`

* Synopsis

```
guess_patch_file path to patch file to test
```

* Description

Given a possible patch file, guess if it's a patch file only using the more intense verify if we really need to

* Returns

0 we think it's a patch file

1 we think it's not a patch file

| Classification | Level |
| :--- | :--- |
| Audience | Private |
| Stability | Evolving |
| Replaceable | None |
