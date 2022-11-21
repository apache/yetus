#!/usr/bin/env python3
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
''' helper app for detect-secrets to take the json and make it colon delimited '''

import json
import logging
import pathlib
import sys

hashdict = []

INPUTFILE = sys.argv[1]
INPUTPATH = pathlib.Path(INPUTFILE).resolve()

if len(sys.argv) == 3:
    HASHFILE = sys.argv[2]
    HASHPATH = pathlib.Path(HASHFILE).resolve()
    if HASHPATH.exists():
        with open(HASHPATH, encoding='utf-8') as filein:
            while True:
                line = filein.readline()
                if not line:
                    break
                if line.startswith('#'):
                    continue
                hashdict.append(line.strip())

if not INPUTPATH.exists() or not INPUTPATH.is_file():
    logging.error('%s does not exist or is not a file.', INPUTPATH)
    sys.exit(1)

with open(INPUTFILE, encoding='utf-8') as filein:
    rawdata = filein.read()

jsondata = json.loads(rawdata)

for filename, results in sorted(jsondata['results'].items(),
                                key=lambda x: x[0]):
    for result in results:
        linenumber = result['line_number']
        resulttype = result['type']
        hashsecret = result['hashed_secret']
        if hashsecret in hashdict:
            continue
        print(f'{filename}:{linenumber}:{hashsecret}:{resulttype}')
