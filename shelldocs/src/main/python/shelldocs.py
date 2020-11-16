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
import sys
import os
import re
import errno
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

FUNCTIONRE = re.compile(r"^(\w+) *\(\) *{")


def docstrip(key, dstr):
    '''remove extra spaces from shelldoc phrase'''
    dstr = re.sub("^## @%s " % key, "", dstr)
    dstr = dstr.lstrip()
    dstr = dstr.rstrip()
    return dstr


def toc(tlist):
    '''build a table of contents'''
    tocout = []
    header = ()
    for i in tlist:
        if header != i.getinter():
            header = i.getinter()
            line = "  * %s\n" % (i.headerbuild())
            tocout.append(line)
        line = "    * [%s](#%s)\n" % (i.getname().replace("_",
                                                          r"\_"), i.getname())
        tocout.append(line)
    return tocout


class ShellFunction:  # pylint: disable=too-many-public-methods, too-many-instance-attributes
    """a shell function"""
    def __init__(self, filename):
        '''Initializer'''
        self.name = None
        self.audience = None
        self.stability = None
        self.replaceb = None
        self.returnt = None
        self.desc = None
        self.params = None
        self.filename = filename
        self.linenum = 0

    def __lt__(self, other):
        '''comparison'''
        if self.audience == other.audience:
            if self.stability == other.stability:
                if self.replaceb == other.replaceb:
                    return self.name < other.name
                if self.replaceb == "Yes":
                    return True
            else:
                if self.stability == "Stable":
                    return True
        else:
            if self.audience == "Public":
                return True
        return False

    def reset(self):
        '''empties current function'''
        self.name = None
        self.audience = None
        self.stability = None
        self.replaceb = None
        self.returnt = None
        self.desc = None
        self.params = None
        self.linenum = 0
        self.filename = None

    def getfilename(self):
        '''get the name of the function'''
        if self.filename is None:
            return "undefined"
        return self.filename

    def setname(self, text):
        '''set the name of the function'''
        if FUNCTIONRE.match(text):
            definition = FUNCTIONRE.match(text).groups()[0]
        else:
            definition = text.split()[1]
        self.name = definition.replace("(", "").replace(")", "")

    def getname(self):
        '''get the name of the function'''
        if self.name is None:
            return "None"
        return self.name

    def setlinenum(self, linenum):
        '''set the line number of the function'''
        self.linenum = linenum

    def getlinenum(self):
        '''get the line number of the function'''
        return self.linenum

    def setaudience(self, text):
        '''set the audience of the function'''
        self.audience = docstrip("audience", text)
        self.audience = self.audience.capitalize()

    def getaudience(self):
        '''get the audience of the function'''
        if self.audience is None:
            return "None"
        return self.audience

    def setstability(self, text):
        '''set the stability of the function'''
        self.stability = docstrip("stability", text)
        self.stability = self.stability.capitalize()

    def getstability(self):
        '''get the stability of the function'''
        if self.stability is None:
            return "None"
        return self.stability

    def setreplace(self, text):
        '''set the replacement state'''
        self.replaceb = docstrip("replaceable", text)
        self.replaceb = self.replaceb.capitalize()

    def getreplace(self):
        '''get the replacement state'''
        if self.replaceb == "Yes":
            return self.replaceb
        return "No"

    def getinter(self):
        '''get the function state'''
        return self.getaudience(), self.getstability(), self.getreplace()

    def addreturn(self, text):
        '''add a return state'''
        if self.returnt is None:
            self.returnt = []
        self.returnt.append(docstrip("return", text))

    def getreturn(self):
        '''get the complete return state'''
        if self.returnt is None:
            return "Nothing"
        return "\n\n".join(self.returnt)

    def adddesc(self, text):
        '''add to the description'''
        if self.desc is None:
            self.desc = []
        self.desc.append(docstrip("description", text))

    def getdesc(self):
        '''get the description'''
        if self.desc is None:
            return "None"
        return " ".join(self.desc)

    def addparam(self, text):
        '''add a parameter'''
        if self.params is None:
            self.params = []
        self.params.append(docstrip("param", text))

    def getparams(self):
        '''get all of the parameters'''
        if self.params is None:
            return ""
        return " ".join(self.params)

    def getusage(self):
        '''get the usage string'''
        line = "%s %s" % (self.name, self.getparams())
        return line.rstrip()

    def headerbuild(self):
        '''get the header for this function'''
        if self.getreplace() == "Yes":
            replacetext = "Replaceable"
        else:
            replacetext = "Not Replaceable"
        line = "%s/%s/%s" % (self.getaudience(), self.getstability(),
                             replacetext)
        return line

    def getdocpage(self):
        '''get the built document page for this function'''
        line = "### `%s`\n\n"\
             "* Synopsis\n\n"\
             "```\n%s\n"\
             "```\n\n" \
             "* Description\n\n" \
             "%s\n\n" \
             "* Returns\n\n" \
             "%s\n\n" \
             "| Classification | Level |\n" \
             "| :--- | :--- |\n" \
             "| Audience | %s |\n" \
             "| Stability | %s |\n" \
             "| Replaceable | %s |\n\n" \
             % (self.getname(),
                self.getusage(),
                self.getdesc(),
                self.getreturn(),
                self.getaudience(),
                self.getstability(),
                self.getreplace())
        return line

    def lint(self):
        '''Lint this function'''
        getfuncs = {
            "audience": self.getaudience,
            "stability": self.getstability,
            "replaceable": self.getreplace,
        }
        validvalues = {
            "audience": ("Public", "Private"),
            "stability": ("Stable", "Evolving"),
            "replaceable": ("Yes", "No"),
        }
        messages = []
        for attr in ("audience", "stability", "replaceable"):
            value = getfuncs[attr]()
            if value == "None":
                messages.append("%s:%u: ERROR: function %s has no @%s" %
                                (self.getfilename(), self.getlinenum(),
                                 self.getname(), attr.lower()))
            elif value not in validvalues[attr]:
                validvalue = "|".join(v.lower() for v in validvalues[attr])
                messages.append(
                    "%s:%u: ERROR: function %s has invalid value (%s) for @%s (%s)"
                    % (self.getfilename(), self.getlinenum(), self.getname(),
                       value.lower(), attr.lower(), validvalue))
        return "\n".join(messages)

    def __str__(self):
        '''Generate a string for this function'''
        line = "{%s %s %s %s}" \
          % (self.getname(),
             self.getaudience(),
             self.getstability(),
             self.getreplace())
        return line


def marked_as_ignored(file_path):
    """Checks for the presence of the marker(SHELLDOC-IGNORE) to ignore the file.

    Marker needs to be in a line of its own and can not
    be an inline comment.

    A leading '#' and white-spaces(leading or trailing)
    are trimmed before checking equality.

    Comparison is case sensitive and the comment must be in
    UPPERCASE.
    """
    with open(file_path) as input_file:
        for line in input_file:
            if line.startswith("#") and line[1:].strip() == "SHELLDOC-IGNORE":
                return True
        return False


def process_file(filename, skipprnorep):
    """ stuff all of the functions into an array """
    allfuncs = []
    try:
        with open(filename, "r") as shellcode:
            # if the file contains a comment containing
            # only "SHELLDOC-IGNORE" then skip that file
            if marked_as_ignored(filename):
                return None
            funcdef = ShellFunction(filename)
            linenum = 0
            for line in shellcode:
                linenum = linenum + 1
                if line.startswith('## @description'):
                    funcdef.adddesc(line)
                elif line.startswith('## @audience'):
                    funcdef.setaudience(line)
                elif line.startswith('## @stability'):
                    funcdef.setstability(line)
                elif line.startswith('## @replaceable'):
                    funcdef.setreplace(line)
                elif line.startswith('## @param'):
                    funcdef.addparam(line)
                elif line.startswith('## @return'):
                    funcdef.addreturn(line)
                elif line.startswith('function') or FUNCTIONRE.match(line):
                    funcdef.setname(line)
                    funcdef.setlinenum(linenum)
                    if skipprnorep and \
                      funcdef.getaudience() == "Private" and \
                      funcdef.getreplace() == "No":
                        pass
                    else:
                        allfuncs.append(funcdef)
                    funcdef = ShellFunction(filename)
    except IOError as err:
        print("ERROR: Failed to read from file: %s. Skipping." % err.filename,
              file=sys.stderr)
        return None
    return allfuncs


def process_input(inputlist, skipprnorep):
    """ take the input and loop around it """
    allfuncs = []
    for filename in inputlist:  #pylint: disable=too-many-nested-blocks
        if os.path.isdir(filename):
            for root, dirs, files in os.walk(filename):  #pylint: disable=unused-variable
                for fname in files:
                    if fname.endswith('sh'):
                        newfuncs = process_file(filename=os.path.join(
                            root, fname),
                                                skipprnorep=skipprnorep)
                        if newfuncs:
                            allfuncs = allfuncs + newfuncs
        else:
            newfuncs = process_file(filename=filename, skipprnorep=skipprnorep)
            if newfuncs:
                allfuncs = allfuncs + newfuncs

    if allfuncs is None:
        print("ERROR: no functions found.", file=sys.stderr)
        sys.exit(1)

    allfuncs = sorted(allfuncs)
    return allfuncs


def write_output(filename, functions):
    """ write the markdown file """
    try:
        directory = os.path.dirname(filename)
        if not os.path.exists(directory):
            os.makedirs(directory)
    except OSError as exc:
        if exc.errno == errno.EEXIST and os.path.isdir(directory):
            pass
        else:
            print("Unable to create output directory %s: %u, %s" % \
                    (directory, exc.errno, exc.strerror))
            sys.exit(1)

    with open(filename, "w") as outfile:
        outfile.write(ASFLICENSE)
        for line in toc(functions):
            outfile.write(line)
        outfile.write("\n------\n\n")

        header = []
        for funcs in functions:
            if header != funcs.getinter():
                header = funcs.getinter()
                line = "## %s\n" % (funcs.headerbuild())
                outfile.write(line)
            outfile.write(funcs.getdocpage())


def main():
    '''main entry point'''
    parser = ArgumentParser(
        prog='shelldocs',
        epilog="You can mark a file to be ignored by shelldocs by adding"
        " 'SHELLDOC-IGNORE' as comment in its own line. "+
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
        with open(os.path.join(os.path.dirname(__file__), "../VERSION"),
                  'r') as ver_file:
            print(ver_file.read())
        sys.exit(0)

    if options.infile is None:
        parser.error("At least one input file needs to be supplied")
    elif options.outfile is None and options.lint is None:
        parser.error(
            "At least one of output file and lint mode needs to be specified")

    allfuncs = process_input(options.infile, options.skipprnorep)

    if options.lint:
        for funcs in allfuncs:
            message = funcs.lint()
            if message:
                print(message)

    if options.outfile is not None:
        write_output(options.outfile, allfuncs)


if __name__ == "__main__":
    main()
