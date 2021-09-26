#!/usr/bin/env python3
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
""" Utility methods used by releasedocmaker """

import base64
import os
import re
import urllib.request
import urllib.error
import urllib.parse
import sys
import json
import http.client

sys.dont_write_bytecode = True

NAME_PATTERN = re.compile(r' \([0-9]+\)')


def get_jira(jira_url):
    """ Provide standard method for fetching content from apache jira and
        handling of potential errors. Returns urllib2 response or
        raises one of several exceptions."""

    username = os.environ.get('RDM_JIRA_USERNAME')
    password = os.environ.get('RDM_JIRA_PASSWORD')

    req = urllib.request.Request(jira_url)
    if username and password:
        basicauth = base64.b64encode(f"{username}:{password}").replace(
            '\n', '')
        req.add_header('Authorization', f'Basic {basicauth}')

    try:
        response = urllib.request.urlopen(req)  # pylint: disable=consider-using-with
    except urllib.error.HTTPError as http_err:
        code = http_err.code
        print(f"JIRA returns HTTP error {code}: {http_err.msg}. Aborting.")
        error_response = http_err.read()
        try:
            error_response = json.loads(error_response)
            print("- Please ensure that specified authentication, projects,"\
                  " fixVersions etc. are correct.")
            for message in error_response['errorMessages']:
                print("-", message)
        except ValueError:
            print("FATAL: Could not parse json response from server.")
        sys.exit(1)
    except urllib.error.URLError as url_err:
        print(f"Error contacting JIRA: {jira_url}\n")
        print(f"Reason: {url_err.reason}")
        raise url_err
    except http.client.BadStatusLine as err:
        raise err
    return response


def format_components(input_string):
    """ format the string """
    input_string = re.sub(NAME_PATTERN, '', input_string).replace("'", "")
    if input_string != "":
        ret = input_string
    else:
        # some markdown parsers don't like empty tables
        ret = "."
    return sanitize_markdown(re.sub(NAME_PATTERN, "", ret))


def sanitize_markdown(input_string):
    """ Sanitize Markdown input so it can be handled by Python.

        The expectation is that the input is already valid Markdown,
        so no additional escaping is required. """
    input_string = input_string.replace('\r', '')
    input_string = input_string.rstrip()
    return input_string


def sanitize_text(input_string):
    """ Sanitize arbitrary text so it can be embedded in MultiMarkdown output.

      Note that MultiMarkdown is not Markdown, and cannot be parsed as such.
      For instance, when using pandoc, invoke it as `pandoc -f markdown_mmd`.

      Calls sanitize_markdown at the end as a final pass.
    """
    escapes = {}
    # See: https://daringfireball.net/projects/markdown/syntax#backslash
    # We only escape a subset of special characters. We ignore characters
    # that only have significance at the start of a line.
    slash_escapes = "_<>*|"
    slash_escapes += "`"
    slash_escapes += "\\"
    all_chars = set()
    # Construct a set of escapes
    for char in slash_escapes:
        all_chars.add(char)
    for char in all_chars:
        escapes[char] = "\\" + char

    # Build the output string character by character to prevent double escaping
    output_string = ""
    for char in input_string:
        out = char
        if escapes.get(char):
            out = escapes[char]
        output_string += out

    return sanitize_markdown(output_string.rstrip())


def processrelnote(input_string):
    """ if release notes have a special marker, we'll treat them as already in markdown format """
    relnote_pattern = re.compile(r'^\<\!\-\- ([a-z]+) \-\-\>')
    fmt = relnote_pattern.match(input_string)
    if fmt is None:
        return sanitize_text(input_string)
    return {
        'markdown': sanitize_markdown(input_string),
    }.get(fmt.group(1), sanitize_text(input_string))


def to_unicode(obj):
    """ convert string to unicode """
    if obj is None:
        return ""
    return str(obj)


class Outputs:
    """Several different files to output to at the same time"""
    def __init__(self, base_file_name, file_name_pattern, keys, params=None):
        if params is None:
            params = {}
        self.params = params
        self.base = open(base_file_name % params, 'w', encoding='utf-8')  # pylint: disable=consider-using-with
        self.others = {}
        for key in keys:
            both = dict(params)
            both['key'] = key
            filename = file_name_pattern % both
            self.others[key] = open(filename, 'w', encoding='utf-8')  # pylint: disable=consider-using-with

    def write_all(self, pattern):
        """ write everything given a pattern """
        both = dict(self.params)
        both['key'] = ''
        self.base.write(pattern % both)
        for key, filehandle in self.others.items():
            both = dict(self.params)
            both['key'] = key
            filehandle.write(pattern % both)

    def write_key_raw(self, key, input_string):
        """ write everything without changes """
        self.base.write(input_string)
        if key in self.others:
            self.others[key].write(input_string.decode("utf-8"))

    def close(self):
        """ close all the outputs """
        self.base.close()
        for value in list(self.others.values()):
            value.close()

    def write_list(self, mylist, skip_credits, base_url):
        """ Take a Jira object and write out the relevants parts in a multimarkdown table line"""
        for jira in sorted(mylist):
            if skip_credits:
                line = '| [{id}]({base_url}/browse/{id}) | {summary} |  ' \
                       '{priority} | {component} |\n'
            else:
                line = '| [{id}]({base_url}/browse/{id}) | {summary} |  ' \
                       '{priority} | {component} | {reporter} | {assignee} |\n'
            args = {
                'id': jira.get_id(),
                'base_url': base_url,
                'summary': sanitize_text(jira.get_summary()),
                'priority': sanitize_text(jira.get_priority()),
                'component': format_components(jira.get_components()),
                'reporter': sanitize_text(jira.get_reporter()),
                'assignee': sanitize_text(jira.get_assignee())
            }
            line = line.format(**args)
            self.write_key_raw(jira.get_project(), line)
