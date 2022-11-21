#!/usr/bin/env python3
#
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
""" process bash scripts and generate documentation from them """

# Do this immediately to prevent compiled forms

import logging
import os
import pathlib
import re
import sys

from argparse import ArgumentParser

sys.dont_write_bytecode = True

ASFLICENSE = '''
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


class ShellFunction:  # pylint: disable=too-many-instance-attributes
    """a shell function"""

    def __init__(self, filename='Unknown'):
        '''Initializer'''
        self.audience = ''
        self.description = []
        self.filename = filename
        self.linenum = 0
        self.name = ''
        self.params = []
        self.replacebool = False
        self.replacerawtext = ''
        self.replacetext = 'Not Replaceable'
        self.returnt = []
        self.stability = ''

    def __lt__(self, other):
        '''comparison'''
        if self.audience == other.audience:
            if self.stability == other.stability:
                if self.replacebool == other.replacebool:
                    return self.name < other.name
                if self.replacebool:
                    return True
            else:
                if self.stability == "Stable":
                    return True
        else:
            if self.audience == "Public":
                return True
        return False

    def header(self):
        '''get the header for this function'''
        return f"{self.audience}/{self.stability}/{self.replacetext}"

    def getdocpage(self):
        '''get the built document page for this function'''
        params = " ".join(self.params)
        usage = f"{self.name} {params}"
        description = "\n".join(self.description)
        if not self.returnt:
            returntext = 'Nothing'
        else:
            returntext = "\n".join(self.returnt)
        return (f"### `{self.name}`\n\n"
                "* Synopsis\n\n"
                f"```\n{usage}\n"
                "```\n\n"
                "* Description\n\n"
                f"{description}\n\n"
                "* Returns\n\n"
                f"{returntext}\n\n"
                "| Classification | Level |\n"
                "| :--- | :--- |\n"
                f"| Audience | {self.audience} |\n"
                f"| Stability | {self.stability} |\n"
                f"| Replaceable | {self.replacebool} |\n\n")

    def isprivateandnotreplaceable(self):
        ''' is this function Private and not replaceable? '''
        return self.audience == "Private" and not self.replacebool

    def lint(self):
        '''Lint this function'''
        validvalues = {
            "audience": ("Public", "Private"),
            "stability": ("Stable", "Evolving"),
            "replacerawtext": ("yes", "no"),
        }
        for attribute, attrvalues in validvalues.items():
            value = getattr(self, attribute)
            if (not value or value == '') and attribute != 'replacerawtext':
                logging.error("%s:%u:ERROR: function %s has no @%s",
                              self.filename, self.linenum, self.name,
                              attribute.lower())
            elif value not in attrvalues:
                if attribute == 'replacerawtext' and value == '':
                    continue
                validvalue = "|".join(v.lower() for v in attrvalues)
                logging.error(
                    "%s:%d:ERROR: function %s has invalid value (%s) for @%s (%s)",
                    self.filename, self.linenum, self.name, value.lower(),
                    attribute.lower().replace('rawtext', 'able'), validvalue)

    def __str__(self):
        '''Generate a string for this function'''
        return f"{{{self.name} {self.audience} {self.stability} {self.replacebool}}}"


class ProcessFile:
    ''' shell file processor '''

    FUNCTIONRE = re.compile(r"^(\w+) *\(\) *{")

    def __init__(self, filename=None, skipsuperprivate=False):
        self.filename = filename
        self.functions = []
        self.skipsuperprivate = skipsuperprivate

    def isignored(self):
        """Checks for the presence of the marker(SHELLDOC-IGNORE) to ignore the file.

      Marker needs to be in a line of its own and can not
      be an inline comment.

      A leading '#' and white-spaces(leading or trailing)
      are trimmed before checking equality.

      Comparison is case sensitive and the comment must be in
      UPPERCASE.
      """
        with open(self.filename) as input_file:  #pylint: disable=unspecified-encoding
            for line in input_file:
                if line.startswith(
                        "#") and line[1:].strip() == "SHELLDOC-IGNORE":
                    return True
            return False

    @staticmethod
    def _docstrip(key, dstr):
        '''remove extra spaces from shelldoc phrase'''
        dstr = re.sub(f"^## @{key} ", "", dstr)
        dstr = dstr.strip()
        return dstr

    def _process_description(self, funcdef, text=None):
        if not text:
            funcdef.description = []
            return
        funcdef.description.append(self._docstrip('description', text))

    def _process_audience(self, funcdef, text=None):
        '''set the audience of the function'''
        if not text:
            return
        funcdef.audience = self._docstrip('audience', text)
        funcdef.audience = funcdef.audience.capitalize()

    def _process_stability(self, funcdef, text=None):
        '''set the stability of the function'''
        if not text:
            return
        funcdef.stability = self._docstrip('stability', text)
        funcdef.stability = funcdef.stability.capitalize()

    def _process_replaceable(self, funcdef, text=None):
        '''set the replacement state'''
        if not text:
            return
        funcdef.replacerawtext = self._docstrip("replaceable", text)
        if funcdef.replacerawtext in ['yes', 'Yes', 'true', 'True']:
            funcdef.replacebool = True
        else:
            funcdef.replacebool = False
        if funcdef.replacebool:
            funcdef.replacetext = 'Replaceable'
        else:
            funcdef.replacetext = 'Not Replaceable'

    def _process_param(self, funcdef, text=None):
        '''add a parameter'''
        if not text:
            funcdef.params = []
            return
        funcdef.params.append(self._docstrip('param', text))

    def _process_return(self, funcdef, text=None):
        '''add a return value'''
        if not text:
            funcdef.returnt = []
            return
        funcdef.returnt.append(self._docstrip('return', text))

    @staticmethod
    def _process_function(funcdef, text=None, linenum=1):
        '''set the name of the function'''
        if ProcessFile.FUNCTIONRE.match(text):
            definition = ProcessFile.FUNCTIONRE.match(text).groups()[0]
        else:
            definition = text.split()[1]
        funcdef.name = definition.replace("(", "").replace(")", "")
        funcdef.linenum = linenum

    def process_file(self):
        """ stuff all of the functions into an array """
        self.functions = []

        mapping = {
            '## @description': '_process_description',
            '## @audience': '_process_audience',
            '## @stability': '_process_stability',
            '## @replaceable': '_process_replaceable',
            '## @param': '_process_param',
            '## @return': '_process_return',
        }

        if self.isignored():
            return

        try:
            with open(self.filename, "r") as shellcode:  #pylint: disable=unspecified-encoding
                # if the file contains a comment containing
                # only "SHELLDOC-IGNORE" then skip that file

                funcdef = ShellFunction(self.filename)
                linenum = 0
                for line in shellcode:
                    linenum = linenum + 1
                    for text, method in mapping.items():
                        if line.startswith(text):
                            getattr(self, method)(funcdef, text=line)

                    if line.startswith(
                            'function') or ProcessFile.FUNCTIONRE.match(line):
                        self._process_function(funcdef,
                                               text=line,
                                               linenum=linenum)

                        if self.skipsuperprivate and funcdef.isprivateandnotreplaceable(
                        ):
                            pass
                        else:
                            self.functions.append(funcdef)
                        funcdef = ShellFunction(self.filename)

        except OSError as err:
            logging.error("ERROR: Failed to read from file: %s. Skipping.",
                          err.filename)
            self.functions = []


class MarkdownReport:
    ''' generate a markdown report '''

    def __init__(self, functions, filename=None):
        self.filename = filename
        self.filepath = pathlib.Path(self.filename)
        if functions:
            self.functions = sorted(functions)
        else:
            self.functions = None

    def write_tableofcontents(self, fhout):
        '''build a table of contents'''
        header = None
        for function in self.functions:
            if header != function.header():
                header = function.header()
                fhout.write(f"  * {header}\n")
            markdownsafename = function.name.replace("_", r"\_")
            fhout.write(f"    * [{markdownsafename}](#{function.name})\n")

    def write_output(self):
        """ write the markdown file """

        self.filepath.parent.mkdir(parents=True, exist_ok=True)

        with open(self.filename, "w", encoding='utf-8') as outfile:
            outfile.write(ASFLICENSE)
            self.write_tableofcontents(outfile)
            outfile.write("\n------\n\n")

            header = []
            for function in self.functions:
                if header != function.header():
                    header = function.header()
                    outfile.write(f"## {header}\n")
                outfile.write(function.getdocpage())


def process_input(inputlist, skipprnorep):
    """ take the input and loop around it """

    def call_process_file(filename, skipsuperprivate):
        ''' handle building a ProcessFile '''
        fileprocessor = ProcessFile(filename=filename,
                                    skipsuperprivate=skipsuperprivate)
        fileprocessor.process_file()
        return fileprocessor.functions

    allfuncs = []
    for inputname in inputlist:
        if pathlib.Path(inputname).is_dir():
            for dirpath, dirnames, filenames in os.walk(inputname):  #pylint: disable=unused-variable
                for fname in filenames:
                    if fname.endswith('sh'):
                        allfuncs = allfuncs + call_process_file(
                            filename=pathlib.Path(dirpath).joinpath(fname),
                            skipsuperprivate=skipprnorep)
        else:
            allfuncs = allfuncs + call_process_file(
                filename=inputname, skipsuperprivate=skipprnorep)
    if allfuncs is None:
        logging.error("ERROR: no functions found.")
        sys.exit(1)

    allfuncs = sorted(allfuncs)
    return allfuncs


def getversion():
    """ print the version file"""
    basepath = pathlib.Path(__file__).parent.resolve()
    for versionfile in [
            basepath.resolve().joinpath('VERSION'),
            basepath.parent.resolve().joinpath('VERSION')
    ]:
        if versionfile.exists():
            with open(versionfile, encoding='utf-8') as ver_file:
                version = ver_file.read()
            return version
    mvnversion = basepath.parent.parent.parent.parent.resolve().joinpath(
        '.mvn', 'maven.config')
    if mvnversion.exists():
        with open(mvnversion, encoding='utf-8') as ver_file:
            return ver_file.read().split('=')[1].strip()

    return 'Unknown'


def process_arguments():
    ''' deal with parameters '''
    parser = ArgumentParser(
        prog='shelldocs',
        epilog="You can mark a file to be ignored by shelldocs by adding"
        " 'SHELLDOC-IGNORE' as comment in its own line. " +
        "--input may be given multiple times.")
    parser.add_argument("-o",
                        "--output",
                        dest="outfile",
                        action="store",
                        type=str,
                        help="file to create",
                        metavar="OUTFILE")
    parser.add_argument("-i",
                        "--input",
                        dest="infile",
                        action="append",
                        type=str,
                        help="file to read",
                        metavar="INFILE")
    parser.add_argument("--skipprnorep",
                        dest="skipprnorep",
                        action="store_true",
                        help="Skip Private & Not Replaceable")
    parser.add_argument("--lint",
                        dest="lint",
                        action="store_true",
                        help="Enable lint mode")
    parser.add_argument(
        "-V",
        "--version",
        dest="release_version",
        action="store_true",
        default=False,
        help="display version information for shelldocs and exit.")

    options = parser.parse_args()

    if options.release_version:
        print(getversion())
        sys.exit(0)

    if options.infile is None:
        parser.error("At least one input file needs to be supplied")
    elif options.outfile is None and options.lint is None:
        parser.error(
            "At least one of output file and lint mode needs to be specified")

    return options


def main():
    '''main entry point'''
    logging.basicConfig(format='%(message)s')

    options = process_arguments()

    allfuncs = process_input(options.infile, options.skipprnorep)

    if options.lint:
        for funcs in allfuncs:
            funcs.lint()

    if options.outfile:
        mdreport = MarkdownReport(allfuncs, filename=options.outfile)
        mdreport.write_output()


if __name__ == "__main__":
    main()
