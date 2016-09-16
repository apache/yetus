#!/usr/bin/env python
#
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

import re

NAME_PATTERN = re.compile(r' \([0-9]+\)')
BASE_URL = "https://issues.apache.org/jira"


def clean(input_string):
    return sanitize_markdown(re.sub(NAME_PATTERN, "", input_string))


def format_components(input_string):
    input_string = re.sub(NAME_PATTERN, '', input_string).replace("'", "")
    if input_string != "":
        ret = input_string
    else:
        # some markdown parsers don't like empty tables
        ret = "."
    return clean(ret)


# Return the string encoded as UTF-8.
#
# This is necessary for handling markdown in Python.
def encode_utf8(input_string):
    return input_string.encode('utf-8')


# Sanitize Markdown input so it can be handled by Python.
#
# The expectation is that the input is already valid Markdown,
# so no additional escaping is required.
def sanitize_markdown(input_string):
    input_string = encode_utf8(input_string)
    input_string = input_string.replace("\r", "")
    input_string = input_string.rstrip()
    return input_string


# Sanitize arbitrary text so it can be embedded in MultiMarkdown output.
#
# Note that MultiMarkdown is not Markdown, and cannot be parsed as such.
# For instance, when using pandoc, invoke it as `pandoc -f markdown_mmd`.
#
# Calls sanitize_markdown at the end as a final pass.
def sanitize_text(input_string):
    escapes = dict()
    # See: https://daringfireball.net/projects/markdown/syntax#backslash
    # We only escape a subset of special characters. We ignore characters
    # that only have significance at the start of a line.
    slash_escapes = "_<>*|"
    slash_escapes += "`"
    slash_escapes += "\\"
    all_chars = set()
    # Construct a set of escapes
    for c in slash_escapes:
        all_chars.add(c)
    for c in all_chars:
        escapes[c] = "\\" + c

    # Build the output string character by character to prevent double escaping
    output_string = ""
    for c in input_string:
        o = c
        if c in escapes:
            o = escapes[c]
        output_string += o

    return sanitize_markdown(output_string.rstrip())


# if release notes have a special marker,
# we'll treat them as already in markdown format
def processrelnote(input_string):
    relnote_pattern = re.compile('^\<\!\-\- ([a-z]+) \-\-\>')
    fmt = relnote_pattern.match(input_string)
    if fmt is None:
        return sanitize_text(input_string)
    else:
        return {
            'markdown': sanitize_markdown(input_string),
        }.get(
            fmt.group(1), sanitize_text(input_string))


def to_unicode(obj):
    if obj is None:
        return ""
    return unicode(obj)


class Outputs(object):
    """Several different files to output to at the same time"""

    def __init__(self, base_file_name, file_name_pattern, keys, params=None):
        if params is None:
            params = {}
        self.params = params
        self.base = open(base_file_name % params, 'w')
        self.others = {}
        for key in keys:
            both = dict(params)
            both['key'] = key
            self.others[key] = open(file_name_pattern % both, 'w')

    def write_all(self, pattern):
        both = dict(self.params)
        both['key'] = ''
        self.base.write(pattern % both)
        for key in self.others:
            both = dict(self.params)
            both['key'] = key
            self.others[key].write(pattern % both)

    def write_key_raw(self, key, input_string):
        self.base.write(input_string)
        if key in self.others:
            self.others[key].write(input_string)

    def close(self):
        self.base.close()
        for value in self.others.values():
            value.close()

    def write_list(self, mylist):
        for jira in sorted(mylist):
            line = '| [%s](' + BASE_URL + '/browse/%s) ' +\
                   '| %s |  %s | %s | %s | %s |\n'
            line = line % (encode_utf8(jira.get_id()),
                           encode_utf8(jira.get_id()),
                           sanitize_text(jira.get_summary()),
                           sanitize_text(jira.get_priority()),
                           format_components(jira.get_components()),
                           sanitize_text(jira.get_reporter()),
                           sanitize_text(jira.get_assignee()))
            self.write_key_raw(jira.get_project(), line)
