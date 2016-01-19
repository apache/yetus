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
from time import gmtime, strftime
from distutils.version import LooseVersion
import os
import re
import sys
import urllib
import urllib2
try:
    import json
except ImportError:
    import simplejson as json
try:
    set
except NameError:
    from sets import Set as set

RELEASE_VERSION = {}
NAME_PATTERN = re.compile(r' \([0-9]+\)')
RELNOTE_PATTERN = re.compile('^\<\!\-\- ([a-z]+) \-\-\>')

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

def clean(_str):
    return tableclean(re.sub(NAME_PATTERN, "", _str))

def format_components(_str):
    _str = re.sub(NAME_PATTERN, '', _str).replace("'", "")
    if _str != "":
        ret = _str
    else:
        # some markdown parsers don't like empty tables
        ret = "."
    return clean(ret)

# convert to utf-8
# protect some known md metachars
# or chars that screw up doxia
def tableclean(_str):
    _str = _str.encode('utf-8')
    _str = _str.replace("_", r"\_")
    _str = _str.replace("\r", "")
    _str = _str.rstrip()
    return _str

# same thing as tableclean,
# except table metachars are also
# escaped as well as more
# things we don't want doxia to
# screw up
def notableclean(_str):
    _str = tableclean(_str)
    _str = _str.replace("|", r"\|")
    _str = _str.replace("<", r"\<")
    _str = _str.replace(">", r"\>")
    _str = _str.replace("*", r"\*")
    _str = _str.rstrip()
    return _str

# if release notes have a special marker,
# we'll treat them as already in markdown format
def processrelnote(_str):
  fmt = RELNOTE_PATTERN.match(_str)
  if fmt is None:
      return notableclean(_str)
  else:
      return {
        'markdown' : tableclean(_str),
      }.get(fmt.group(1),notableclean(_str))

# clean output dir
def clean_output_dir(directory):
    files = os.listdir(directory)
    for name in files:
        os.remove(os.path.join(directory, name))
    os.rmdir(directory)

def mstr(obj):
    if obj is None:
        return ""
    return unicode(obj)

def buildindex(title, asf_license):
    """Write an index file for later conversion using mvn site"""
    versions = glob("[0-9]*.[0-9]*.[0-9]*")
    versions.sort(key=LooseVersion, reverse=True)
    with open("index.md", "w") as indexfile:
        if asf_license is True:
            indexfile.write(ASF_LICENSE)
        for version in versions:
            indexfile.write("* %s v%s\n" % (title, version))
            for k in ("Changes", "Release Notes"):
                indexfile.write("    * [%s](%s/%s.%s.html)\n" \
                    % (k, version, k.upper().replace(" ", ""), version))

def buildreadme(title, asf_license):
    """Write an index file for Github using README.md"""
    versions = glob("[0-9]*.[0-9]*.[0-9]*")
    versions.sort(key=LooseVersion, reverse=True)
    with open("README.md", "w") as indexfile:
        if asf_license is True:
            indexfile.write(ASF_LICENSE)
        for version in versions:
            indexfile.write("* %s v%s\n" % (title, version))
            for k in ("Changes", "Release Notes"):
                indexfile.write("    * [%s](%s/%s.%s.md)\n" \
                    % (k, version, k.upper().replace(" ", ""), version))

class GetVersions(object):
    """ List of version strings """
    def __init__(self, versions, projects):
        versions = versions
        projects = projects
        self.newversions = []
        versions.sort(key=LooseVersion)
        print "Looking for %s through %s"%(versions[0], versions[-1])
        newversions = set()
        for project in projects:
            url = "https://issues.apache.org/jira/rest/api/2/project/%s/versions" % project.upper()
            resp = urllib2.urlopen(url)
            datum = json.loads(resp.read())
            for data in datum:
                newversions.add(data['name'])
        newversions.add(versions[0])
        newversions.add(versions[-1])
        newlist = newversions.copy()
        newlist = list(newlist)
        newlist.sort(key=LooseVersion)
        for newversion in newlist[newlist.index(versions[0]):newlist.index(versions[-1])+1]:
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
        return mstr(self.key)

    def get_description(self):
        return mstr(self.fields['description'])

    def get_release_note(self):
        if self.notes is None:
            field = self.parent.field_id_map['Release Note']
            if self.fields.has_key(field):
                self.notes = mstr(self.fields[field])
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
        return mstr(ret)

    def get_assignee(self):
        ret = ""
        mid = self.fields['assignee']
        if mid is not None:
            ret = mid['displayName']
        return mstr(ret)

    def get_components(self):
        if len(self.fields['components']) > 0:
            return ", ".join([comp['name'] for comp in self.fields['components']])
        else:
            return ""

    def get_summary(self):
        return self.fields['summary']

    def get_type(self):
        ret = ""
        mid = self.fields['issuetype']
        if mid is not None:
            ret = mid['name']
        return mstr(ret)

    def get_reporter(self):
        ret = ""
        mid = self.fields['reporter']
        if mid is not None:
            ret = mid['displayName']
        return mstr(ret)

    def get_project(self):
        ret = ""
        mid = self.fields['project']
        if mid is not None:
            ret = mid['key']
        return mstr(ret)

    def __cmp__(self, other):
        selfsplit = self.get_id().split('-')
        othersplit = other.get_id().split('-')
        result = cmp(selfsplit[0], othersplit[0])
        if result != 0:
            return result
        else:
            if selfsplit[1] < othersplit[1]:
                return True
            elif selfsplit[1] > othersplit[1]:
                return False
        return False

    def get_incompatible_change(self):
        if self.incompat is None:
            field = self.parent.field_id_map['Hadoop Flags']
            self.reviewed = False
            self.incompat = False
            if self.fields.has_key(field):
                if self.fields[field]:
                    for flag in self.fields[field]:
                        if flag['value'] == "Incompatible change":
                            self.incompat = True
                        if flag['value'] == "Reviewed":
                            self.reviewed = True
        return self.incompat

    def get_important(self):
        if self.important is None:
            field = self.parent.field_id_map['Flags']
            self.important = False
            if self.fields.has_key(field):
                if self.fields[field]:
                    for flag in self.fields[field]:
                        if flag['value'] == "Important":
                            self.important = True
        return self.important

    def check_missing_component(self):
        if len(self.fields['components']) > 0:
            return False
        return True

    def check_missing_assignee(self):
        if self.fields['assignee'] is not None:
            return False
        return True

    def check_version_string(self):
        field = self.parent.field_id_map['Fix Version/s']
        for ver in self.fields[field]:
            found = re.match(r'^((\d+)(\.\d+)*).*$|^(\w+\-\d+)$', ver['name'])
            if not found:
                return True
        return False

    def get_release_date(self, version):
        fix_versions = self.fields['fixVersions']
        for j in range(len(fix_versions)):
            if fix_versions[j] == version:
                return fix_versions[j]['releaseDate']
        return None

class JiraIter(object):
    """An Iterator of JIRAs"""

    @staticmethod
    def collect_fields():
        """send a query to JIRA and collect field-id map"""
        resp = urllib2.urlopen("https://issues.apache.org/jira/rest/api/2/field")
        data = json.loads(resp.read())
        field_id_map = {}
        for part in data:
            field_id_map[part['name']] = part['id']
        return field_id_map

    @staticmethod
    def query_jira(ver, projects, pos):
        """send a query to JIRA and collect a certain number of issue information"""
        count = 100
        pjs = "','".join(projects)
        jql = "project in ('%s') and fixVersion in ('%s') and resolution = Fixed" % (pjs, ver)
        params = urllib.urlencode({'jql':jql, 'startAt':pos, 'maxResults':count})
        try:
            resp = urllib2.urlopen("https://issues.apache.org/jira/rest/api/2/search?%s" % params)
        except urllib2.HTTPError, err:
            code = err.code
            print "JIRA returns HTTP error %d: %s. Aborting." % (code, err.msg)
            if code == 400:
                print "Please make sure the specified projects are correct."
            sys.exit(1)
        data = json.loads(resp.read())
        return data

    @staticmethod
    def collect_jiras(ver, projects):
        """send queries to JIRA and collect all issues that belongs to given version and projects"""
        jiras = []
        pos = 0
        end = 1
        while pos < end:
            data = JiraIter.query_jira(ver, projects, pos)
            if data.has_key('error_messages'):
                print "JIRA returns error message: %s" % data['error_messages']
                sys.exit(1)
            pos = data['startAt'] + data['maxResults']
            end = data['total']
            jiras.extend(data['issues'])

            if ver not in RELEASE_VERSION:
                for issue in data['issues']:
                    for fix_version in issue['fields']['fixVersions']:
                        if 'releaseDate' in fix_version:
                            RELEASE_VERSION[fix_version['name']] = fix_version['releaseDate']
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

class Outputs(object):
    """Several different files to output to at the same time"""

    def __init__(self, base_file_name, file_name_pattern, keys, params=None):
        if params is None:
            params = {}
        self.params = params
        self.base = open(base_file_name%params, 'w')
        self.others = {}
        for key in keys:
            both = dict(params)
            both['key'] = key
            self.others[key] = open(file_name_pattern%both, 'w')

    def write_all(self, pattern):
        both = dict(self.params)
        both['key'] = ''
        self.base.write(pattern%both)
        for key in self.others.keys():
            both = dict(self.params)
            both['key'] = key
            self.others[key].write(pattern%both)

    def write_key_raw(self, key, _str):
        self.base.write(_str)
        if self.others.has_key(key):
            self.others[key].write(_str)

    def close(self):
        self.base.close()
        for value in self.others.values():
            value.close()

    def write_list(self, mylist):
        for jira in sorted(mylist):
            line = '| [%s](https://issues.apache.org/jira/browse/%s) | %s |  %s | %s | %s | %s |\n'
            line = line % (notableclean(jira.get_id()),
                           notableclean(jira.get_id()),
                           notableclean(jira.get_summary()),
                           notableclean(jira.get_priority()),
                           format_components(jira.get_components()),
                           notableclean(jira.get_reporter()),
                           notableclean(jira.get_assignee()))
            self.write_key_raw(jira.get_project(), line)

def main():
    usage = "usage: %prog --project PROJECT [--project PROJECT] --version VERSION [--version VERSION2 ...]"
    parser = OptionParser(usage=usage,
                          epilog="Markdown-formatted CHANGES and RELEASENOTES files will be stored"
                                 "in a directory named after the highest version provided.")
    parser.add_option("-i", "--index", dest="index", action="store_true",
                      default=False, help="build an index file")
    parser.add_option("-l", "--license", dest="license", action="store_false",
                      default=True, help="Add an ASF license")
    parser.add_option("-n", "--lint", dest="lint", action="store_true",
                      help="use lint flag to exit on failures")
    parser.add_option("-p", "--project", dest="projects",
                      action="append", type="string",
                      help="projects in JIRA to include in releasenotes", metavar="PROJECT")
    parser.add_option("-r", "--range", dest="range", action="store_true",
                      default=False, help="Given versions are a range")
    parser.add_option("-t", "--projecttitle", dest="title", type="string",
                      help="Title to use for the project (default is Apache PROJECT)")
    parser.add_option("-u", "--usetoday", dest="usetoday", action="store_true",
                      default=False, help="use current date for unreleased versions")
    parser.add_option("-v", "--version", dest="versions", action="append", type="string",
                      help="versions in JIRA to include in releasenotes", metavar="VERSION")
    parser.add_option("-V", dest="release_version", action="store_true", default=False,
                      help="display version information for releasedocmaker and exit.")
    parser.add_option("-O", "--outputdir", dest="output_directory", action="append", type="string",
                      help="specify output directory to put release docs to.")
    (options, _) = parser.parse_args()

    if options.release_version:
        with open(os.path.join(os.path.dirname(__file__), "../VERSION"), 'r') as ver_file:
            print ver_file.read()
        sys.exit(0)

    if options.versions is None:
        parser.error("At least one version needs to be supplied")

    if options.output_directory is not None:
        if len(options.output_directory) > 1:
            parser.error("Only one output directory should be given")
        if not os.path.isdir(options.output_directory[0]):
            try:
                os.makedirs(options.output_directory[0])
            except OSError:
                parser.error("Unable to create output directory that does not exist")
        os.chdir(options.output_directory[0])

    proxy = urllib2.ProxyHandler()
    opener = urllib2.build_opener(proxy)
    urllib2.install_opener(opener)

    projects = options.projects
    if projects is None:
        parser.error("At least one project needs to be supplied")

    if options.range is True:
        versions = [Version(v) for v in GetVersions(options.versions, projects).getlist()]
    else:
        versions = [Version(v) for v in options.versions]
    versions.sort()

    if options.title is None:
        title = projects[0]
    else:
        title = options.title

    haderrors = False

    for version in versions:
        vstr = str(version)
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
                             "%(ver)s/RELEASENOTES.%(key)s.%(ver)s.md",
                             [], {"ver":version, "date":reldate, "title":title})
        choutputs = Outputs("%(ver)s/CHANGES.%(ver)s.md",
                            "%(ver)s/CHANGES.%(key)s.%(ver)s.md",
                            [], {"ver":version, "date":reldate, "title":title})

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
        error_count = 0
        warning_count = 0
        lint_message = ""
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

            line = '* [%s](https://issues.apache.org/jira/browse/%s) | *%s* | **%s**\n' \
                   % (notableclean(jira.get_id()), notableclean(jira.get_id()),
                      notableclean(jira.get_priority()), notableclean(jira.get_summary()))

            if jira.get_incompatible_change() and len(jira.get_release_note()) == 0:
                warning_count += 1
                reloutputs.write_key_raw(jira.get_project(), "\n---\n\n")
                reloutputs.write_key_raw(jira.get_project(), line)
                line = '\n**WARNING: No release note provided for this incompatible change.**\n\n'
                lint_message += "\nWARNING: incompatible change %s lacks release notes." % \
                                (notableclean(jira.get_id()))
                reloutputs.write_key_raw(jira.get_project(), line)

            if jira.get_important() and len(jira.get_release_note()) == 0:
                warning_count += 1
                reloutputs.write_key_raw(jira.get_project(), "\n---\n\n")
                reloutputs.write_key_raw(jira.get_project(), line)
                line = '\n**WARNING: No release note provided for this important issue.**\n\n'
                lint_message += "\nWARNING: important issue %s lacks release notes." % \
                                (notableclean(jira.get_id()))
                reloutputs.write_key_raw(jira.get_project(), line)

            if jira.check_version_string():
                warning_count += 1
                lint_message += "\nWARNING: Version string problem for %s " % jira.get_id()

            if jira.check_missing_component() or jira.check_missing_assignee():
                error_count += 1
                error_message = []
                if jira.check_missing_component():
                    error_message.append("component")
                if jira.check_missing_assignee():
                    error_message.append("assignee")
                lint_message += "\nERROR: missing %s for %s " \
                                % (" and ".join(error_message), jira.get_id())

            if len(jira.get_release_note()) > 0:
                reloutputs.write_key_raw(jira.get_project(), "\n---\n\n")
                reloutputs.write_key_raw(jira.get_project(), line)
                line = '\n%s\n\n' % (processrelnote(jira.get_release_note()))
                reloutputs.write_key_raw(jira.get_project(), line)

        if options.lint is True:
            print lint_message
            print "======================================="
            print "%s: Error:%d, Warning:%d \n" % (vstr, error_count, warning_count)
            if error_count > 0:
                haderrors = True
                clean_output_dir(vstr)
                continue

        reloutputs.write_all("\n\n")
        reloutputs.close()

        choutputs.write_all("### INCOMPATIBLE CHANGES:\n\n")
        choutputs.write_all("| JIRA | Summary | Priority | Component | Reporter | Contributor |\n")
        choutputs.write_all("|:---- |:---- | :--- |:---- |:---- |:---- |\n")
        choutputs.write_list(incompatlist)

        choutputs.write_all("\n\n### IMPORTANT ISSUES:\n\n")
        choutputs.write_all("| JIRA | Summary | Priority | Component | Reporter | Contributor |\n")
        choutputs.write_all("|:---- |:---- | :--- |:---- |:---- |:---- |\n")
        choutputs.write_list(importantlist)

        choutputs.write_all("\n\n### NEW FEATURES:\n\n")
        choutputs.write_all("| JIRA | Summary | Priority | Component | Reporter | Contributor |\n")
        choutputs.write_all("|:---- |:---- | :--- |:---- |:---- |:---- |\n")
        choutputs.write_list(newfeaturelist)

        choutputs.write_all("\n\n### IMPROVEMENTS:\n\n")
        choutputs.write_all("| JIRA | Summary | Priority | Component | Reporter | Contributor |\n")
        choutputs.write_all("|:---- |:---- | :--- |:---- |:---- |:---- |\n")
        choutputs.write_list(improvementlist)

        choutputs.write_all("\n\n### BUG FIXES:\n\n")
        choutputs.write_all("| JIRA | Summary | Priority | Component | Reporter | Contributor |\n")
        choutputs.write_all("|:---- |:---- | :--- |:---- |:---- |:---- |\n")
        choutputs.write_list(buglist)

        choutputs.write_all("\n\n### TESTS:\n\n")
        choutputs.write_all("| JIRA | Summary | Priority | Component | Reporter | Contributor |\n")
        choutputs.write_all("|:---- |:---- | :--- |:---- |:---- |:---- |\n")
        choutputs.write_list(testlist)

        choutputs.write_all("\n\n### SUB-TASKS:\n\n")
        choutputs.write_all("| JIRA | Summary | Priority | Component | Reporter | Contributor |\n")
        choutputs.write_all("|:---- |:---- | :--- |:---- |:---- |:---- |\n")
        choutputs.write_list(subtasklist)

        choutputs.write_all("\n\n### OTHER:\n\n")
        choutputs.write_all("| JIRA | Summary | Priority | Component | Reporter | Contributor |\n")
        choutputs.write_all("|:---- |:---- | :--- |:---- |:---- |:---- |\n")
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
