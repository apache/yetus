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
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

from optparse import OptionParser
from tempfile import NamedTemporaryFile
from xml.etree import ElementTree
import base64
import httplib
import os
import re
import sys
import urllib2

def httpGet(resource, ignoreError=False, username=None, password=None):
    request = urllib2.Request(resource)
    if username and password:
      base64string = base64.b64encode('%s:%s' % (username, password))
      request.add_header("Authorization", "Basic %s" % base64string)
    try:
        response = urllib2.urlopen(request)
    except urllib2.HTTPError, http_err:
        code = http_err.code
        print '%s returns HTTP error %d: %s' \
              % (resource, code, http_err.reason)
        if ignoreError:
            return ''
        else:
            print 'Aborting.'
            sys.exit(1)
    except urllib2.URLError, url_err:
        print 'Error contacting %s: %s' % (resource, url_err.reason)
        if ignoreError:
            return ''
        else:
            raise url_err
    except httplib.BadStatusLine, err:
        if ignoreError:
            return ''
        else:
            raise err
    return response.read()


# returns a map of (project, issue) => attachment id

def parseJiraData(fileName):
    tree = ElementTree.parse(fileName)
    root = tree.getroot()
    jiraPattern = re.compile('([A-Z]+)\-([0-9]+)')
    result = {}
    for item in root.findall('./channel/item'):
        jirakey = item.find('key')
        if jirakey is None:
            continue
        jiraissue = jirakey.text
        matcher = jiraPattern.match(jiraissue)
        if not matcher:
            continue
        jiraissue = (matcher.group(1), matcher.group(2))
        attachmentIds = []
        for jiraattachment in item.findall('./attachments/attachment'):
            attachmentId = jiraattachment.get('id')
            try:
                attachmentIds.append(int(attachmentId))
            except ValueError:
                pass
        if attachmentIds:
            attachmentIds.sort()
            result[jiraissue] = attachmentIds[-1]
    return result


if __name__ == '__main__':
    parser = OptionParser(prog = 'jenkins-admin')
    if os.getenv('JENKINS_URL'):
        parser.set_defaults(jenkinsUrl=os.getenv('JENKINS_URL'))
    if os.getenv('JOB_NAME'):
        parser.set_defaults(jenkinsJobName=os.getenv('JOB_NAME'))
    else:
        parser.set_defaults(jenkinsJobName='PreCommit-Admin')

    parser.set_defaults(jenkinsJobTemplate='PreCommit-{project}')
    parser.add_option('--initialize', action='store_true',
                      dest='jenkinsInit',
                      help='Start a new patch_tested.txt file')
    parser.add_option('--jenkins-jobname', type='string',
                      dest='jenkinsJobName',
                      help='PreCommit-Admin JobName', metavar='JOB_NAME')
    parser.add_option('--jenkins-project-template', type='string',
                      dest='jenkinsJobTemplate',
                      help='Template for project jobs',
                      metavar='TEMPLATE')
    parser.add_option('--jenkins-token', type='string',
                      dest='jenkinsToken', help='Jenkins Token',
                      metavar='TOKEN')
    parser.add_option('--jenkins-url', type='string', dest='jenkinsUrl'
                      , help='Jenkins base URL', metavar='URL')
    parser.add_option(
        '--jenkins-url-override',
        type='string',
        dest='jenkinsUrlOverrides',
        action='append',
        help='Project specific Jenkins base URL',
        metavar='PROJECT=URL',
        )
    parser.add_option('--jira-filter', type='string', dest='jiraFilter',
                      help='JIRA filter URL', metavar='URL')
    parser.add_option('--jira-user', type='string', dest='jiraUser',
                      help='JIRA username')
    parser.add_option('--jira-password', type='string', dest='jiraPassword',
                      help='JIRA password')
    parser.add_option('--live', dest='live', action='store_true',
                      help='Submit Job to jenkins')
    parser.add_option('--max-history', dest='history', type='int',
                      help='Maximum history to store', default=5000)
    parser.add_option(
        '-V',
        '--version',
        dest='release_version',
        action='store_true',
        default=False,
        help="display version information for jenkins-admin and exit.")

    (options, args) = parser.parse_args()

    # Handle the version string right away and exit
    if options.release_version:
        with open(
                os.path.join(
                    os.path.dirname(__file__), "../../VERSION"), 'r') as ver_file:
            print ver_file.read()
        sys.exit(0)

    tokenFrag = ''
    if options.jenkinsToken:
        tokenFrag = 'token=%s' % options.jenkinsToken
    else:
        tokenFrag = 'token={project}-token'
    if not options.jiraFilter:
        parser.error('ERROR: --jira-filter is a required argument.')
    if not options.jenkinsUrl:
        parser.error('ERROR: --jenkins-url or the JENKINS_URL environment variable is required.'
                     )
    if options.history < 0:
        parser.error('ERROR: --max-history must be 0 or a positive integer.'
                     )
    jenkinsUrlOverrides = {}
    if options.jenkinsUrlOverrides:
        for override in options.jenkinsUrlOverrides:
            if '=' not in override:
                parser.error('Invalid Jenkins Url Override: '
                             + override)
            (project, url) = override.split('=', 1)
            jenkinsUrlOverrides[project.upper()] = url
    tempFile = NamedTemporaryFile(delete=False)
    try:
        jobLogHistory = None
        if not options.jenkinsInit:
            jobLogHistory = httpGet(options.jenkinsUrl
                                    + '/job/%s/lastSuccessfulBuild/artifact/patch_tested.txt'
                                     % options.jenkinsJobName, True)

            # if we don't have a successful build available try the last build

            if not jobLogHistory:
                jobLogHistory = httpGet(options.jenkinsUrl
                        + '/job/%s/lastCompletedBuild/artifact/patch_tested.txt'
                         % options.jenkinsJobName)
            jobLogHistory = jobLogHistory.strip().split('\n')
            if 'TESTED ISSUES' not in jobLogHistory[0]:
                print 'Downloaded patch_tested.txt control file may be corrupted. Failing.'
                sys.exit(1)

        # we are either going to write a new one or rewrite the old one

        jobLog = open('patch_tested.txt', 'w+')

        if jobLogHistory:
            if len(jobLogHistory) > options.history:
                jobLogHistory = [jobLogHistory[0]] \
                    + jobLogHistory[len(jobLogHistory)
                    - options.history:]
            for jobHistoryRecord in jobLogHistory:
                jobLog.write(jobHistoryRecord + '\n')
        else:
            jobLog.write('TESTED ISSUES\n')
        jobLog.flush()
        rssData = httpGet(options.jiraFilter,False,options.jiraUser,options.jiraPassword)
        tempFile.write(rssData)
        tempFile.flush()
        for (key, attachment) in parseJiraData(tempFile.name).items():
            (project, issue) = key
            if jenkinsUrlOverrides.has_key(project):
                url = jenkinsUrlOverrides[project]
            else:
                url = options.jenkinsUrl

            jenkinsUrlTemplate = url + '/job/' \
                + options.jenkinsJobTemplate \
                + '/buildWithParameters?' + tokenFrag \
                + '&ISSUE_NUM={issue}&ATTACHMENT_ID={attachment}'

            urlArgs = {
                'project': project,
                'issue': issue,
                'attachment': attachment,
                }
            jenkinsUrl = jenkinsUrlTemplate.format(**urlArgs)

            # submit job

            jobName = '%s-%s,%s' % (project, issue, attachment)
            if not jobLogHistory or jobName not in jobLogHistory:
                print jobName + ' has not been processed, submitting'
                jobLog.write(jobName + '\n')
                jobLog.flush()
                if options.live:
                    httpGet(jenkinsUrl, True)
                else:
                    print 'GET ' + jenkinsUrl
            else:
                print jobName + ' has been processed, ignoring'
        jobLog.close()
    finally:
        if options.live:
            os.remove(tempFile.name)
        else:
            print 'JIRA Data is located: ' + tempFile.name
