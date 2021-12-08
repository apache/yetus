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
""" Handle versions in JIRA """

import copy
import http.client
import json
import logging
import re
import sys
import urllib.error
from .utils import get_jira

class ReleaseVersion:
    ''' a very simple version handler '''

    def __init__(self, version=None):
        self.rawversion = version
        self.rawcomponents = re.split('[ \\.]', version)
        self.intcomponents = []
        for value in self.rawcomponents:
            try:
                self.intcomponents.append(int(value))
            except ValueError:
                try:
                    self.intcomponents.append(int(value[1:]))
                except ValueError:
                    self.intcomponents.append(-1)

    def __repr__ (self):
        return f"ReleaseVersion ('{str(self)}')"

    def __str__(self):
        return self.rawversion

    def __lt__(self, cmpver):  # pylint: disable=too-many-return-statements
        if isinstance(cmpver, (int,str)):
            cmpver = ReleaseVersion(cmpver)

        # shortcut
        if self.rawversion == cmpver.rawversion:
            return False

        srcver = copy.deepcopy(self)

        if len(srcver.rawcomponents) < len(cmpver.rawcomponents):
            for index in range(0, len(cmpver.rawcomponents)):
                srcver.rawcomponents.append('0')
                srcver.intcomponents.append(0)

        for index, rawvalue in enumerate(srcver.rawcomponents):  # pylint: disable=unused-variable
            if index+1 > len(cmpver.rawcomponents):
                cmpver.rawcomponents.append('0')
                cmpver.intcomponents.append(0)

            intvalue = srcver.intcomponents[index]
            if intvalue == -1 or cmpver.intcomponents[index] == -1:
                return self.rawversion < cmpver.rawversion

            if intvalue < cmpver.intcomponents[index]:
                return True

            if intvalue > cmpver.intcomponents[index]:
                return False

        return False


class GetVersions:  # pylint: disable=too-few-public-methods
    """ List of version strings """
    def __init__(self, versions, projects, jira_base_url):
        self.userversions = sorted(versions, key=ReleaseVersion)
        logging.info("Looking for %s through %s", self.userversions[0],
                     self.userversions[-1])

        serverversions = set()
        for project in projects:
            url = f"{jira_base_url}/rest/api/2/project/{project.upper()}/versions"
            try:
                resp = get_jira(url)
            except (urllib.error.HTTPError, urllib.error.URLError,
                    http.client.BadStatusLine):
                sys.exit(1)

            datum = json.loads(resp.read())
            for data in datum:
                serverversions.add(data['name'])

        serverversions = sorted(serverversions, key=ReleaseVersion)

        combolist = serverversions + self.userversions
        comboset = set(combolist)
        combolist = sorted(comboset,  key=ReleaseVersion)

        start_index = combolist.index(self.userversions[0])
        end_index = combolist.index(self.userversions[-1])

        self.versions = []
        for candidate in combolist[start_index:end_index+1]:
            if candidate in serverversions:
                self.versions.append(candidate)
                logging.info('Adding %s to the list', candidate)

    def getlist(self):
        """ Get the list of versions """
        return self.versions
