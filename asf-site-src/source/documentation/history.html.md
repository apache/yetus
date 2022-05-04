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

# History of Apache Yetus

## Precommit

The origins of the project start with a single Hudson job, long lost to the mists of time. The
purpose was to run a few basic tests against the Apache Hadoop source tree so that developers
would not have to re-run common tests before trying to merge a commit.  Eventually this
Hudson job would get turned into a shell script that sat in the Apache Hadoop's source
repository so that anyone could run it without trying to tie up Hudson.

As Hadoop's needs increased and as the "Big Data" projects grew in the Apache Software
Foundation, `test-patch.sh` was getting copied from Hadoop into these other repos.
Time passed and all of these copies diverged.

In 2015, the Apache Hadoop project did a major rewrite (HADOOP-11746) to take advantage
of new tooling and to deal with the heavy burden of testing a very large code base.
Other projects took note and it was felt that it was time to combine everyone's efforts
into a single project, using the new Apache Hadoop code as the starting point.

Thus, Apache Yetus was born.

## Other Parts

While splitting off the patch testing facilities, it was thought that other portions that
were equally useful and in some cases followed a similar path should also be copied into
the Apache Yetus repository.  When it came time to split from Apache Hadoop, the
`audience-annotations`, `releasedocmaker`, and `shelldocs` portions were also copied over.

# Old Source

Due to coming from Apache Hadoop, the source repository history is extremely messy.  The
project underwent many major changes that make following changes much more difficult,
including splitting the project into multiple different repos, svn->git source migration,
and changing the build tooling from `ant` to `maven`.  As a result, the first commit
in the repository history is not actually the first commit. In order to provide a
clearer picture, the `prehistory` repository tag documents the code changes that
happened to the `test-patch.sh` script prior to the first commit in the `main` branch.
