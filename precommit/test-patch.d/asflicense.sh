#!/usr/bin/env bash
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


add_test_type asflicense

function asflicense_usage
{
  yetus_add_option "--asflicense-rat-excludes=<path>" "path to file containing exclusion patterns"
  yetus_add_option "--asflicense-rat-jar=<path>" "path to Apache Creadur Rat jar file"
}

function asflicense_parse_args
{
  declare i

  for i in "$@"; do
    case ${i} in
      --asflicense-rat-excludes=*)
        ASFLICENSE_RAT_EXCLUDES=${i#*=}
      ;;
      --asflicense-rat-jar=*)
        ASFLICENSE_RAT_JAR=${i#*=}
      ;;
    esac
  done

  case ${BUILDTOOL} in
    ant|gradle|maven)
      add_test asflicense
    ;;
    *)
      if [[ -f "${ASFLICENSE_RAT_JAR}" ]]; then
        add_test asflicense
      fi
    ;;
  esac
}

## @description  Verify all files have an Apache License
## @audience     private
## @stability    evolving
## @replaceable  no
## @return       0 on success
## @return       1 on failure
function asflicense_tests
{
  local numpatch
  local btfails=true

  big_console_header "Determining number of ASF License errors"

  start_clock

  personality_modules patch asflicense
  case ${BUILDTOOL} in
    ant)
      modules_workers patch asflicense releaseaudit
    ;;
    gradle)
      btfails=false
      modules_workers patch asflicense rat
    ;;
    maven)
      modules_workers patch asflicense -fn apache-rat:check
      btfails=false
    ;;
    *)
      if [[ -z "${ASFLICENSE_RAT_JAR}" ]]; then
        return 0
      fi

      btfails=false
      asflicense_writexsl "${PATCH_DIR}/asf.xsl"
      if [[ -f ${ASFLICENSE_RAT_EXCLUDES} ]]; then
        echo_and_redirect "${PATCH_DIR}/patch-asflicense.txt" \
        "${JAVA_HOME}/bin/java" \
            -jar "${ASFLICENSE_RAT_JAR}" \
            -s "${PATCH_DIR}/asf.xsl" \
            -E "${ASFLICENSE_RAT_EXCLUDES}" \
            -d "${BASEDIR}"
      else
        echo_and_redirect "${PATCH_DIR}/patch-asflicense.txt" \
        "${JAVA_HOME}/bin/java" \
            -jar "${ASFLICENSE_RAT_JAR}" \
            -s "${PATCH_DIR}/asf.xsl" \
            "${BASEDIR}"
      fi
    ;;
  esac

  # RAT fails the build if there are license problems.
  # so let's take advantage of that a bit.
  if [[ $? == 0 && ${btfails} = true ]]; then
    add_vote_table 1 asflicense "${BUILDMODEMSG} does not generate ASF License warnings."
    return 0
  fi

  if [[ ! -f "${PATCH_DIR}/patch-asflicense.txt" ]]; then
    #shellcheck disable=SC2038
    find "${BASEDIR}" -name rat.txt \
          -o -name releaseaudit_report.txt \
          -o -name rat-report.txt \
      | xargs cat > "${PATCH_DIR}/patch-asflicense.txt"
  fi

  if [[ ! -s "${PATCH_DIR}/patch-asflicense.txt" ]]; then
    if [[ ${btfails} = true ]]; then
      # if we're here, then build actually failed
      modules_messages patch asflicense true
      return 1
    else
      add_vote_table 0 asflicense "ASF License check generated no output?"
      return 0
    fi
  fi

  numpatch=$("${GREP}" -c '\!?????' "${PATCH_DIR}/patch-asflicense.txt")
  echo ""
  echo ""
  echo "There appear to be ${numpatch} ASF License warnings after applying the patch."
  if [[ -n ${numpatch}
     && ${numpatch} -gt 0 ]] ; then
    add_vote_table -1 asflicense "${BUILDMODEMSG} generated ${numpatch} ASF License warnings."

    echo "Lines that start with ????? in the ASF License "\
        "report indicate files that do not have an Apache license header:" \
          > "${PATCH_DIR}/patch-asflicense-problems.txt"

    ${GREP} '\!?????' "${PATCH_DIR}/patch-asflicense.txt" \
    >>  "${PATCH_DIR}/patch-asflicense-problems.txt"

    add_footer_table asflicense "@@BASE@@/patch-asflicense-problems.txt"
    return 1
  fi
  add_vote_table 1 asflicense "${BUILDMODEMSG} does not generate ASF License warnings."
  return 0
}

function asflicense_writexsl
{
cat > "${1}" << EOF
<?xml version='1.0' ?>
<!--
 Licensed to the Apache Software Foundation (ASF) under one   *
 or more contributor license agreements.  See the NOTICE file *
 distributed with this work for additional information        *
 regarding copyright ownership.  The ASF licenses this file   *
 to you under the Apache License, Version 2.0 (the            *
 "License"); you may not use this file except in compliance   *
 with the License.  You may obtain a copy of the License at   *
                                                              *
   http://www.apache.org/licenses/LICENSE-2.0                 *
                                                              *
 Unless required by applicable law or agreed to in writing,   *
 software distributed under the License is distributed on an  *
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY       *
 KIND, either express or implied.  See the License for the    *
 specific language governing permissions and limitations      *
 under the License.                                           *
-->
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method='text'/>
<xsl:template match='/'>
  Files with Apache License headers will be marked AL
  Binary files (which do not require any license headers) will be marked B
  Compressed archives will be marked A
  Notices, licenses etc. will be marked N

 <xsl:for-each select='descendant::resource'>
  <xsl:choose>
     <xsl:when test='license-approval/@name="false"'>!</xsl:when>
     <xsl:otherwise><xsl:text> </xsl:text></xsl:otherwise>
 </xsl:choose>
 <xsl:choose>
     <xsl:when test='type/@name="notice"'>N    </xsl:when>
     <xsl:when test='type/@name="archive"'>A    </xsl:when>
     <xsl:when test='type/@name="binary"'>B    </xsl:when>
     <xsl:when test='type/@name="standard"'><xsl:value-of select='header-type/@name'/></xsl:when>
     <xsl:otherwise>!!!!!</xsl:otherwise>
 </xsl:choose>
 <xsl:text> </xsl:text>
 <xsl:value-of select='@name'/>
 <xsl:text>
 </xsl:text>
 </xsl:for-each>
</xsl:template>
</xsl:stylesheet>
EOF
}
