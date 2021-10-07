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

import http.client
import json
import logging
import sys
import urllib.error
from .utils import get_jira

try:
    from pip._vendor.packaging.version import LegacyVersion as PythonVersion
except ImportError:
    try:
        from setuptools._vendor.packaging.version import LegacyVersion as PythonVersion
    except ImportError:
        try:
            from pkg_resources._vendor.packaging.version import LegacyVersion as PythonVersion
        except ImportError:
            try:
                from packaging.version import LegacyVersion as PythonVersion
            except ImportError:
                logging.error(
                    "This script requires a packaging module to be installed.")
                sys.exit(1)


class GetVersions:  # pylint: disable=too-few-public-methods
    """ List of version strings """
    def __init__(self, versions, projects, jira_base_url):
        self.newversions = []
        versions = sorted(versions, key=PythonVersion)
        logging.info("Looking for %s through %s", {versions[0]},
                     {versions[-1]})
        newversions = set()
        for project in projects:
            url = f"{jira_base_url}/rest/api/2/project/{project.upper()}/versions"
            try:
                resp = get_jira(url)
            except (urllib.error.HTTPError, urllib.error.URLError,
                    http.client.BadStatusLine):
                sys.exit(1)

            datum = json.loads(resp.read())
            for data in datum:
                newversions.add(PythonVersion(data['name']))
        newlist = list(newversions.copy())
        newlist.append(PythonVersion(versions[0]))
        newlist.append(PythonVersion(versions[-1]))
        newlist = sorted(newlist)
        start_index = newlist.index(PythonVersion(versions[0]))
        end_index = len(newlist) - 1 - newlist[::-1].index(
            PythonVersion(versions[-1]))
        for newversion in newlist[start_index + 1:end_index]:
            if newversion in newversions:
                logging.info("Adding %s to the list", newversion)
                self.newversions.append(newversion)

    def getlist(self):
        """ Get the list of versions """
        return self.newversions
