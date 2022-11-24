#!/usr/bin/env python3
# pylint: disable=invalid-name
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
""" Process patch file attachments from JIRA using a query """

#
# we actually want native encoding so tell pylint to be quiet
#
# pylint: disable=unspecified-encoding

from argparse import ArgumentParser
from tempfile import NamedTemporaryFile
from xml.etree import ElementTree
import os
import pathlib
import re
import sys
import requests


def http_get(resource, ignore_error=False, username=None, password=None):
    """ get the contents of a URL """

    try:
        if username and password:
            response = requests.get(resource, auth=(username, password), timeout=10)
        else:
            response = requests.get(resource, timeout=10)
        response.raise_for_status()
    except requests.exceptions.HTTPError as http_err:
        errstr = str(http_err)
        print(
            f'%{resource} returns HTTP error %{response.status_code}: %{errstr}\n'
        )
        if ignore_error:
            return ''
        print('Aborting.')
        sys.exit(1)
    return response.text


def parse_jira_data(filename):
    """ returns a map of (project, issue) => attachment id """
    tree = ElementTree.parse(filename)
    root = tree.getroot()
    jirapattern = re.compile(r'([A-Z]+)\-([0-9]+)')
    result = {}
    for item in root.findall('./channel/item'):
        jirakey = item.find('key')
        if jirakey is None:
            continue
        jiraissue = jirakey.text
        matcher = jirapattern.match(jiraissue)
        if not matcher:
            continue
        jiraissue = (matcher.group(1), matcher.group(2))
        attachmentids = []
        for jiraattachment in item.findall('./attachments/attachment'):
            attachmentid = jiraattachment.get('id')
            try:
                attachmentids.append(int(attachmentid))
            except ValueError:
                pass
        if attachmentids:
            attachmentids.sort()
            result[jiraissue] = attachmentids[-1]
    return result


def main():  #pylint: disable=too-many-branches, too-many-statements, too-many-locals
    """ main program """
    parser = ArgumentParser(prog='jenkins-admin')
    if os.getenv('JENKINS_URL'):
        parser.set_defaults(jenkinsurl=os.getenv('JENKINS_URL'))
    if os.getenv('JOB_NAME'):
        parser.set_defaults(jenkinsJobName=os.getenv('JOB_NAME'))
    else:
        parser.set_defaults(jenkinsJobName='PreCommit-Admin')

    parser.set_defaults(jenkinsJobTemplate='PreCommit-{project}')
    parser.add_argument('--initialize',
                        action='store_true',
                        dest='jenkinsInit',
                        help='Start a new patch_tested.txt file')
    parser.add_argument('--jenkins-jobname',
                        type=str,
                        dest='jenkinsJobName',
                        help='PreCommit-Admin JobName',
                        metavar='JOB_NAME')
    parser.add_argument('--jenkins-project-template',
                        type=str,
                        dest='jenkinsJobTemplate',
                        help='Template for project jobs',
                        metavar='TEMPLATE')
    parser.add_argument('--jenkins-token',
                        type=str,
                        dest='jenkinsToken',
                        help='Jenkins Token',
                        metavar='TOKEN')
    parser.add_argument('--jenkins-url',
                        type=str,
                        dest='jenkinsurl',
                        help='Jenkins base URL',
                        metavar='URL')
    parser.add_argument(
        '--jenkins-url-override',
        type=str,
        dest='jenkinsurloverrides',
        action='append',
        help='Project specific Jenkins base URL',
        metavar='PROJECT=URL',
    )
    parser.add_argument('--jira-filter',
                        type=str,
                        dest='jiraFilter',
                        help='JIRA filter URL',
                        metavar='URL')
    parser.add_argument('--jira-user',
                        type=str,
                        dest='jiraUser',
                        help='JIRA username')
    parser.add_argument('--jira-password',
                        type=str,
                        dest='jiraPassword',
                        help='JIRA password')
    parser.add_argument('--live',
                        dest='live',
                        action='store_true',
                        help='Submit Job to jenkins')
    parser.add_argument('--max-history',
                        dest='history',
                        type=int,
                        help='Maximum history to store',
                        default=5000)
    parser.add_argument(
        '-V',
        '--version',
        dest='release_version',
        action='store_true',
        default=False,
        help="display version information for jenkins-admin and exit.")

    options = parser.parse_args()

    # Handle the version string right away and exit
    if options.release_version:
        execname = pathlib.Path(__file__)
        binversion = execname.joinpath("..", "..", "VERSION").resolve()
        mvnversion = execname.joinpath("..", "..", "..", "..", "..", ".mvn",
                                       "maven.config").resolve()
        if binversion.exists():
            with open(binversion, encoding='utf-8') as ver_file:
                print(ver_file.read().strip())
        elif mvnversion.exists():
            with open(mvnversion, encoding='utf-8') as ver_file:
                print(ver_file.read().split('=')[1].strip())
        sys.exit(0)

    token_frag = ''
    if options.jenkinsToken:
        token_frag = f'token={options.jenkinsToken}'
    else:
        token_frag = 'token={project}-token'
    if not options.jiraFilter:
        parser.error('ERROR: --jira-filter is a required argument.')
    if not options.jenkinsurl:
        parser.error(
            'ERROR: --jenkins-url or the JENKINS_URL environment variable is required.'
        )
    if options.history < 0:
        parser.error('ERROR: --max-history must be 0 or a positive integer.')
    jenkinsurloverrides = {}
    if options.jenkinsurloverrides:
        for override in options.jenkinsurloverrides:
            if '=' not in override:
                parser.error('Invalid Jenkins Url Override: ' + override)
            (project, url) = override.split('=', 1)
            jenkinsurloverrides[project.upper()] = url
    tempfile = NamedTemporaryFile(delete=False)  # pylint: disable=consider-using-with
    try:
        jobloghistory = None
        if not options.jenkinsInit:
            lsb = 'lastSuccessfulBuild/artifact/patch_tested.txt'
            lcb = 'lastCompletedBuild/artifact/patch_tested.txt'
            jobloghistory = http_get(
                f'{options.jenkinsurl}/job/{options.jenkinsJobName}/{lsb}',
                True)

            # if we don't have a successful build available try the last build

            if not jobloghistory:
                jobloghistory = http_get(
                    f'{options.jenkinsurl}/job/{options.jenkinsJobName}/{lcb}')
            jobloghistory = jobloghistory.strip().split('\n')
            if 'TESTED ISSUES' not in jobloghistory[0]:
                print(
                    'Downloaded patch_tested.txt control file may be corrupted. Failing.'
                )
                sys.exit(1)

        # we are either going to write a new one or rewrite the old one

        joblog = open('patch_tested.txt', 'w+')  # pylint: disable=consider-using-with

        if jobloghistory:
            if len(jobloghistory) > options.history:
                jobloghistory = [jobloghistory[0]] \
                                 + jobloghistory[len(jobloghistory) \
                                 - options.history:]
            for jobhistoryrecord in jobloghistory:
                joblog.write(jobhistoryrecord + '\n')
        else:
            joblog.write('TESTED ISSUES\n')
        joblog.flush()
        rssdata = http_get(options.jiraFilter, False, options.jiraUser,
                           options.jiraPassword)
        tempfile.write(rssdata.encode('utf-8'))
        tempfile.flush()
        for (key, attachment) in list(parse_jira_data(tempfile.name).items()):
            (project, issue) = key
            if jenkinsurloverrides.get(project):
                url = jenkinsurloverrides[project]
            else:
                url = options.jenkinsurl

            jenkinsurltemplate = url + '/job/' \
                + options.jenkinsJobTemplate \
                + '/buildWithParameters?' + token_frag \
                + '&ISSUE_NUM={issue}&ATTACHMENT_ID={attachment}'

            url_args = {
                'project': project,
                'issue': issue,
                'attachment': attachment,
            }
            jenkinsurl = jenkinsurltemplate.format(**url_args)

            # submit job

            jobname = f'{project}-{issue},{attachment}'
            if not jobloghistory or jobname not in jobloghistory:
                print(jobname + ' has not been processed, submitting')
                joblog.write(jobname + '\n')
                joblog.flush()
                if options.live:
                    http_get(jenkinsurl, True)
                else:
                    print('GET ' + jenkinsurl)
            else:
                print(jobname + ' has been processed, ignoring')
        joblog.close()
    finally:
        if options.live:
            os.remove(tempfile.name)
        else:
            print('JIRA Data is located: ' + tempfile.name)


if __name__ == '__main__':
    main()
