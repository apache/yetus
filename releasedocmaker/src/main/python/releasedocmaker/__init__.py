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
""" Generate releasenotes based upon JIRA """

import errno
import http.client
import json
import logging
import os
import pathlib
import re
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request

from glob import glob
from argparse import ArgumentParser
from time import gmtime, strftime, sleep

sys.dont_write_bytecode = True
# pylint: disable=wrong-import-position
from .getversions import GetVersions, ReleaseVersion
from .jira import (Jira, JiraIter, Linter, RELEASE_VERSION, SORTTYPE,
                   SORTORDER, BACKWARD_INCOMPATIBLE_LABEL, NUM_RETRIES)
from .utils import get_jira, to_unicode, sanitize_text, processrelnote, Outputs
# pylint: enable=wrong-import-position

# These are done in order of preference as to which one seems to be
# more up-to-date at any given point in time.  And yes, it is
# ironic that packaging is usually the last one to be
# correct.

EXTENSION = '.md'

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


def indexbuilder(title, asf_license, format_string):
    """Write an index file for later conversion using mvn site"""
    versions = glob("*[0-9]*.[0-9]*")
    versions = sorted(versions, reverse=True, key=ReleaseVersion)
    with open("index" + EXTENSION, "w", encoding='utf-8') as indexfile:
        if asf_license is True:
            indexfile.write(ASF_LICENSE)
        for version in versions:
            indexfile.write(f"* {title} v{version}\n")
            for k in ("Changelog", "Release Notes"):
                indexfile.write(
                    format_string %
                    (k, version, k.upper().replace(" ", ""), version))


def buildprettyindex(title, asf_license):
    """Write an index file for later conversion using middleman"""
    indexbuilder(title, asf_license, "    * [%s](%s/%s.%s)\n")


def buildindex(title, asf_license):
    """Write an index file for later conversion using mvn site"""
    indexbuilder(title, asf_license, "    * [%s](%s/%s.%s.html)\n")


def buildreadme(title, asf_license):
    """Write an index file for Github using README.md"""
    versions = glob("[0-9]*.[0-9]*")
    versions = sorted(versions, reverse=True, key=ReleaseVersion)
    with open("README.md", "w", encoding='utf-8') as indexfile:
        if asf_license is True:
            indexfile.write(ASF_LICENSE)
        for version in versions:
            indexfile.write(f"* {title} v{version}\n")
            for k in ("Changelog", "Release Notes"):
                indexfile.write(
                    f"    * [{k}]({version}/{k.upper().replace(' ', '')}.{version}{EXTENSION})\n"
                )


def getversion():
    """ print the version file"""
    basepath = pathlib.Path(__file__).parent.resolve()
    for versionfile in [
            basepath.resolve().joinpath('VERSION'),
            basepath.parent.parent.resolve().joinpath('VERSION')
    ]:
        if versionfile.exists():
            with open(versionfile, encoding='utf-8') as ver_file:
                version = ver_file.read()
            return version
    mvnversion = basepath.parent.parent.parent.parent.parent.resolve(
    ).joinpath('.mvn', 'maven.config')
    if mvnversion.exists():
        with open(mvnversion, encoding='utf-8') as ver_file:
            return ver_file.read().split('=')[1].strip()

    return 'Unknown'


def parse_args():  # pylint: disable=too-many-branches
    """Parse command-line arguments with optparse."""
    parser = ArgumentParser(
        prog='releasedocmaker',
        epilog="--project and --version may be given multiple times.")
    parser.add_argument("--dirversions",
                        dest="versiondirs",
                        action="store_true",
                        default=False,
                        help="Put files in versioned directories")
    parser.add_argument("--empty",
                        dest="empty",
                        action="store_true",
                        default=False,
                        help="Create empty files when no issues")
    parser.add_argument(
        "--extension",
        dest="extension",
        default=EXTENSION,
        type=str,
        help="Set the file extension of created Markdown files")
    parser.add_argument("--fileversions",
                        dest="versionfiles",
                        action="store_true",
                        default=False,
                        help="Write files with embedded versions")
    parser.add_argument("-i",
                        "--index",
                        dest="index",
                        action="store_true",
                        default=False,
                        help="build an index file")
    parser.add_argument("-l",
                        "--license",
                        dest="license",
                        action="store_true",
                        default=False,
                        help="Add an ASF license")
    parser.add_argument("-p",
                        "--project",
                        dest="projects",
                        action="append",
                        type=str,
                        help="projects in JIRA to include in releasenotes",
                        metavar="PROJECT")
    parser.add_argument("--prettyindex",
                        dest="prettyindex",
                        action="store_true",
                        default=False,
                        help="build an index file with pretty URLs")
    parser.add_argument("-r",
                        "--range",
                        dest="range",
                        action="store_true",
                        default=False,
                        help="Given versions are a range")
    parser.add_argument(
        "--sortorder",
        dest="sortorder",
        metavar="TYPE",
        default=SORTORDER,
        # dec is supported for backward compatibility
        choices=["asc", "dec", "desc", "newer", "older"],
        help=f"Sorting order for sort type (default: {SORTORDER})")
    parser.add_argument("--sorttype",
                        dest="sorttype",
                        metavar="TYPE",
                        default=SORTTYPE,
                        choices=["resolutiondate", "issueid"],
                        help=f"Sorting type for issues (default: {SORTTYPE})")
    parser.add_argument(
        "-t",
        "--projecttitle",
        dest="title",
        type=str,
        help="Title to use for the project (default is Apache PROJECT)")
    parser.add_argument("-u",
                        "--usetoday",
                        dest="usetoday",
                        action="store_true",
                        default=False,
                        help="use current date for unreleased versions")
    parser.add_argument("-v",
                        "--version",
                        dest="versions",
                        action="append",
                        type=str,
                        help="versions in JIRA to include in releasenotes",
                        metavar="VERSION")
    parser.add_argument(
        "-V",
        dest="release_version",
        action="store_true",
        default=False,
        help="display version information for releasedocmaker and exit.")
    parser.add_argument(
        "-O",
        "--outputdir",
        dest="output_directory",
        action="append",
        type=str,
        help="specify output directory to put release docs to.")
    parser.add_argument("-B",
                        "--baseurl",
                        dest="base_url",
                        action="append",
                        type=str,
                        default='https://issues.apache.org/jira',
                        help="specify base URL of the JIRA instance.")
    parser.add_argument(
        "--retries",
        dest="retries",
        action="append",
        type=int,
        help="Specify how many times to retry connection for each URL.")
    parser.add_argument(
        "--skip-credits",
        dest="skip_credits",
        action="store_true",
        default=False,
        help=
        "While creating release notes skip the 'reporter' and 'contributor' columns"
    )
    parser.add_argument(
        "-X",
        "--incompatiblelabel",
        dest="incompatible_label",
        default="backward-incompatible",
        type=str,
        help="Specify the label to indicate backward incompatibility.")

    Linter.add_parser_options(parser)

    if len(sys.argv) <= 1:
        parser.print_help()
        sys.exit(1)

    options = parser.parse_args()

    # Handle the version string right away and exit
    if options.release_version:
        logging.info(getversion())
        sys.exit(0)

    # Validate options
    if not options.release_version:
        if options.versions is None:
            parser.error("At least one version needs to be supplied")
        if options.projects is None:
            parser.error("At least one project needs to be supplied")
        if options.base_url is None:
            parser.error("Base URL must be defined")
        if options.output_directory is not None:
            if len(options.output_directory) > 1:
                parser.error("Only one output directory should be given")
            else:
                options.output_directory = options.output_directory[0]

    if options.range or len(options.versions) > 1:
        if not options.versiondirs and not options.versionfiles:
            parser.error(
                "Multiple versions require either --fileversions or --dirversions"
            )

    return options


def generate_changelog_line_md(base_url, jira):
    ''' take a jira object and generate the changelog line in md'''
    sani_jira_id = sanitize_text(jira.get_id())
    sani_prio = sanitize_text(jira.get_priority())
    sani_summ = sanitize_text(jira.get_summary())
    line = f'* [{sani_jira_id}](' + f'{base_url}/browse/{sani_jira_id})'
    line += f' | *{sani_prio}* | **{sani_summ}**\n'
    return line


def main():  # pylint: disable=too-many-statements, too-many-branches, too-many-locals
    """ hey, it's main """
    global BACKWARD_INCOMPATIBLE_LABEL  #pylint: disable=global-statement
    global SORTTYPE  #pylint: disable=global-statement
    global SORTORDER  #pylint: disable=global-statement
    global NUM_RETRIES  #pylint: disable=global-statement
    global EXTENSION  #pylint: disable=global-statement

    logging.basicConfig(format='%(message)s', level=logging.DEBUG)
    options = parse_args()

    if options.output_directory is not None:
        # Create the output directory if it does not exist.
        try:
            outputpath = pathlib.Path(options.output_directory).resolve()
            outputpath.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            logging.error("Unable to create output directory %s: %s, %s",
                          options.output_directory, exc.errno, exc.strerror)
            sys.exit(1)
        os.chdir(options.output_directory)

    if options.incompatible_label is not None:
        BACKWARD_INCOMPATIBLE_LABEL = options.incompatible_label

    if options.extension is not None:
        EXTENSION = options.extension

    projects = options.projects

    if options.range is True:
        versions = GetVersions(options.versions, projects,
                               options.base_url).getlist()
    else:
        versions = [ReleaseVersion(v) for v in options.versions]
    versions = sorted(versions)

    SORTTYPE = options.sorttype
    SORTORDER = options.sortorder

    if options.title is None:
        title = projects[0]
    else:
        title = options.title

    if options.retries is not None:
        NUM_RETRIES = options.retries[0]

    haderrors = False

    for version in versions:
        vstr = str(version)
        linter = Linter(vstr, options)
        jlist = sorted(JiraIter(options.base_url, vstr, projects))
        if not jlist and not options.empty:
            logging.warning(
                "There is no issue which has the specified version: %s",
                version)
            continue

        if vstr in RELEASE_VERSION:
            reldate = RELEASE_VERSION[vstr]
        elif options.usetoday:
            reldate = strftime("%Y-%m-%d", gmtime())
        else:
            reldate = f"Unreleased (as of {strftime('%Y-%m-%d', gmtime())})"

        if not os.path.exists(vstr) and options.versiondirs:
            os.mkdir(vstr)

        if options.versionfiles and options.versiondirs:
            reloutputs = Outputs(
                "%(ver)s/RELEASENOTES.%(ver)s%(ext)s",
                "%(ver)s/RELEASENOTES.%(key)s.%(ver)s%(ext)s", [], {
                    "ver": version,
                    "date": reldate,
                    "title": title,
                    "ext": EXTENSION
                })
            choutputs = Outputs("%(ver)s/CHANGELOG.%(ver)s%(ext)s",
                                "%(ver)s/CHANGELOG.%(key)s.%(ver)s%(ext)s", [],
                                {
                                    "ver": version,
                                    "date": reldate,
                                    "title": title,
                                    "ext": EXTENSION
                                })
        elif options.versiondirs:
            reloutputs = Outputs("%(ver)s/RELEASENOTES%(ext)s",
                                 "%(ver)s/RELEASENOTES.%(key)s%(ext)s", [], {
                                     "ver": version,
                                     "date": reldate,
                                     "title": title,
                                     "ext": EXTENSION
                                 })
            choutputs = Outputs("%(ver)s/CHANGELOG%(ext)s",
                                "%(ver)s/CHANGELOG.%(key)s%(ext)s", [], {
                                    "ver": version,
                                    "date": reldate,
                                    "title": title,
                                    "ext": EXTENSION
                                })
        elif options.versionfiles:
            reloutputs = Outputs("RELEASENOTES.%(ver)s%(ext)s",
                                 "RELEASENOTES.%(key)s.%(ver)s%(ext)s", [], {
                                     "ver": version,
                                     "date": reldate,
                                     "title": title,
                                     "ext": EXTENSION
                                 })
            choutputs = Outputs("CHANGELOG.%(ver)s%(ext)s",
                                "CHANGELOG.%(key)s.%(ver)s%(ext)s", [], {
                                    "ver": version,
                                    "date": reldate,
                                    "title": title,
                                    "ext": EXTENSION
                                })
        else:
            reloutputs = Outputs("RELEASENOTES%(ext)s",
                                 "RELEASENOTES.%(key)s%(ext)s", [], {
                                     "ver": version,
                                     "date": reldate,
                                     "title": title,
                                     "ext": EXTENSION
                                 })
            choutputs = Outputs("CHANGELOG%(ext)s", "CHANGELOG.%(key)s%(ext)s",
                                [], {
                                    "ver": version,
                                    "date": reldate,
                                    "title": title,
                                    "ext": EXTENSION
                                })

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

            line = generate_changelog_line_md(options.base_url, jira)

            if jira.get_release_note() or \
               jira.get_incompatible_change() or jira.get_important():
                reloutputs.write_key_raw(jira.get_project(), "\n---\n\n")
                reloutputs.write_key_raw(jira.get_project(), line)
                if not jira.get_release_note():
                    line = '\n**WARNING: No release note provided for this change.**\n\n'
                else:
                    line = f'\n{processrelnote(jira.get_release_note())}\n\n'
                reloutputs.write_key_raw(jira.get_project(), line)

            linter.lint(jira)

        if linter.enabled:
            if linter.had_errors():
                logging.error(linter.message())
                haderrors = True
                if os.path.exists(vstr):
                    shutil.rmtree(vstr)
                continue

        reloutputs.write_all("\n\n")
        reloutputs.close()

        if options.skip_credits:
            change_header21 = "| JIRA | Summary | Priority | " + \
                     "Component |\n"
            change_header22 = "|:---- |:---- | :--- |:---- |\n"
        else:
            change_header21 = "| JIRA | Summary | Priority | " + \
                         "Component | Reporter | Contributor |\n"
            change_header22 = "|:---- |:---- | :--- |:---- |:---- |:---- |\n"

        if incompatlist:
            choutputs.write_all("### INCOMPATIBLE CHANGES:\n\n")
            choutputs.write_all(change_header21)
            choutputs.write_all(change_header22)
            choutputs.write_list(incompatlist, options.skip_credits,
                                 options.base_url)

        if importantlist:
            choutputs.write_all("\n\n### IMPORTANT ISSUES:\n\n")
            choutputs.write_all(change_header21)
            choutputs.write_all(change_header22)
            choutputs.write_list(importantlist, options.skip_credits,
                                 options.base_url)

        if newfeaturelist:
            choutputs.write_all("\n\n### NEW FEATURES:\n\n")
            choutputs.write_all(change_header21)
            choutputs.write_all(change_header22)
            choutputs.write_list(newfeaturelist, options.skip_credits,
                                 options.base_url)

        if improvementlist:
            choutputs.write_all("\n\n### IMPROVEMENTS:\n\n")
            choutputs.write_all(change_header21)
            choutputs.write_all(change_header22)
            choutputs.write_list(improvementlist, options.skip_credits,
                                 options.base_url)

        if buglist:
            choutputs.write_all("\n\n### BUG FIXES:\n\n")
            choutputs.write_all(change_header21)
            choutputs.write_all(change_header22)
            choutputs.write_list(buglist, options.skip_credits,
                                 options.base_url)

        if testlist:
            choutputs.write_all("\n\n### TESTS:\n\n")
            choutputs.write_all(change_header21)
            choutputs.write_all(change_header22)
            choutputs.write_list(testlist, options.skip_credits,
                                 options.base_url)

        if subtasklist:
            choutputs.write_all("\n\n### SUB-TASKS:\n\n")
            choutputs.write_all(change_header21)
            choutputs.write_all(change_header22)
            choutputs.write_list(subtasklist, options.skip_credits,
                                 options.base_url)

        if tasklist or otherlist:
            choutputs.write_all("\n\n### OTHER:\n\n")
            choutputs.write_all(change_header21)
            choutputs.write_all(change_header22)
            choutputs.write_list(otherlist, options.skip_credits,
                                 options.base_url)
            choutputs.write_list(tasklist, options.skip_credits,
                                 options.base_url)

        choutputs.write_all("\n\n")
        choutputs.close()

    if options.index:
        buildindex(title, options.license)
        buildreadme(title, options.license)

    if options.prettyindex:
        buildprettyindex(title, options.license)

    if haderrors is True:
        sys.exit(1)


if __name__ == "__main__":
    main()
