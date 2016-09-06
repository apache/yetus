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

from glob import glob
from optparse import OptionParser
from time import gmtime, strftime, sleep
from distutils.version import LooseVersion
import errno
import os
import re
import shutil
import sys
import urllib
import urllib2
import httplib
import json
from utils import to_unicode, sanitize_text, processrelnote, Outputs


try:
    import dateutil.parser
except ImportError:
    print "This script requires python-dateutil module to be installed. " \
          "You can install it using:\n\t pip install python-dateutil"
    sys.exit(1)

RELEASE_VERSION = {}

JIRA_BASE_URL = "https://issues.apache.org/jira"
SORTTYPE = 'resolutiondate'
SORTORDER = 'older'
NUM_RETRIES = 5

# label to be used to mark an issue as Incompatible change.
BACKWARD_INCOMPATIBLE_LABEL = 'backward-incompatible'
CHANGEHDR1 = "| JIRA | Summary | Priority | " + \
             "Component | Reporter | Contributor |\n"
CHANGEHDR2 = "|:---- |:---- | :--- |:---- |:---- |:---- |\n"

ASF_LICENSE = '''
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
'''


def buildindex(title, asf_license):
    """Write an index file for later conversion using mvn site"""
    versions = glob("[0-9]*.[0-9]*")
    versions.sort(key=LooseVersion, reverse=True)
    with open("index.md", "w") as indexfile:
        if asf_license is True:
            indexfile.write(ASF_LICENSE)
        for version in versions:
            indexfile.write("* %s v%s\n" % (title, version))
            for k in ("Changes", "Release Notes"):
                indexfile.write("    * [%s](%s/%s.%s.html)\n" %
                                (k, version, k.upper().replace(" ", ""),
                                 version))


def buildreadme(title, asf_license):
    """Write an index file for Github using README.md"""
    versions = glob("[0-9]*.[0-9]*")
    versions.sort(key=LooseVersion, reverse=True)
    with open("README.md", "w") as indexfile:
        if asf_license is True:
            indexfile.write(ASF_LICENSE)
        for version in versions:
            indexfile.write("* %s v%s\n" % (title, version))
            for k in ("Changes", "Release Notes"):
                indexfile.write("    * [%s](%s/%s.%s.md)\n" %
                                (k, version, k.upper().replace(" ", ""),
                                 version))


class GetVersions(object):
    """ List of version strings """

    def __init__(self, versions, projects):
        versions = versions
        projects = projects
        self.newversions = []
        versions.sort(key=LooseVersion)
        print "Looking for %s through %s" % (versions[0], versions[-1])
        newversions = set()
        for project in projects:
            url = JIRA_BASE_URL + \
              "/rest/api/2/project/%s/versions" % project.upper()
            try:
                resp = urllib2.urlopen(url)
            except urllib2.HTTPError as err:
                code = err.code
                print "JIRA returns HTTP error %d: %s. Aborting." % (code, err.msg)
                error_response = err.read()
                try:
                    error_response = json.loads(error_response)
                    print "- Please ensure that specified projects are correct."
                    for message in error_response['errorMessages']:
                        print "-", message
                except Exception:
                    print "Couldn't parse server response."
                sys.exit(1)
            datum = json.loads(resp.read())
            for data in datum:
                newversions.add(data['name'])
        newlist = list(newversions.copy())
        newlist.append(versions[0])
        newlist.append(versions[-1])
        newlist.sort(key=LooseVersion)
        start_index = newlist.index(versions[0])
        end_index = len(newlist) - 1 - newlist[::-1].index(versions[-1])
        for newversion in newlist[start_index + 1:end_index]:
            if newversion in newversions:
                print "Adding %s to the list" % newversion
                self.newversions.append(newversion)

    def getlist(self):
        return self.newversions


class Version(object):
    """Represents a version number"""

    def __init__(self, data):
        self.mod = False
        self.data = data
        found = re.match(r'^((\d+)(\.\d+)*).*$', data)
        if found:
            self.parts = [int(p) for p in found.group(1).split('.')]
        else:
            self.parts = []
        # backfill version with zeroes if missing parts
        self.parts.extend((0,) * (3 - len(self.parts)))

    def __str__(self):
        if self.mod:
            return '.'.join([str(p) for p in self.parts])
        return self.data

    def __cmp__(self, other):
        return cmp(self.parts, other.parts)


class Jira(object):
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
        return to_unicode(self.key)

    def get_description(self):
        return to_unicode(self.fields['description'])

    def get_release_note(self):
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
        ret = ""
        pri = self.fields['priority']
        if pri is not None:
            ret = pri['name']
        return to_unicode(ret)

    def get_assignee(self):
        ret = ""
        mid = self.fields['assignee']
        if mid is not None:
            ret = mid['displayName']
        return to_unicode(ret)

    def get_components(self):
        if len(self.fields['components']) > 0:
            return ", ".join([comp['name'] for comp in self.fields['components']
                             ])
        else:
            return ""

    def get_summary(self):
        return self.fields['summary']

    def get_type(self):
        ret = ""
        mid = self.fields['issuetype']
        if mid is not None:
            ret = mid['name']
        return to_unicode(ret)

    def get_reporter(self):
        ret = ""
        mid = self.fields['reporter']
        if mid is not None:
            ret = mid['displayName']
        return to_unicode(ret)

    def get_project(self):
        ret = ""
        mid = self.fields['project']
        if mid is not None:
            ret = mid['key']
        return to_unicode(ret)

    def __cmp__(self, other):
        result = 0

        if SORTTYPE == 'issueid':
            # compare by issue name-number
            selfsplit = self.get_id().split('-')
            othersplit = other.get_id().split('-')
            result = cmp(selfsplit[0], othersplit[0])
            if result == 0:
                result = cmp(int(selfsplit[1]), int(othersplit[1]))
                # dec is supported for backward compatibility
                if SORTORDER in ['dec', 'desc']:
                        result *= -1

        elif SORTTYPE == 'resolutiondate':
            dts = dateutil.parser.parse(self.fields['resolutiondate'])
            dto = dateutil.parser.parse(other.fields['resolutiondate'])
            result = cmp(dts, dto)
            if SORTORDER == 'newer':
                    result *= -1

        return result

    def get_incompatible_change(self):
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
        if self.important is None:
            field = self.parent.field_id_map['Flags']
            self.important = False
            if field in self.fields:
                if self.fields[field]:
                    for flag in self.fields[field]:
                        if flag['value'] == "Important":
                            self.important = True
        return self.important


class JiraIter(object):
    """An Iterator of JIRAs"""

    @staticmethod
    def collect_fields():
        """send a query to JIRA and collect field-id map"""
        resp = urllib2.urlopen(JIRA_BASE_URL + "/rest/api/2/field")
        data = json.loads(resp.read())
        field_id_map = {}
        for part in data:
            field_id_map[part['name']] = part['id']
        return field_id_map

    @staticmethod
    def query_jira(ver, projects, pos):
        """send a query to JIRA and collect
        a certain number of issue information"""
        count = 100
        pjs = "','".join(projects)
        jql = "project in ('%s') and \
               fixVersion in ('%s') and \
               resolution = Fixed" % (pjs, ver)
        params = urllib.urlencode({'jql': jql,
                                   'startAt': pos,
                                   'maxResults': count})
        return JiraIter.load_jira(params, 0)

    @staticmethod
    def load_jira(params, fail_count):
        """send query to JIRA and collect with retries"""
        try:
            resp = urllib2.urlopen(JIRA_BASE_URL + "/rest/api/2/search?%s" %
                                   params)
        except urllib2.HTTPError, err:
            code = err.code
            print "JIRA returns HTTP error %d: %s. Aborting." % (code, err.msg)
            error_response = err.read()
            try:
                error_response = json.loads(error_response)
                print "- Please ensure that specified projects, fixVersions etc. are correct."
                for message in error_response['errorMessages']:
                    print "-", message
            except Exception:
                print "Couldn't parse server response."
            sys.exit(1)
        except httplib.BadStatusLine as err:
            return JiraIter.retry_load(err, params, fail_count)
        try:
            data = json.loads(resp.read())
        except httplib.IncompleteRead as err:
            return JiraIter.retry_load(err, params, fail_count)
        return data

    @staticmethod
    def retry_load(err, params, fail_count):
        """Retry connection up to NUM_RETRIES times."""
        print(err)
        fail_count += 1
        if fail_count <= NUM_RETRIES:
            print "Connection failed %d times. Retrying." % (fail_count)
            sleep(1)
            return JiraIter.load_jira(params, fail_count)
        else:
            print "Connection failed %d times. Aborting." % (fail_count)
            sys.exit(1)

    @staticmethod
    def collect_jiras(ver, projects):
        """send queries to JIRA and collect all issues
        that belongs to given version and projects"""
        jiras = []
        pos = 0
        end = 1
        while pos < end:
            data = JiraIter.query_jira(ver, projects, pos)
            if 'error_messages' in data:
                print "JIRA returns error message: %s" % data['error_messages']
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

    def __init__(self, version, projects):
        self.version = version
        self.projects = projects
        self.field_id_map = JiraIter.collect_fields()
        ver = str(version).replace("-SNAPSHOT", "")
        self.jiras = JiraIter.collect_jiras(ver, projects)
        self.iter = self.jiras.__iter__()

    def __iter__(self):
        return self

    def next(self):
        data = self.iter.next()
        j = Jira(data, self)
        return j


class Linter(object):
    """Encapsulates lint-related functionality.
    Maintains running lint statistics about JIRAs."""

    _valid_filters = ["incompatible", "important", "version", "component",
                      "assignee"]

    def __init__(self, version, options):
        self._warning_count = 0
        self._error_count = 0
        self._lint_message = ""
        self._version = version

        self._filters = dict(zip(self._valid_filters, [False] * len(
            self._valid_filters)))

        self.enabled = False
        self._parse_options(options)

    @staticmethod
    def add_parser_options(parser):
        """Add Linter options to passed optparse parser."""
        filter_string = ", ".join("'" + f + "'" for f in Linter._valid_filters)
        parser.add_option(
            "-n",
            "--lint",
            dest="lint",
            action="append",
            type="string",
            help="Specify lint filters. Valid filters are " + filter_string +
            ". " + "'all' enables all lint filters. " +
            "Multiple filters can be specified comma-delimited and " +
            "filters can be negated, e.g. 'all,-component'.")

    def _parse_options(self, options):
        """Parse options from optparse."""

        if options.lint is None or len(options.lint) == 0:
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

        for o in options.lint:
            for token in o.split(","):
                if token not in valid:
                    print "Unknown lint filter '%s', valid options are: %s" % \
                            (token, ", ".join(v for v in sorted(valid)))
                    sys.exit(1)
                if token.startswith("-"):
                    disabled.append(token[1:])
                else:
                    enabled.append(token)

        for e in enabled:
            if e == "all":
                for f in self._valid_filters:
                    self._filters[f] = True
            else:
                self._filters[e] = True
        for d in disabled:
            self._filters[d] = False

    def had_errors(self):
        """Returns True if a lint error was encountered, else False."""
        return self._error_count > 0

    def message(self):
        """Return summary lint message suitable for printing to stdout."""
        if not self.enabled:
            return
        return self._lint_message + \
               "\n=======================================" + \
               "\n%s: Error:%d, Warning:%d \n" % \
               (self._version, self._error_count, self._warning_count)

    def _check_missing_component(self, jira):
        """Return if JIRA has a 'missing component' lint error."""
        if not self._filters["component"]:
            return False

        if len(jira.fields['components']) > 0:
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
        if len(jira.get_release_note()) == 0:
            if self._filters["incompatible"] and jira.get_incompatible_change():
                self._warning_count += 1
                self._lint_message += "\nWARNING: incompatible change %s lacks release notes." % \
                                (sanitize_text(jira.get_id()))
            if self._filters["important"] and jira.get_important():
                self._warning_count += 1
                self._lint_message += "\nWARNING: important issue %s lacks release notes." % \
                                (sanitize_text(jira.get_id()))

        if self._check_version_string(jira):
            self._warning_count += 1
            self._lint_message += "\nWARNING: Version string problem for %s " % jira.get_id(
            )

        if self._check_missing_component(jira) or self._check_missing_assignee(
                jira):
            self._error_count += 1
            error_message = []
            if self._check_missing_component(jira):
                error_message.append("component")
            if self._check_missing_assignee(jira):
                error_message.append("assignee")
            self._lint_message += "\nERROR: missing %s for %s " \
                            % (" and ".join(error_message), jira.get_id())


def parse_args():
    """Parse command-line arguments with optparse."""
    usage = "usage: %prog [OPTIONS] " + \
            "--project PROJECT [--project PROJECT] " + \
            "--version VERSION [--version VERSION2 ...]"
    parser = OptionParser(
        usage=usage,
        epilog=
        "Markdown-formatted CHANGES and RELEASENOTES files will be stored"
        " in a directory named after the highest version provided.")
    parser.add_option("-i",
                      "--index",
                      dest="index",
                      action="store_true",
                      default=False,
                      help="build an index file")
    parser.add_option("-l",
                      "--license",
                      dest="license",
                      action="store_true",
                      default=False,
                      help="Add an ASF license")
    parser.add_option("-p",
                      "--project",
                      dest="projects",
                      action="append",
                      type="string",
                      help="projects in JIRA to include in releasenotes",
                      metavar="PROJECT")
    parser.add_option("-r",
                      "--range",
                      dest="range",
                      action="store_true",
                      default=False,
                      help="Given versions are a range")
    parser.add_option(
        "--sortorder",
        dest="sortorder",
        metavar="TYPE",
        default=SORTORDER,
        # dec is supported for backward compatibility
        choices=["asc", "dec", "desc", "newer", "older"],
        help="Sorting order for sort type (default: %s)" % SORTORDER)
    parser.add_option("--sorttype",
                      dest="sorttype",
                      metavar="TYPE",
                      default=SORTTYPE,
                      choices=["resolutiondate", "issueid"],
                      help="Sorting type for issues (default: %s)" % SORTTYPE)
    parser.add_option(
        "-t",
        "--projecttitle",
        dest="title",
        type="string",
        help="Title to use for the project (default is Apache PROJECT)")
    parser.add_option("-u",
                      "--usetoday",
                      dest="usetoday",
                      action="store_true",
                      default=False,
                      help="use current date for unreleased versions")
    parser.add_option("-v",
                      "--version",
                      dest="versions",
                      action="append",
                      type="string",
                      help="versions in JIRA to include in releasenotes",
                      metavar="VERSION")
    parser.add_option(
        "-V",
        dest="release_version",
        action="store_true",
        default=False,
        help="display version information for releasedocmaker and exit.")
    parser.add_option("-O",
                      "--outputdir",
                      dest="output_directory",
                      action="append",
                      type="string",
                      help="specify output directory to put release docs to.")
    parser.add_option("-B",
                      "--baseurl",
                      dest="base_url",
                      action="append",
                      type="string",
                      help="specify base URL of the JIRA instance.")
    parser.add_option(
        "--retries",
        dest="retries",
        action="append",
        type="int",
        help="Specify how many times to retry connection for each URL.")
    parser.add_option("-X",
                      "--incompatiblelabel",
                      dest="incompatible_label",
                      default="backward-incompatible",
                      type="string",
                      help="Specify the label to indicate backward incompatibility.")

    Linter.add_parser_options(parser)

    if len(sys.argv) <= 1:
        parser.print_help()
        sys.exit(1)

    (options, _) = parser.parse_args()

    # Validate options
    if not options.release_version:
        if options.versions is None:
            parser.error("At least one version needs to be supplied")
        if options.projects is None:
            parser.error("At least one project needs to be supplied")
        if options.base_url is not None:
            if len(options.base_url) > 1:
                parser.error("Only one base URL should be given")
            else:
                options.base_url = options.base_url[0]
        if options.output_directory is not None:
            if len(options.output_directory) > 1:
                parser.error("Only one output directory should be given")
            else:
                options.output_directory = options.output_directory[0]

    return options


def main():
    options = parse_args()
    if options.release_version:
        with open(
                os.path.join(
                    os.path.dirname(__file__), "../VERSION"), 'r') as ver_file:
            print ver_file.read()
        sys.exit(0)

    if options.output_directory is not None:
        # Create the output directory if it does not exist.
        # Equivalent to `mkdir -p`.
        try:
            os.makedirs(options.output_directory)
        except OSError as exc:
            if exc.errno == errno.EEXIST and os.path.isdir(
                    options.output_directory):
                pass
            else:
                print "Unable to create output directory %s: %s" % \
                        (options.output_directory, exc.message)
                sys.exit(1)
        os.chdir(options.output_directory)

    if options.base_url is not None:
        global JIRA_BASE_URL
        JIRA_BASE_URL = options.base_url

    if options.incompatible_label is not None:
        global BACKWARD_INCOMPATIBLE_LABEL
        BACKWARD_INCOMPATIBLE_LABEL = options.incompatible_label

    proxy = urllib2.ProxyHandler()
    opener = urllib2.build_opener(proxy)
    urllib2.install_opener(opener)

    projects = options.projects

    if options.range is True:
        versions = [Version(v)
                    for v in GetVersions(options.versions, projects).getlist()]
    else:
        versions = [Version(v) for v in options.versions]
    versions.sort()

    global SORTTYPE
    SORTTYPE = options.sorttype
    global SORTORDER
    SORTORDER = options.sortorder

    if options.title is None:
        title = projects[0]
    else:
        title = options.title

    if options.retries is not None:
        global NUM_RETRIES
        NUM_RETRIES = options.retries[0]

    haderrors = False

    for version in versions:
        vstr = str(version)
        linter = Linter(vstr, options)
        jlist = sorted(JiraIter(vstr, projects))
        if len(jlist) == 0:
            print "There is no issue which has the specified version: %s" % version
            continue

        if vstr in RELEASE_VERSION:
            reldate = RELEASE_VERSION[vstr]
        elif options.usetoday:
            reldate = strftime("%Y-%m-%d", gmtime())
        else:
            reldate = "Unreleased (as of %s)" % strftime("%Y-%m-%d", gmtime())

        if not os.path.exists(vstr):
            os.mkdir(vstr)

        reloutputs = Outputs("%(ver)s/RELEASENOTES.%(ver)s.md",
                             "%(ver)s/RELEASENOTES.%(key)s.%(ver)s.md", [],
                             {"ver": version,
                              "date": reldate,
                              "title": title})
        choutputs = Outputs("%(ver)s/CHANGES.%(ver)s.md",
                            "%(ver)s/CHANGES.%(key)s.%(ver)s.md", [],
                            {"ver": version,
                             "date": reldate,
                             "title": title})

        if options.license is True:
            reloutputs.write_all(ASF_LICENSE)
            choutputs.write_all(ASF_LICENSE)

        relhead = '# %(title)s %(key)s %(ver)s Release Notes\n\n' \
                  'These release notes cover new developer and user-facing ' \
                  'incompatibilities, important issues, features, and major improvements.\n\n'
        chhead = '# %(title)s Changelog\n\n' \
                 '## Release %(ver)s - %(date)s\n'\
                 '\n'

        reloutputs.write_all(relhead)
        choutputs.write_all(chhead)

        incompatlist = []
        importantlist = []
        buglist = []
        improvementlist = []
        newfeaturelist = []
        subtasklist = []
        tasklist = []
        testlist = []
        otherlist = []

        for jira in jlist:
            if jira.get_incompatible_change():
                incompatlist.append(jira)
            elif jira.get_important():
                importantlist.append(jira)
            elif jira.get_type() == "Bug":
                buglist.append(jira)
            elif jira.get_type() == "Improvement":
                improvementlist.append(jira)
            elif jira.get_type() == "New Feature":
                newfeaturelist.append(jira)
            elif jira.get_type() == "Sub-task":
                subtasklist.append(jira)
            elif jira.get_type() == "Task":
                tasklist.append(jira)
            elif jira.get_type() == "Test":
                testlist.append(jira)
            else:
                otherlist.append(jira)

            line = '* [%s](' % (sanitize_text(jira.get_id())) + JIRA_BASE_URL + \
                   '/browse/%s) | *%s* | **%s**\n' \
                   % (sanitize_text(jira.get_id()),
                      sanitize_text(jira.get_priority()), sanitize_text(jira.get_summary()))

            if len(jira.get_release_note()) > 0 or \
               jira.get_incompatible_change() or jira.get_important():
                reloutputs.write_key_raw(jira.get_project(), "\n---\n\n")
                reloutputs.write_key_raw(jira.get_project(), line)
                if len(jira.get_release_note()) == 0:
                    line = '\n**WARNING: No release note provided for this change.**\n\n'
                else:
                    line = '\n%s\n\n' % (
                        processrelnote(jira.get_release_note()))
                reloutputs.write_key_raw(jira.get_project(), line)

            linter.lint(jira)

        if linter.enabled:
            print linter.message()
            if linter.had_errors():
                haderrors = True
                shutil.rmtree(vstr)
                continue

        reloutputs.write_all("\n\n")
        reloutputs.close()

        if incompatlist:
            choutputs.write_all("### INCOMPATIBLE CHANGES:\n\n")
            choutputs.write_all(CHANGEHDR1)
            choutputs.write_all(CHANGEHDR2)
            choutputs.write_list(incompatlist)

        if importantlist:
            choutputs.write_all("\n\n### IMPORTANT ISSUES:\n\n")
            choutputs.write_all(CHANGEHDR1)
            choutputs.write_all(CHANGEHDR2)
            choutputs.write_list(importantlist)

        if newfeaturelist:
            choutputs.write_all("\n\n### NEW FEATURES:\n\n")
            choutputs.write_all(CHANGEHDR1)
            choutputs.write_all(CHANGEHDR2)
            choutputs.write_list(newfeaturelist)

        if improvementlist:
            choutputs.write_all("\n\n### IMPROVEMENTS:\n\n")
            choutputs.write_all(CHANGEHDR1)
            choutputs.write_all(CHANGEHDR2)
            choutputs.write_list(improvementlist)

        if buglist:
            choutputs.write_all("\n\n### BUG FIXES:\n\n")
            choutputs.write_all(CHANGEHDR1)
            choutputs.write_all(CHANGEHDR2)
            choutputs.write_list(buglist)

        if testlist:
            choutputs.write_all("\n\n### TESTS:\n\n")
            choutputs.write_all(CHANGEHDR1)
            choutputs.write_all(CHANGEHDR2)
            choutputs.write_list(testlist)

        if subtasklist:
            choutputs.write_all("\n\n### SUB-TASKS:\n\n")
            choutputs.write_all(CHANGEHDR1)
            choutputs.write_all(CHANGEHDR2)
            choutputs.write_list(subtasklist)

        if tasklist or otherlist:
            choutputs.write_all("\n\n### OTHER:\n\n")
            choutputs.write_all(CHANGEHDR1)
            choutputs.write_all(CHANGEHDR2)
            choutputs.write_list(otherlist)
            choutputs.write_list(tasklist)

        choutputs.write_all("\n\n")
        choutputs.close()

    if options.index:
        buildindex(title, options.license)
        buildreadme(title, options.license)

    if haderrors is True:
        sys.exit(1)


if __name__ == "__main__":
    main()
