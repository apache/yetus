
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
  * Public/Stable/Not Replaceable
    * [bugzilla\_write\_comment](#bugzilla_write_comment)
    * [github\_write\_comment](#github_write_comment)
  * Public/Stable/Not Replaceable
    * [javac\_precheck](#javac_precheck)
  * Public/Stable/Not Replaceable
    * [jira\_write\_comment](#jira_write_comment)
  * None/None/Not Replaceable
    * [ant\_buildfile](#ant_buildfile)
    * [ant\_builtin\_personality\_file\_tests](#ant_builtin_personality_file_tests)
    * [ant\_builtin\_personality\_modules](#ant_builtin_personality_modules)
    * [ant\_docker\_support](#ant_docker_support)
    * [ant\_executor](#ant_executor)
    * [ant\_initialize](#ant_initialize)
    * [ant\_javac\_count\_probs](#ant_javac_count_probs)
    * [ant\_modules\_worker](#ant_modules_worker)
    * [ant\_parse\_args](#ant_parse_args)
    * [ant\_usage](#ant_usage)
    * [asflicense\_parse\_args](#asflicense_parse_args)
    * [asflicense\_writexsl](#asflicense_writexsl)
    * [bugzilla\_determine\_issue](#bugzilla_determine_issue)
    * [bugzilla\_http\_fetch](#bugzilla_http_fetch)
    * [bugzilla\_locate\_patch](#bugzilla_locate_patch)
    * [bugzilla\_parse\_args](#bugzilla_parse_args)
    * [bugzilla\_usage](#bugzilla_usage)
    * [cc\_count\_probs](#cc_count_probs)
    * [cc\_filefilter](#cc_filefilter)
    * [checkstyle\_filefilter](#checkstyle_filefilter)
    * [checkstyle\_postapply](#checkstyle_postapply)
    * [checkstyle\_postcompile](#checkstyle_postcompile)
    * [checkstyle\_preapply](#checkstyle_preapply)
    * [checkstyle\_runner](#checkstyle_runner)
    * [findbugs\_filefilter](#findbugs_filefilter)
    * [findbugs\_parse\_args](#findbugs_parse_args)
    * [findbugs\_rebuild](#findbugs_rebuild)
    * [findbugs\_usage](#findbugs_usage)
    * [github\_breakup\_url](#github_breakup_url)
    * [github\_determine\_issue](#github_determine_issue)
    * [github\_find\_jira\_title](#github_find_jira_title)
    * [github\_jira\_bridge](#github_jira_bridge)
    * [github\_linecomments](#github_linecomments)
    * [github\_locate\_patch](#github_locate_patch)
    * [github\_parse\_args](#github_parse_args)
    * [github\_usage](#github_usage)
    * [gradle\_buildfile](#gradle_buildfile)
    * [gradle\_builtin\_personality\_file\_tests](#gradle_builtin_personality_file_tests)
    * [gradle\_builtin\_personality\_modules](#gradle_builtin_personality_modules)
    * [gradle\_docker\_support](#gradle_docker_support)
    * [gradle\_executor](#gradle_executor)
    * [gradle\_initialize](#gradle_initialize)
    * [gradle\_javac\_count\_probs](#gradle_javac_count_probs)
    * [gradle\_javadoc\_count\_probs](#gradle_javadoc_count_probs)
    * [gradle\_modules\_worker](#gradle_modules_worker)
    * [gradle\_parse\_args](#gradle_parse_args)
    * [gradle\_scalac\_count\_probs](#gradle_scalac_count_probs)
    * [gradle\_usage](#gradle_usage)
    * [initialize\_java](#initialize_java)
    * [javac\_filefilter](#javac_filefilter)
    * [javac\_initialize](#javac_initialize)
    * [javadoc\_filefilter](#javadoc_filefilter)
    * [javadoc\_initialize](#javadoc_initialize)
    * [jira\_determine\_issue](#jira_determine_issue)
    * [jira\_http\_fetch](#jira_http_fetch)
    * [jira\_locate\_patch](#jira_locate_patch)
    * [jira\_parse\_args](#jira_parse_args)
    * [jira\_usage](#jira_usage)
    * [junit\_finalize\_results](#junit_finalize_results)
    * [junit\_process\_tests](#junit_process_tests)
    * [maven\_buildfile](#maven_buildfile)
    * [maven\_builtin\_personality\_file\_tests](#maven_builtin_personality_file_tests)
    * [maven\_builtin\_personality\_modules](#maven_builtin_personality_modules)
    * [maven\_docker\_support](#maven_docker_support)
    * [maven\_executor](#maven_executor)
    * [maven\_initialize](#maven_initialize)
    * [maven\_javac\_count\_probs](#maven_javac_count_probs)
    * [maven\_modules\_worker](#maven_modules_worker)
    * [maven\_parse\_args](#maven_parse_args)
    * [maven\_precheck](#maven_precheck)
    * [maven\_scalac\_count\_probs](#maven_scalac_count_probs)
    * [maven\_usage](#maven_usage)
    * [mvnsite\_filefilter](#mvnsite_filefilter)
    * [nobuild\_buildfile](#nobuild_buildfile)
    * [nobuild\_builtin\_personality\_file\_tests](#nobuild_builtin_personality_file_tests)
    * [nobuild\_builtin\_personality\_modules](#nobuild_builtin_personality_modules)
    * [nobuild\_executor](#nobuild_executor)
    * [nobuild\_modules\_worker](#nobuild_modules_worker)
    * [perlcritic\_filefilter](#perlcritic_filefilter)
    * [perlcritic\_parse\_args](#perlcritic_parse_args)
    * [perlcritic\_postapply](#perlcritic_postapply)
    * [perlcritic\_postcompile](#perlcritic_postcompile)
    * [perlcritic\_preapply](#perlcritic_preapply)
    * [perlcritic\_usage](#perlcritic_usage)
    * [pylint\_filefilter](#pylint_filefilter)
    * [pylint\_parse\_args](#pylint_parse_args)
    * [pylint\_postapply](#pylint_postapply)
    * [pylint\_postcompile](#pylint_postcompile)
    * [pylint\_preapply](#pylint_preapply)
    * [pylint\_usage](#pylint_usage)
    * [rubocop\_filefilter](#rubocop_filefilter)
    * [rubocop\_parse\_args](#rubocop_parse_args)
    * [rubocop\_postapply](#rubocop_postapply)
    * [rubocop\_postcompile](#rubocop_postcompile)
    * [rubocop\_preapply](#rubocop_preapply)
    * [rubocop\_usage](#rubocop_usage)
    * [ruby\_lint\_filefilter](#ruby_lint_filefilter)
    * [ruby\_lint\_parse\_args](#ruby_lint_parse_args)
    * [ruby\_lint\_postapply](#ruby_lint_postapply)
    * [ruby\_lint\_postcompile](#ruby_lint_postcompile)
    * [ruby\_lint\_preapply](#ruby_lint_preapply)
    * [ruby\_lint\_usage](#ruby_lint_usage)
    * [scalac\_filefilter](#scalac_filefilter)
    * [scaladoc\_filefilter](#scaladoc_filefilter)
    * [shellcheck\_filefilter](#shellcheck_filefilter)
    * [shellcheck\_postapply](#shellcheck_postapply)
    * [shellcheck\_postcompile](#shellcheck_postcompile)
    * [shellcheck\_preapply](#shellcheck_preapply)
    * [shellcheck\_private\_findbash](#shellcheck_private_findbash)
    * [tap\_finalize\_results](#tap_finalize_results)
    * [tap\_parse\_args](#tap_parse_args)
    * [tap\_process\_tests](#tap_process_tests)
    * [tap\_usage](#tap_usage)
    * [whitespace\_linecomment\_reporter](#whitespace_linecomment_reporter)
    * [whitespace\_postcompile](#whitespace_postcompile)
    * [xml\_filefilter](#xml_filefilter)
    * [xml\_postcompile](#xml_postcompile)

------

## Public/Stable/Not Replaceable
### `bugzilla_write_comment`

* Synopsis

```
bugzilla_write_comment ## @params filename
```

* Description

Write the contents of a file to Bugzilla

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | None |

### `github_write_comment`

* Synopsis

```
github_write_comment ## @params filename
```

* Description

Write the contents of a file to github

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | None |

## Public/Stable/Not Replaceable
### `javac_precheck`

* Synopsis

```
javac_precheck
```

* Description

Verify that ${JAVA_HOME} is defined

* Returns

1 - no JAVA_HOME

0 - JAVA_HOME defined

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | No |

## Public/Stable/Not Replaceable
### `jira_write_comment`

* Synopsis

```
jira_write_comment ## @params filename
```

* Description

Write the contents of a file to JIRA

* Returns

## @returns exit code from posting to jira

| Classification | Level |
| :--- | :--- |
| Audience | Public |
| Stability | Stable |
| Replaceable | None |

## None/None/Not Replaceable
### `ant_buildfile`

* Synopsis

```
ant_buildfile
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

### `ant_builtin_personality_file_tests`

* Synopsis

```
ant_builtin_personality_file_tests
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

### `ant_builtin_personality_modules`

* Synopsis

```
ant_builtin_personality_modules
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

### `ant_docker_support`

* Synopsis

```
ant_docker_support
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

### `ant_executor`

* Synopsis

```
ant_executor
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

### `ant_initialize`

* Synopsis

```
ant_initialize
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

### `ant_javac_count_probs`

* Synopsis

```
ant_javac_count_probs
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

### `ant_modules_worker`

* Synopsis

```
ant_modules_worker
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

### `ant_parse_args`

* Synopsis

```
ant_parse_args
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

### `ant_usage`

* Synopsis

```
ant_usage
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

### `asflicense_parse_args`

* Synopsis

```
asflicense_parse_args
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

### `asflicense_writexsl`

* Synopsis

```
asflicense_writexsl
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

### `bugzilla_determine_issue`

* Synopsis

```
bugzilla_determine_issue
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

### `bugzilla_http_fetch`

* Synopsis

```
bugzilla_http_fetch
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

### `bugzilla_locate_patch`

* Synopsis

```
bugzilla_locate_patch
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

### `bugzilla_parse_args`

* Synopsis

```
bugzilla_parse_args
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

### `bugzilla_usage`

* Synopsis

```
bugzilla_usage
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

### `cc_count_probs`

* Synopsis

```
cc_count_probs
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

### `cc_filefilter`

* Synopsis

```
cc_filefilter
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

### `checkstyle_filefilter`

* Synopsis

```
checkstyle_filefilter
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

### `checkstyle_postapply`

* Synopsis

```
checkstyle_postapply
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

### `checkstyle_postcompile`

* Synopsis

```
checkstyle_postcompile
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

### `checkstyle_preapply`

* Synopsis

```
checkstyle_preapply
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

### `checkstyle_runner`

* Synopsis

```
checkstyle_runner
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

### `findbugs_filefilter`

* Synopsis

```
findbugs_filefilter
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

### `findbugs_parse_args`

* Synopsis

```
findbugs_parse_args
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

### `findbugs_rebuild`

* Synopsis

```
findbugs_rebuild
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

### `findbugs_usage`

* Synopsis

```
findbugs_usage
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

### `github_breakup_url`

* Synopsis

```
github_breakup_url ## @params url
```

* Description

given a URL, break it up into github plugin globals this will *override* any personality or yetus defaults

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | None |
| Stability | None |
| Replaceable | None |

### `github_determine_issue`

* Synopsis

```
github_determine_issue
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

### `github_find_jira_title`

* Synopsis

```
github_find_jira_title
```

* Description

based upon a github PR, attempt to link back to JIRA

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | None |
| Stability | None |
| Replaceable | None |

### `github_jira_bridge`

* Synopsis

```
github_jira_bridge
```

* Description

this gets called when JIRA thinks this issue is just a pointer to github WARNING: Called from JIRA plugin!

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | None |
| Stability | None |
| Replaceable | None |

### `github_linecomments`

* Synopsis

```
github_linecomments
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

### `github_locate_patch`

* Synopsis

```
github_locate_patch
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

### `github_parse_args`

* Synopsis

```
github_parse_args
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

### `github_usage`

* Synopsis

```
github_usage
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

### `gradle_buildfile`

* Synopsis

```
gradle_buildfile
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

### `gradle_builtin_personality_file_tests`

* Synopsis

```
gradle_builtin_personality_file_tests
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

### `gradle_builtin_personality_modules`

* Synopsis

```
gradle_builtin_personality_modules
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

### `gradle_docker_support`

* Synopsis

```
gradle_docker_support
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

### `gradle_executor`

* Synopsis

```
gradle_executor
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

### `gradle_initialize`

* Synopsis

```
gradle_initialize
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

### `gradle_javac_count_probs`

* Synopsis

```
gradle_javac_count_probs
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

### `gradle_javadoc_count_probs`

* Synopsis

```
gradle_javadoc_count_probs
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

### `gradle_modules_worker`

* Synopsis

```
gradle_modules_worker
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

### `gradle_parse_args`

* Synopsis

```
gradle_parse_args
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

### `gradle_scalac_count_probs`

* Synopsis

```
gradle_scalac_count_probs
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

### `gradle_usage`

* Synopsis

```
gradle_usage
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

### `initialize_java`

* Synopsis

```
initialize_java
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

### `javac_filefilter`

* Synopsis

```
javac_filefilter
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

### `javac_initialize`

* Synopsis

```
javac_initialize
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

### `javadoc_filefilter`

* Synopsis

```
javadoc_filefilter
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

### `javadoc_initialize`

* Synopsis

```
javadoc_initialize
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

### `jira_determine_issue`

* Synopsis

```
jira_determine_issue
```

* Description

provides issue determination based upon the URL and more. WARNING: called from the github plugin!

* Returns

Nothing

| Classification | Level |
| :--- | :--- |
| Audience | None |
| Stability | None |
| Replaceable | None |

### `jira_http_fetch`

* Synopsis

```
jira_http_fetch
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

### `jira_locate_patch`

* Synopsis

```
jira_locate_patch
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

### `jira_parse_args`

* Synopsis

```
jira_parse_args
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

### `jira_usage`

* Synopsis

```
jira_usage
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

### `junit_finalize_results`

* Synopsis

```
junit_finalize_results
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

### `junit_process_tests`

* Synopsis

```
junit_process_tests
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

### `maven_buildfile`

* Synopsis

```
maven_buildfile
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

### `maven_builtin_personality_file_tests`

* Synopsis

```
maven_builtin_personality_file_tests
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

### `maven_builtin_personality_modules`

* Synopsis

```
maven_builtin_personality_modules
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

### `maven_docker_support`

* Synopsis

```
maven_docker_support
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

### `maven_executor`

* Synopsis

```
maven_executor
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

### `maven_initialize`

* Synopsis

```
maven_initialize
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

### `maven_javac_count_probs`

* Synopsis

```
maven_javac_count_probs
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

### `maven_modules_worker`

* Synopsis

```
maven_modules_worker
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

### `maven_parse_args`

* Synopsis

```
maven_parse_args
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

### `maven_precheck`

* Synopsis

```
maven_precheck
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

### `maven_scalac_count_probs`

* Synopsis

```
maven_scalac_count_probs
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

### `maven_usage`

* Synopsis

```
maven_usage
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

### `mvnsite_filefilter`

* Synopsis

```
mvnsite_filefilter
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

### `nobuild_buildfile`

* Synopsis

```
nobuild_buildfile
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

### `nobuild_builtin_personality_file_tests`

* Synopsis

```
nobuild_builtin_personality_file_tests
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

### `nobuild_builtin_personality_modules`

* Synopsis

```
nobuild_builtin_personality_modules
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

### `nobuild_executor`

* Synopsis

```
nobuild_executor
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

### `nobuild_modules_worker`

* Synopsis

```
nobuild_modules_worker
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

### `perlcritic_filefilter`

* Synopsis

```
perlcritic_filefilter
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

### `perlcritic_parse_args`

* Synopsis

```
perlcritic_parse_args
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

### `perlcritic_postapply`

* Synopsis

```
perlcritic_postapply
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

### `perlcritic_postcompile`

* Synopsis

```
perlcritic_postcompile
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

### `perlcritic_preapply`

* Synopsis

```
perlcritic_preapply
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

### `perlcritic_usage`

* Synopsis

```
perlcritic_usage
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

### `pylint_filefilter`

* Synopsis

```
pylint_filefilter
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

### `pylint_parse_args`

* Synopsis

```
pylint_parse_args
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

### `pylint_postapply`

* Synopsis

```
pylint_postapply
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

### `pylint_postcompile`

* Synopsis

```
pylint_postcompile
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

### `pylint_preapply`

* Synopsis

```
pylint_preapply
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

### `pylint_usage`

* Synopsis

```
pylint_usage
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

### `rubocop_filefilter`

* Synopsis

```
rubocop_filefilter
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

### `rubocop_parse_args`

* Synopsis

```
rubocop_parse_args
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

### `rubocop_postapply`

* Synopsis

```
rubocop_postapply
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

### `rubocop_postcompile`

* Synopsis

```
rubocop_postcompile
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

### `rubocop_preapply`

* Synopsis

```
rubocop_preapply
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

### `rubocop_usage`

* Synopsis

```
rubocop_usage
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

### `ruby_lint_filefilter`

* Synopsis

```
ruby_lint_filefilter
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

### `ruby_lint_parse_args`

* Synopsis

```
ruby_lint_parse_args
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

### `ruby_lint_postapply`

* Synopsis

```
ruby_lint_postapply
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

### `ruby_lint_postcompile`

* Synopsis

```
ruby_lint_postcompile
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

### `ruby_lint_preapply`

* Synopsis

```
ruby_lint_preapply
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

### `ruby_lint_usage`

* Synopsis

```
ruby_lint_usage
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

### `scalac_filefilter`

* Synopsis

```
scalac_filefilter
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

### `scaladoc_filefilter`

* Synopsis

```
scaladoc_filefilter
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

### `shellcheck_filefilter`

* Synopsis

```
shellcheck_filefilter
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

### `shellcheck_postapply`

* Synopsis

```
shellcheck_postapply
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

### `shellcheck_postcompile`

* Synopsis

```
shellcheck_postcompile
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

### `shellcheck_preapply`

* Synopsis

```
shellcheck_preapply
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

### `shellcheck_private_findbash`

* Synopsis

```
shellcheck_private_findbash
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

### `tap_finalize_results`

* Synopsis

```
tap_finalize_results
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

### `tap_parse_args`

* Synopsis

```
tap_parse_args
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

### `tap_process_tests`

* Synopsis

```
tap_process_tests
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

### `tap_usage`

* Synopsis

```
tap_usage
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

### `whitespace_linecomment_reporter`

* Synopsis

```
whitespace_linecomment_reporter
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

### `whitespace_postcompile`

* Synopsis

```
whitespace_postcompile
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

### `xml_filefilter`

* Synopsis

```
xml_filefilter
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

### `xml_postcompile`

* Synopsis

```
xml_postcompile
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
