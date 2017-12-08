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

# Script uses a JIRA search filter to submit test Jenkins
# jobs for patch avilable issues. For more information see:
#  http://wiki.apache.org/general/PreCommitBuilds
#  https://builds.apache.org/job/PreCommit-Admin/

from optparse import OptionParser
from tempfile import NamedTemporaryFile
from xml.etree import ElementTree
import os, re, sys, urllib2

# max number of entries to keep in the patch_tested.txt file
MAX_HISTORY = 5000

def httpGet(resource, ignoreError=False):
  if ignoreError:
    try:
      return urllib2.urlopen(resource).read()
    except urllib2.URLError, e:
      print "ERROR retrieving resource %s: %s" % (resource, e)
      return ""
  return urllib2.urlopen(resource).read()


# returns a map of (project, issue) => attachment id
def parseJiraData(fileName):
  tree = ElementTree.parse(fileName)
  root = tree.getroot()
  jiraPattern = re.compile('([A-Z]+)\-([0-9]+)')
  result = {}
  for item in root.findall("./channel/item"):
    key = item.find('key')
    if key == None: continue
    issue = key.text
    matcher = jiraPattern.match(issue)
    if not matcher: continue
    issue = matcher.group(1), matcher.group(2)
    attachmentIds = []
    for attachment in item.findall('./attachments/attachment'):
      attachmentId = attachment.get('id')
      try:
        attachmentIds.append(int(attachmentId))
      except ValueError:
        pass
    if len(attachmentIds) > 0:
      attachmentIds.sort()
      result[issue] = attachmentIds[-1]
  return result

if __name__ == '__main__':
  parser = OptionParser()
  parser.add_option("--jenkins-url", dest="jenkinsUrl",
                    help="Jenkins base URL", metavar="URL")
  parser.add_option("--jenkins-token", dest="jenkinsToken",
                    help="Jenkins Token", metavar="TOKEN")
  parser.add_option("--jira-filter", dest="jiraFilter",
                    help="JIRA filter URL", metavar="URL")
  parser.add_option("--jenkins-url-override", dest="jenkinsUrlOverrides", action="append",
                    help="Project specific Jenkins base URL", metavar="PROJECT=URL")
  parser.add_option("--live", dest="live", action="store_true",
                    help="Submit Job to jenkins")
  (options, args) = parser.parse_args()
  if not options.jiraFilter:
    parser.error("JIRA Filter is a required argument")
  if not options.jenkinsUrl:
    parser.error("Jenkins URL is a required argument")
  if options.live and not options.jenkinsToken:
    parser.error("Jenkins Token is required when in live mode")
  jenkinsUrlOverrides = {}
  if options.jenkinsUrlOverrides:
    for override in options.jenkinsUrlOverrides:
      if "=" not in override:
        parser.error("Invalid Jenkins Url Override: " + override)
      (project, url) = override.split("=", 1)
      jenkinsUrlOverrides[project.upper()] = url
  tempFile = NamedTemporaryFile(delete=False)
  try:
    jobLogHistory = httpGet(options.jenkinsUrl + \
      "/job/PreCommit-Admin/lastSuccessfulBuild/artifact/patch_tested.txt", True)
    # if we don't have a successful build available try the last build
    if not jobLogHistory:
      jobLogHistory = httpGet(options.jenkinsUrl + \
        "/job/PreCommit-Admin/lastCompletedBuild/artifact/patch_tested.txt")
    jobLogHistory = jobLogHistory.strip().split("\n")
    if "TESTED ISSUES" not in jobLogHistory[0]:
      print "Downloaded patch_tested.txt control file may be corrupted. Failing."
      sys.exit(1)
    jobLog = open('patch_tested.txt', 'w+')
    if len(jobLogHistory)  > MAX_HISTORY:
      jobLogHistory = [ jobLogHistory[0] ] + jobLogHistory[len(jobLogHistory) - MAX_HISTORY:]
    for jobHistoryRecord in jobLogHistory:
      jobLog.write(jobHistoryRecord + "\n")
    jobLog.flush()
    rssData = httpGet(options.jiraFilter)
    tempFile.write(rssData)
    tempFile.flush()
    for key, attachment in parseJiraData(tempFile.name).items():
      (project, issue) = key
      if jenkinsUrlOverrides.has_key(project):
        url = jenkinsUrlOverrides[project]
      else:
        url = options.jenkinsUrl
      jenkinsUrlTemplate = url + "/job/PreCommit-{project}-Build/buildWithParameters" + \
        "?token={token}&ISSUE_NUM={issue}&ATTACHMENT_ID={attachment}"
      urlArgs = {'token': options.jenkinsToken, 'project': project, 'issue': issue, 'attachment': attachment }
      jenkinsUrl = jenkinsUrlTemplate.format(**urlArgs)
      # submit job
      jobName = "%s-%s,%s" % (project, issue, attachment)
      if jobName not in jobLogHistory:
        print jobName + " has not been processed, submitting"
        jobLog.write(jobName + "\n")
        jobLog.flush()
        if options.live:
          httpGet(jenkinsUrl, True)
        else:
          print "GET " + jenkinsUrl
      else:
        print jobName + " has been processed, ignoring"
    jobLog.close()
  finally:
    if options.live:
      os.remove(tempFile.name)
    else:
      print "JIRA Data is located: " + tempFile.name
