#!/usr/bin/env python3
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
""" Handle JIRA Issues """

import http.client
import json
import logging
import re
import sys
import urllib.parse
import urllib.error
import time

try:
    import dateutil.parser
except ImportError:
    logging.error(
        ("This script requires python-dateutil module to be installed. "
         "You can install it using:\n\t pip install python-dateutil"))
    sys.exit(1)

from .utils import get_jira, to_unicode, sanitize_text

RELEASE_VERSION = {}

SORTTYPE = 'resolutiondate'
SORTORDER = 'older'
NUM_RETRIES = 5

# label to be used to mark an issue as Incompatible change.
BACKWARD_INCOMPATIBLE_LABEL = 'backward-incompatible'


class Jira:
    """A single JIRA"""
    def __init__(self, data, parent):
        self.key = data['key']
        self.fields = data['fields']
        self.parent = parent
        self.notes = None
        self.incompat = None
        self.reviewed = None
        self.important = None

    def get_id(self):
        """ get the Issue ID """
        return to_unicode(self.key)

    def get_description(self):
        """ get the description """
        return to_unicode(self.fields['description'])

    def get_release_note(self):
        """ get the release note field """
        if self.notes is None:
            field = self.parent.field_id_map['Release Note']
            if field in self.fields:
                self.notes = to_unicode(self.fields[field])
            elif self.get_incompatible_change() or self.get_important():
                self.notes = self.get_description()
            else:
                self.notes = ""
        return self.notes

    def get_priority(self):
        """ Get the priority """
        ret = ""
        pri = self.fields['priority']
        if pri is not None:
            ret = pri['name']
        return to_unicode(ret)

    def get_assignee(self):
        """ Get the assignee """
        ret = ""
        mid = self.fields['assignee']
        if mid is not None:
            ret = mid['displayName']
        return to_unicode(ret)

    def get_components(self):
        """ Get the component(s) """
        if self.fields['components']:
            return ", ".join(
                [comp['name'] for comp in self.fields['components']])
        return ""

    def get_summary(self):
        """ Get the summary """
        return self.fields['summary']

    def get_type(self):
        """ Get the Issue type """
        ret = ""
        mid = self.fields['issuetype']
        if mid is not None:
            ret = mid['name']
        return to_unicode(ret)

    def get_reporter(self):
        """ Get the issue reporter """
        ret = ""
        mid = self.fields['reporter']
        if mid is not None:
            ret = mid['displayName']
        return to_unicode(ret)

    def get_project(self):
        """ get the project """
        ret = ""
        mid = self.fields['project']
        if mid is not None:
            ret = mid['key']
        return to_unicode(ret)

    def __lt__(self, other):

        if SORTTYPE == 'issueid':
            # compare by issue name-number
            selfsplit = self.get_id().split('-')
            othersplit = other.get_id().split('-')
            result = selfsplit[0] < othersplit[0]
            if not result:
                result = int(selfsplit[1]) < int(othersplit[1])
                # dec is supported for backward compatibility
                if SORTORDER in ['dec', 'desc']:
                    result = not result

        elif SORTTYPE == 'resolutiondate':
            dts = dateutil.parser.parse(self.fields['resolutiondate'])
            dto = dateutil.parser.parse(other.fields['resolutiondate'])
            result = dts < dto
            if SORTORDER == 'newer':
                result = not result

        return result

    def get_incompatible_change(self):
        """ get incompatible flag """
        if self.incompat is None:
            field = self.parent.field_id_map['Hadoop Flags']
            self.reviewed = False
            self.incompat = False
            if field in self.fields:
                if self.fields[field]:
                    for flag in self.fields[field]:
                        if flag['value'] == "Incompatible change":
                            self.incompat = True
                        if flag['value'] == "Reviewed":
                            self.reviewed = True
            else:
                # Custom field 'Hadoop Flags' is not defined,
                # search for 'backward-incompatible' label
                field = self.parent.field_id_map['Labels']
                if field in self.fields and self.fields[field]:
                    if BACKWARD_INCOMPATIBLE_LABEL in self.fields[field]:
                        self.incompat = True
                        self.reviewed = True
        return self.incompat

    def get_important(self):
        """ get important flag """
        if self.important is None:
            field = self.parent.field_id_map['Flags']
            self.important = False
            if field in self.fields:
                if self.fields[field]:
                    for flag in self.fields[field]:
                        if flag['value'] == "Important":
                            self.important = True
        return self.important


class JiraIter:
    """An Iterator of JIRAs"""
    @staticmethod
    def collect_fields(jira_base_url):
        """send a query to JIRA and collect field-id map"""
        try:
            resp = get_jira(f"{jira_base_url}/rest/api/2/field")
            data = json.loads(resp.read())
        except (urllib.error.HTTPError, urllib.error.URLError,
                http.client.BadStatusLine, ValueError) as error:
            logging.error('Blew up trying to get a response: %s', error)
            sys.exit(1)
        field_id_map = {}
        for part in data:
            field_id_map[part['name']] = part['id']
        return field_id_map

    @staticmethod
    def query_jira(jira_base_url, ver, projects, pos):
        """send a query to JIRA and collect
        a certain number of issue information"""
        count = 100
        pjs = "','".join(projects)
        jql = f"project in ('{pjs}') and fixVersion in ('{ver}') and resolution = Fixed"
        params = urllib.parse.urlencode({
            'jql': jql,
            'startAt': pos,
            'maxResults': count
        })
        return JiraIter.load_jira(jira_base_url, params, 0)

    @staticmethod
    def load_jira(jira_base_url, params, fail_count):
        """send query to JIRA and collect with retries"""
        try:
            resp = get_jira(f"{jira_base_url}/rest/api/2/search?{params}")
        except (urllib.error.URLError, http.client.BadStatusLine) as err:
            return JiraIter.retry_load(jira_base_url, err, params, fail_count)

        try:
            data = json.loads(resp.read())
        except http.client.IncompleteRead as err:
            return JiraIter.retry_load(jira_base_url, err, params, fail_count)
        return data

    @staticmethod
    def retry_load(jira_base_url, err, params, fail_count):
        """Retry connection up to NUM_RETRIES times."""
        logging.error(err)
        fail_count += 1
        if fail_count <= NUM_RETRIES:
            logging.warning("Connection failed %s times. Retrying.",
                            fail_count)
            time.sleep(1)
            return JiraIter.load_jira(jira_base_url, params, fail_count)
        logging.error("Connection failed %s times. Aborting.", fail_count)
        sys.exit(1)

    @staticmethod
    def collect_jiras(jira_base_url, ver, projects):
        """send queries to JIRA and collect all issues
        that belongs to given version and projects"""
        jiras = []
        pos = 0
        end = 1
        while pos < end:
            data = JiraIter.query_jira(jira_base_url, ver, projects, pos)
            if 'error_messages' in data:
                logging.error("JIRA returns error message: %s",
                              data['error_messages'])
                sys.exit(1)
            pos = data['startAt'] + data['maxResults']
            end = data['total']
            jiras.extend(data['issues'])

            if ver not in RELEASE_VERSION:
                for issue in data['issues']:
                    for fix_version in issue['fields']['fixVersions']:
                        if 'releaseDate' in fix_version:
                            RELEASE_VERSION[fix_version['name']] = fix_version[
                                'releaseDate']
        return jiras

    def __init__(self, jira_base_url, version, projects):
        self.version = version
        self.projects = projects
        self.jira_base_url = jira_base_url
        self.field_id_map = JiraIter.collect_fields(jira_base_url)
        ver = str(version).replace("-SNAPSHOT", "")
        self.jiras = JiraIter.collect_jiras(jira_base_url, ver, projects)
        self.iter = self.jiras.__iter__()

    def __iter__(self):
        return self

    def __next__(self):
        """ get next """
        data = next(self.iter)
        j = Jira(data, self)
        return j


class Linter:
    """Encapsulates lint-related functionality.
    Maintains running lint statistics about JIRAs."""

    _valid_filters = [
        "incompatible", "important", "version", "component", "assignee"
    ]

    def __init__(self, version, options):
        self._warning_count = 0
        self._error_count = 0
        self._lint_message = ""
        self._version = version

        self._filters = dict(
            list(zip(self._valid_filters, [False] * len(self._valid_filters))))

        self.enabled = False
        self._parse_options(options)

    @staticmethod
    def add_parser_options(parser):
        """Add Linter options to passed optparse parser."""
        filter_string = ", ".join("'" + f + "'" for f in Linter._valid_filters)
        parser.add_argument(
            "-n",
            "--lint",
            dest="lint",
            action="append",
            type=str,
            help="Specify lint filters. Valid filters are " + filter_string +
            ". " + "'all' enables all lint filters. " +
            "Multiple filters can be specified comma-delimited and " +
            "filters can be negated, e.g. 'all,-component'.")

    def _parse_options(self, options):
        """Parse options from optparse."""

        if options.lint is None or not options.lint:
            return
        self.enabled = True

        # Valid filter specifications are
        # self._valid_filters, negations, and "all"
        valid_list = self._valid_filters
        valid_list += ["-" + v for v in valid_list]
        valid_list += ["all"]
        valid = set(valid_list)

        enabled = []
        disabled = []

        for opt in options.lint:
            for token in opt.split(","):
                if token not in valid:
                    logging.error(
                        "Unknown lint filter '%s', valid options are: %s",
                        token, ', '.join(v for v in sorted(valid)))
                    sys.exit(1)
                if token.startswith("-"):
                    disabled.append(token[1:])
                else:
                    enabled.append(token)

        for eopt in enabled:
            if eopt == "all":
                for filt in self._valid_filters:
                    self._filters[filt] = True
            else:
                self._filters[eopt] = True
        for disopt in disabled:
            self._filters[disopt] = False

    def had_errors(self):
        """Returns True if a lint error was encountered, else False."""
        return self._error_count > 0

    def message(self):
        """Return summary lint message suitable for printing to stdout."""
        if not self.enabled:
            return None
        msg = self._lint_message
        msg += "\n======================================="
        msg += f"\n{self._version}: Error:{self._error_count}, Warning:{self._warning_count} \n"
        return msg

    def _check_missing_component(self, jira):
        """Return if JIRA has a 'missing component' lint error."""
        if not self._filters["component"]:
            return False

        if jira.fields['components']:
            return False
        return True

    def _check_missing_assignee(self, jira):
        """Return if JIRA has a 'missing assignee' lint error."""
        if not self._filters["assignee"]:
            return False

        if jira.fields['assignee'] is not None:
            return False
        return True

    def _check_version_string(self, jira):
        """Return if JIRA has a version string lint error."""
        if not self._filters["version"]:
            return False

        field = jira.parent.field_id_map['Fix Version/s']
        for ver in jira.fields[field]:
            found = re.match(r'^((\d+)(\.\d+)*).*$|^(\w+\-\d+)$', ver['name'])
            if not found:
                return True
        return False

    def lint(self, jira):
        """Run lint check on a JIRA."""
        if not self.enabled:
            return
        if not jira.get_release_note():
            jiraid = sanitize_text(jira.get_id())
            if self._filters["incompatible"] and jira.get_incompatible_change(
            ):
                self._warning_count += 1
                self._lint_message += f"\nWARNING: incompatible change {jiraid} lacks release notes."  #pylint: disable=line-too-long

            if self._filters["important"] and jira.get_important():
                self._warning_count += 1
                self._lint_message += f"\nWARNING: important issue {jiraid} lacks release notes."

        if self._check_version_string(jira):
            self._warning_count += 1
            self._lint_message += f"\nWARNING: Version string problem for {jira.get_id()} "

        if self._check_missing_component(jira) or self._check_missing_assignee(
                jira):
            self._error_count += 1
            error_message = []
            if self._check_missing_component(jira):
                error_message.append("component")
            if self._check_missing_assignee(jira):
                error_message.append("assignee")
            multimessage = ' and '.join(error_message)
            self._lint_message += f"\nERROR: missing {multimessage} for {jira.get_id()} "
