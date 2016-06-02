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

qbt
===

`qbt` is a command to execute test-patch without a patch.  It uses
the same plug-ins and the same options as test-patch.  The only
difference is that no patch file, location, etc should be supplied.
It is meant to be a way to easily get test-patch's output on your
current source tree.  It is suitable to be run as a regularly
scheduled build as part of your overall development strategy.

# Reporting

When using an automation tool, it may be useful to use the
`--console-report-file` option to send the summary email to a
file. This can then be used with systems like Jenkin's
email-ext plug-in to send the output as an emailed report:

```
${FILE,path="<report-file-path>"}
```

For something a bit more structured, there is also the `--html-report-file`
option.  Using this output, again with Jenkins' email-ext plug-in, it is
possible to build some very nice looking output that is easily customized:

```
<html>
<head>
<style>
table {
    border-collapse: collapse;
}
table, th, td {
   border: 1px solid black;
}
tr:nth-child(even){background-color: #f2f2f2}
</style>
</head>
<body>
<p>See the <a href="${BUILD_URL}">Jenkins Build</a> for more information.</p>
<p>${CHANGES, format="<div>[%d] (%a) %m</div>"}</p>
<p></p>
${FILE,path="<report-file-path>"}
</body></html>
```

If your mailing lists do not allow HTML-formatted email, then the `--brief-report-file`
provides a solution.  This option creates a very plain, reduced content text file
suitable for email.  It contains just the barebones information needed to get
information on failures: what voted -1, what tests failed, what subsystems are long
running (configurable with the `--brief-report-long` opton), and a list of any
attached log files.

NOTE: Be aware that ASF mailing lists do not allow HTML formatted email.

# Archiving

It may be useful to save off certain files while qbt is running for more
post-processing by another utility.  If the `rsync` command is available,
then the archiving functionality may be used.

The `--archive-list` option takes a comma separated list of `find -name`
patterns and copies them to the patch directory's archiver subdirectory.
It will preserve the directory structure of the source tree so that
multiple matching file names will be preserved.
