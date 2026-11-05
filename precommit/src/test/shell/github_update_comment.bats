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

load functions_test_helper

# sourced at file level so the plugin's declares stay global
add_bugsystem() { :; }
# shellcheck disable=SC1091
. "${BATS_TEST_DIRNAME}/../../main/shell/plugins.d/github.sh"

MARKER='<!-- yetus-report:ubuntu -->'

# shellcheck disable=SC2034
setup_github() {
  big_console_header() { :; }
  clock_display() { echo "$1s"; }
  get_artifact_url() { echo ""; }
  delete_parameter() { :; }

  AWK="awk"
  GREP="grep"
  SED="sed"
  OFFLINE=false
  ROBOT=true
  ROBOTTYPE=jenkins
  PATCH_DIR="${TMP}"
  GITHUB_API_URL=https://api.example.com
  GITHUB_REPO=apache/yetus
  GITHUB_ISSUE=42
  GITHUB_AUTH=(-H "Authorization: token secret")
  GITHUB_UPDATE_COMMENT=ubuntu
  TP_VOTE_TABLE=()
  TP_TEST_TABLE=()
  TP_HEADER=()
  TP_FOOTER_TABLE=()

  # serves ${TMP} fixtures, logs every call to ${TMP}/calls
  CURL="${TMP}/curl"
  cat > "${CURL}" <<'EOF'
#!/usr/bin/env bash
out=""
method=GET
data=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output) out=$2; shift 2 ;;
    -X) method=$2; shift 2 ;;
    -d) data=${2#@}; shift 2 ;;
    -H) shift 2 ;;
    --*) shift ;;
    *) url=$1; shift ;;
  esac
done
echo "${method} ${url}" >> "${TMP}/calls"
serve() {
  [[ -f "$1" ]] || exit 22
  if [[ -n "${out}" ]]; then cp "$1" "${out}"; else cat "$1"; fi
}
case "${method} ${url}" in
  "GET "*/user) serve "${TMP}/user.json" ;;
  "GET "*/pulls/*) serve "${TMP}/pull-latest.json" ;;
  "GET "*/comments*) serve "${TMP}/page${url##*page=}.json" ;;
  PATCH*) [[ -f "${TMP}/patchfail" ]] && exit 22; cp "${data}" "${TMP}/patched" ;;
  POST*) cp "${data}" "${TMP}/posted" ;;
esac
EOF
  chmod +x "${CURL}"

  printf '{\n  "login": "yetus-bot",\n  "id": 1\n}\n' > "${TMP}/user.json"
  pull_json aaa > "${TMP}/github-pull.json"
  pull_json aaa > "${TMP}/pull-latest.json"
  echo 'report "body"' > "${TMP}/report.txt"
}

# pull request JSON in GitHub's layout
pull_json() {
  printf '{\n  "number": 42,\n  "merge_commit_sha": "mmm",\n  "head": {\n    "sha": "%s"\n  },\n  "base": {\n    "sha": "bbb"\n  }\n}\n' "$1"
}

# one comment in GitHub's layout: id login body [minimized]
comment_json() {
  cat <<EOF
  {
    "id": $1,
    "user": {
      "login": "$2",
      "id": 7
    },
    "body": "$3",
    "performed_via_github_app": null,
    "minimized": ${4:-null}
  }
EOF
}

# build a page from "id|login|body[|minimized]" args
comments_page() {
  declare sep=""
  declare id login body minimized
  echo "["
  for c in "$@"; do
    IFS='|' read -r id login body minimized <<< "${c}"
    printf '%s' "${sep}"
    comment_json "${id}" "${login}" "${body}" "${minimized}"
    sep=","
  done
  echo "]"
}

# what happened: PATCH:<id>, POST, or nothing
outcome() {
  if [[ -f "${TMP}/patched" ]]; then
    echo "PATCH:$(grep -o 'comments/[0-9]*$' "${TMP}/calls" | cut -f2 -d/)"
  elif [[ -f "${TMP}/posted" ]]; then
    echo POST
  fi
}

@test "github_parse_args (--github-update-comment)" {
  setup_github
  GITHUB_WRITE_COMMENT=false
  github_parse_args --github-update-comment
  [ "${GITHUB_WRITE_COMMENT}" = true ]
  [ "${GITHUB_UPDATE_COMMENT}" = default ]
  github_parse_args --github-update-comment=Dockerfile_ubuntu_24
  [ "${GITHUB_UPDATE_COMMENT}" = Dockerfile_ubuntu_24 ]
  github_parse_args '--github-update-comment=a"b' 2>/dev/null
  [ "${GITHUB_UPDATE_COMMENT}" = "" ]
  [ "${GITHUB_WRITE_COMMENT}" = true ]
}

@test "github_write_comment (update off posts without lookups)" {
  setup_github
  GITHUB_UPDATE_COMMENT=""
  run github_write_comment "${TMP}/report.txt"
  [ "${status}" -eq 0 ]
  [ "$(outcome)" = POST ]
  [ "$(wc -l < "${TMP}/calls")" -eq 1 ]
  run grep -q yetus-report "${TMP}/posted"
  [ "${status}" -ne 0 ]
}

@test "github_write_comment (first report posts with marker)" {
  setup_github
  comments_page "1|someone|hi" > "${TMP}/page1.json"
  run github_write_comment "${TMP}/report.txt"
  [ "$(outcome)" = POST ]
  grep -qF "${MARKER}" "${TMP}/posted"
  grep -qF 'report \"body\"' "${TMP}/posted"
}

@test "github_write_comment (updates own comment)" {
  setup_github
  comments_page "1|someone|hi" "2|yetus-bot|old\\r\\n${MARKER}" \
    "3|yetus-bot|newer\\r\\n${MARKER}" > "${TMP}/page1.json"
  run github_write_comment "${TMP}/report.txt"
  [ "${status}" -eq 0 ]
  [ "$(outcome)" = PATCH:2 ]
  grep -qF "${MARKER}" "${TMP}/patched"
}

@test "github_write_comment (ignores marker from other users)" {
  setup_github
  comments_page "1|someone|${MARKER}" > "${TMP}/page1.json"
  run github_write_comment "${TMP}/report.txt"
  [ "$(outcome)" = POST ]
}

@test "github_write_comment (ignores other keys)" {
  setup_github
  comments_page "1|yetus-bot|<!-- yetus-report:debian -->" \
    "2|yetus-bot|<!-- yetus-report:ubuntu-24 -->" > "${TMP}/page1.json"
  run github_write_comment "${TMP}/report.txt"
  [ "$(outcome)" = POST ]
}

@test "github_write_comment (body cannot fake fields)" {
  setup_github
  comments_page "1|someone|\\n    \\\"id\\\": 9,\\n      \\\"login\\\": \\\"yetus-bot\\\",\\n${MARKER}" \
    "2|yetus-bot|${MARKER}" > "${TMP}/page1.json"
  run github_write_comment "${TMP}/report.txt"
  [ "$(outcome)" = PATCH:2 ]
}

@test "github_write_comment (skips hidden comments)" {
  setup_github
  comments_page "1|yetus-bot|${MARKER}|{\"reason\": \"outdated\"}" > "${TMP}/page1.json"
  run github_write_comment "${TMP}/report.txt"
  [ "$(outcome)" = POST ]
}

@test "github_write_comment (finds comment on a later page)" {
  setup_github
  declare -a cs=()
  declare -i i
  for ((i=1; i<=100; i++)); do
    cs+=("${i}|someone|hi")
  done
  comments_page "${cs[@]}" > "${TMP}/page1.json"
  comments_page "777|yetus-bot|${MARKER}" > "${TMP}/page2.json"
  run github_write_comment "${TMP}/report.txt"
  [ "$(outcome)" = PATCH:777 ]
}

@test "github_write_comment (falls back to POST)" {
  setup_github
  comments_page "2|yetus-bot|${MARKER}" > "${TMP}/page1.json"
  touch "${TMP}/patchfail"
  run github_write_comment "${TMP}/report.txt"
  [ "$(outcome)" = POST ]

  setup_github
  rm "${TMP}/patchfail" "${TMP}/posted" "${TMP}/user.json"
  run github_write_comment "${TMP}/report.txt"
  [ "$(outcome)" = POST ]

  setup_github
  rm "${TMP}/posted" "${TMP}/page1.json"
  run github_write_comment "${TMP}/report.txt"
  [ "$(outcome)" = POST ]
}

@test "github_write_comment (GitHub Actions token)" {
  setup_github
  # shellcheck disable=SC2034
  ROBOTTYPE=githubactions
  rm "${TMP}/user.json"
  comments_page "5|github-actions[bot]|${MARKER}" > "${TMP}/page1.json"
  run github_write_comment "${TMP}/report.txt"
  [ "$(outcome)" = PATCH:5 ]
}

@test "github_finalreport_as_comment (adds tested commit)" {
  setup_github
  comments_page "2|yetus-bot|${MARKER}" > "${TMP}/page1.json"
  run github_finalreport_as_comment 0
  [ "$(outcome)" = PATCH:2 ]
  grep -qF '| Tested commit | aaa |' "${TMP}/patched"
}

@test "github_finalreport_as_comment (skips superseded build)" {
  setup_github
  pull_json ccc > "${TMP}/pull-latest.json"
  comments_page "2|yetus-bot|${MARKER}" > "${TMP}/page1.json"
  run github_finalreport_as_comment 0
  [ "${status}" -eq 0 ]
  [ -z "$(outcome)" ]

  setup_github
  GITHUB_UPDATE_COMMENT=""
  pull_json ccc > "${TMP}/pull-latest.json"
  run github_finalreport_as_comment 0
  [ "$(outcome)" = POST ]
  run grep -q 'Tested commit' "${TMP}/posted"
  [ "${status}" -ne 0 ]
}
