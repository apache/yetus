personality_plugins "all,-ant,-javac,-scalac,-scaladoc"

function personality_globals
{
  #shellcheck disable=SC2034
  PATCH_BRANCH_DEFAULT=develop
  #shellcheck disable=SC2034
  HOW_TO_CONTRIBUTE="https://cwiki.apache.org/confluence/display/GEODE/How+to+Contribute"
  #shellcheck disable=SC2034
  JIRA_ISSUE_RE='^(GEODE)-[0-9]+$'
  #shellcheck disable=SC2034
  GITHUB_REPO="apache/incubator-geode"
  #shellcheck disable=SC2034
  BUILDTOOL=gradle
#   PYLINT_OPTIONS="--indent-string='  '"

#   HADOOP_MODULES=""
}
