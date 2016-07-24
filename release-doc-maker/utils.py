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
    return markdown_sanitize(re.sub(NAME_PATTERN, "", input_string))


def format_components(input_string):
    input_string = re.sub(NAME_PATTERN, '', input_string).replace("'", "")
    if input_string != "":
        ret = input_string
    else:
        # some markdown parsers don't like empty tables
        ret = "."
    return clean(ret)


# convert to utf-8
def markdown_sanitize(input_string):
    input_string = input_string.encode('utf-8')
    input_string = input_string.replace("\r", "")
    input_string = input_string.rstrip()
    return input_string


# same thing as markdownsanitize,
# except markdown metachars are also
# escaped as well as more
# things we don't want doxia, etc, to
# screw up
def text_sanitize(input_string):
    input_string = markdown_sanitize(input_string)
    input_string = input_string.replace("_", r"\_")
    input_string = input_string.replace("|", r"\|")
    input_string = input_string.replace("<", r"\<")
    input_string = input_string.replace(">", r"\>")
    input_string = input_string.replace("*", r"\*")
    input_string = input_string.rstrip()
    return input_string


# if release notes have a special marker,
# we'll treat them as already in markdown format
def processrelnote(input_string):
    relnote_pattern = re.compile('^\<\!\-\- ([a-z]+) \-\-\>')
    fmt = relnote_pattern.match(input_string)
    if fmt is None:
        return text_sanitize(input_string)
    else:
        return {
            'markdown': markdown_sanitize(input_string),
        }.get(
            fmt.group(1), text_sanitize(input_string))


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
            line = line % (text_sanitize(jira.get_id()),
                           text_sanitize(jira.get_id()),
                           text_sanitize(jira.get_summary()),
                           text_sanitize(jira.get_priority()),
                           format_components(jira.get_components()),
                           text_sanitize(jira.get_reporter()),
                           text_sanitize(jira.get_assignee()))
            self.write_key_raw(jira.get_project(), line)
