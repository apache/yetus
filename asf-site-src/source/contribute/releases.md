<!---
  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.
-->

# Managing a Release

The Apache Yetus community encourages all committers to help on driving releases. To that end, this section seeks to outline the tools and process you'll use when managing a release. Note that these are our community norms; they do not supercede foundation policy should the two disagree.

## Dependencies

First, let's review what you'll need to complete all steps of the process.

### Committer Access
While the Yetus project aims to get new contributors involved in as much of the project as possible, ASF policy requires that all [Release Managers be committers on the project](http://www.apache.org/foundation/glossary.html#ReleaseManager). As a practical matter, [release candidates are staged in a project-specific svn repository that only project commiters have write access to](https://www.apache.org/dev/release.html#stage).
### Hardware You Own and Physically Control
ASF release policy requires that release manager verification and signing of artifacts take place on hardware you have as much control over as possible. This is because your private signing keys will be involved and those _should_ only be accessible on such hardware, to minimize the exposure to third parties. For more details, [see the ASF release policy's relevant text](https://www.apache.org/dev/release.html#owned-controlled-hardware).
### Cryptographic Signing Tools and Keys
Everything distributed by an ASF project must be signed prior to distribution (ref ASF release policy [on releases](https://www.apache.org/dev/release.html#what-must-every-release-contain) and [supplemental artifacts](https://www.apache.org/dev/release.html#distribute-other-artifacts)). The short version of the rationale is that downstream users should be able to verify that the artifacts they make use of were ones blessed by the project PMC. For a longer explanation, [see the ASF release signing document's motivation section](https://www.apache.org/dev/release-signing.html#motivation).

In practice, the requirement for artifact signing is handled via OpenPGP signatures. For all practical purposes, this means you'll need to use Gnu Privacy Guard (aka GnuPG or GPG). It also means you'll need to have a public/private key pair you control that is published in your name. Thankfully, the ASF provides a good overview to using GPG in [the ASF OpenPGP guide](https://www.apache.org/dev/openpgp.html). In particular, if you don't already have a published key be sure to follow the instructions in the section [How To Generate A Strong Key](https://www.apache.org/dev/openpgp.html#generate-key).

### Version Control System Tools
In addition to the git tools you normally use to interact with the Yetus project, managing a release also requires a properly configured Subversion installation. This is because both the staging area for release candidates and the final distribution mechanism for PMC approved releases rely on Subversion.

The Subversion project provides a nice set of pointers to installing on various OSes, in most cases via package managers, on their page [Apache Subversion Binary Packages](http://subversion.apache.org/packages.html). Alternatively, you could start with a source release and manually build the necessary tools by starting at [Apache Subversion - Download Source Code](http://subversion.apache.org/download.cgi).
### Project Specific Build Tools
To create our convenience binary artifact, you'll need to build both our project docs and all of individual components. If you normally only work on one part of the project, say Yetus Precommit, this might require some additional programming languages and tools.

- Yetus Audience Annotations will require Maven 3.2.0+ and Java 7.
- Yetus Precommit will require Python 2.6+ for generating documentation on its API via Yetus Shelldocs.
- The project documentation will require Ruby 2.x+ for rendering.
- We'll build release notes with Yetus Release Doc Maker, which will require Python 2.6+.
- Assembling release artifacts will make use of bash, tar, gzip, and md5sum.

## Setup

When you first start managing a given release you'll have to take care of the following tasks. With the exception of creating the release staging branch, these can be done in any order.

### Ensure Your Public Key is in KEYS
Like many ASF projects, we provide a single file that downstream folks can use to verify our release artifacts. It's located in the project's distribution area: http://www.apache.org/dist/yetus/KEYS. You can read about this file in the ASF guide to release signing's section [The KEYS File](http://www.apache.org/dist/yetus/KEYS). If your public key is not already included in this file, you will need to add it. You can either follow the instructions in the previously mentioned guide or those at the top of the actual KEYS file. In any case, you will need to use Subversion to update the KEYS file in the project's distribution area. Note that this area is writable only by the project PMC. If you are not yet on the PMC, your last step should be providing a patch rather than commiting.

Example commands:

```
$ svn co https://dist.apache.org/repos/dist/release/yetus yetus-dist-release
$ cd yetus-dist-release
$ (gpg --list-sigs <your key name> && gpg --armor --export <your key name>) >> KEYS
$ svn diff
$ svn commit -m "Added myself to KEYS."
```

### Work in JIRA
Like the rest of our project activity, we'll use an issue in JIRA to track managing the release. You should create this issue and assign it to yourself. As you make your way through the process of creating and running votes on release candidates, this issue will give you a centralized place to collect pointers to your work.

1. Browse to the ASF JIRA instance's "create issue" page: https://issues.apache.org/jira/secure/CreateIssue!default.jspa
1. Select "Yetus" for the Project and "Task" for the issue type. Click "Next"
1. On the next screen, use a subject line like "Release VERSION", with an appropriate version number. Fill in the following fields and click "Create".
  - Component should be "website and documentation"
  - Affects Version and Fix Version should both be the version you are releasing
  - Assignee should be you
  - Add a description similar to "Generate release candidates as needed to create a VERSION release." with an appropriate version number.

Next, create a shortened link to the JIRA version's release notes. This should use the ASF link shortener, http://s.apache.org/. To find the appropriate release notes page:

1. Browse to the Yetus JIRA versions page: https://issues.apache.org/jira/browse/YETUS/?selectedTab=com.atlassian.jira.jira-projects-plugin:versions-panel
1. Click on the Name of the release you are managing
1. Click on the "Release Notes" button. If it isn't shown, click on the "Summary" button in the left menu
1. Copy this URL
1. Browse to the ASF URL shortener: http://s.apache.org/
1. Paste the URL into the "URI" field
1. Set the optional key field to 'yetus-_version_-jira'

For example, on the 0.2.0 release you would use 'https://issues.apache.org/jira/secure/ReleaseNote.jspa?projectId=12318920&version=12334330' for the URI field and 'yetus-0.2.0-jira' for the key.

Finally, you should create a JIRA version to correspond to the release _following_ the one you are managing. This is so that folks can continue to work on things that won't make it into the in-progress release while we evaluate candidates.

1. Browse to the ASF JIRA project management page for versions: https://issues.apache.org/jira/plugins/servlet/project-config/YETUS/versions
1. Fill in a version one minor version up from the release you're managing. E.g. when managing the 0.2.0 release, fill in 0.3.0.
1. Set a start date of today.
1. Click "Add"

### Work in Git

Once you have a issue to track things, you can create the git branch for staging our release. This seperate branch will allow you to polish the release while regular work continues on the master branch. You will need to update master for the next SNAPSHOT version and the branch for the release.

Example commands, presuming the release under management is **0.2.0** and the JIRA issue is **YETUS-XXX**:

```
$ # Ensure master is up to date
$ git fetch origin
$ git status
# On branch master
# Your branch is behind 'origin/master' by 6 commits, and can be fast-forwarded.
#
nothing to commit (working directory clean)
$ git rebase origin/master
First, rewinding head to replay your work on top of it...
Fast-forwarded master to origin/master.
$ git status
# On branch master
nothing to commit (working directory clean)
$ # create branch and push without changes
$ git checkout -b YETUS-XXX
Switched to a new branch 'YETUS-XXX'
$ git push origin YETUS-XXX
$ # find files we need to update for release
$ grep -rl "0.2.0-SNAPSHOT" * 2>/dev/null
VERSION
audience-annotations-component/audience-annotations/pom.xml
audience-annotations-component/audience-annotations-jdiff/pom.xml
audience-annotations-component/pom.xml
yetus-project/pom.xml
```

At this point you should edit the aforementioned files so they have the version we expect upon a successful release. Search for instances of *VERSION-SNAPSHOT* and replace with *VERSION*; e.g. *0.2.0-SNAPSHOT* should become *0.2.0*. After you are done, create a branch-specific patch and then prepare to update the master branch.

```
$ git add -p
$ git commit -m "YETUS-XXX. Stage version 0.2.0."
$ git format-patch --stdout origin/YETUS-XXX > path/to/patches/YETUS-XXX-YETUS-XXX.1.patch
$ git checkout master
$ grep -rl "0.2.0-SNAPSHOT" * 2>/dev/null
VERSION
audience-annotations-component/audience-annotations/pom.xml
audience-annotations-component/audience-annotations-jdiff/pom.xml
audience-annotations-component/pom.xml
yetus-project/pom.xml
```

Now update these files, but this time you should update them for the next minor version's SNAPSHOT. e.g. *0.2.0-SNAPSHOT* should become *0.3.0-SNAPSHOT*. After you are done, create a patch.

```
$ git add -p
$ git commit -m "YETUS-XXX. bump master version to 0.3.0-SNAPSHOT"
$ git format-patch --stdout origin/master > path/to/patches/YETUS-XXX.1.patch
```

Both of these patch files should be uploaded to your release issue for review. Once the patches get approval push them to the repository.

## Release Candidate(s)

Depending on how candidate evaluation goes, you may end up performing these steps multiple times. Before you start, you'll need to decide when you want each candidate's vote thread to end. ASF policy requires a minimum voting period of 72 hours (ref [ASF Voting Policy](https://www.apache.org/foundation/voting.html)), so you should ensure enough padding to complete the candidate generation process in time. Ideally, you would plan to post the vote thread on a Friday morning (US time) with a closing date on Monday morning (US time).

1. Update JIRA version release date. Browse to the JIRA project version management page (https://issues.apache.org/jira/plugins/servlet/project-config/YETUS/versions) and set the release date to when you expect your next vote thread to close. This date will be used by our generated release notes.
1. Build release artifacts. You should use our convenience script to create the tarballs and markdown documents for a release. Run the following from the release staging branch and inspect the results:

        $ ./build.sh --release
        $ ls -lah target/RELEASENOTES.md target/CHANGES.md target/*.tar.gz
1. Check out the staging area for release candidates and make a directory for this candidate, somewhere outside of the your working directory. Copy the artifacts from the previous step into place. For example, when working on RC1 for the 0.2.0 release

        $ svn co https://dist.apache.org/repos/dist/dev/yetus/ yetus-dist-dev
        $ cd yetus-dist-dev
        $ mkdir 0.2.0-RC1
        $ cd 0.2.0-RC1
        $ cp path/to/yetus/target/RELEASENOTES.md path/to/yetus/target/CHANGES.md path/to/yetus/target/*.tar.gz .
1. While still in the staging area, sign the artifacts and create the needed checksum files:

        $ for artifact in *; do
            echo ${artifact}
            gpg --use-agent --armor --output "${artifact}".asc --detach-sig "${artifact}"
            gpg --print-mds "${artifact}" >"${artifact}".mds
            md5 "${artifact}" >"${artifact}".md5
          done
1. Push the release candidate to staging distribution. This will make the artifacts visible for the vote.

        $ cd ..
        $ svn add 0.2.0-RC1
        $ svn commit -m "stage Apache Yetus 0.2.0-RC1"
Afterwards, the artifacts should be visible via the web under the same URL used when checking out. In the case of 0.2.0-RC1: https://dist.apache.org/repos/dist/dev/yetus/0.2.0-RC1/
1. Call a vote on the release candidate. At this point you have everything you need to call a vote. Your vote thread must contain "[VOTE]" in the subject line, a link to the candidate staging area you created, a source repository commit hash, and voting rules. It should also contain hashes for the artifacts. Here is an example draft for 0.2.0-RC1, update it as appropriate for your release:

        Subject: [VOTE] Apache Yetus 0.2.0-RC1

        Artifacts are available:

        https://dist.apache.org/repos/dist/dev/yetus/0.2.0-RC1/

        As of this vote the relevant md5 hashes are:
        MD5 (CHANGES.md) = b7f7894d686a59aad1a4afe2ae8fbb94
        MD5 (RELEASENOTES.md) = e321ef2909e3e51ce40bbf701159b01e
        MD5 (yetus-0.2.0-bin.tar.gz) = e23fe4d34611a4c027df3f515cb46d7e
        MD5 (yetus-0.2.0-src.tar.gz) = e57b96533092356f3d5b9b4f47654fe9

        Source repository commit: 1e8f4588906a51317207092bd97b35687f2e3fa3

        Our KEYS file is at: https://dist.apache.org/repos/dist/release/yetus/KEYS
        All artifacts are signed with my key (DEADBEEF)

        JIRA version: http://s.apache.org/yetus-0.2.0-jira

        Please take a few minutes to verify the release[1] and vote on releasing it:

        [ ] +1 Release this package as Apache Yetus 0.2.0
        [ ] +0 no opinion
        [ ] -1 Do not release this package because...

        Vote will be subject to Majority Approval[2] and will close at 8:00PM
        UTC on Monday, Xxx XXth, 2016[3].

        [1]: http://www.apache.org/info/verification.html
        [2]: https://www.apache.org/foundation/glossary.html#MajorityApproval
        [3]: to find this in your local timezone see:
        http://s.apache.org/yetus-0.2.0-rc1-close
That final short link should point to some online timezone conversion utility. ASF votes often use timeanddate.com's Event Time Announcer: http://www.timeanddate.com/worldclock/fixedform.html.

1. Close the vote after the deadline. Once the deadline in the vote thread passes, tally the vote and post a suitable response that changes the subject line to start with "[RESULT]". If the vote failed, ensure there are issues in JIRA for any problems brought up. When they are closed, repeat the steps for creating a release candidate. If the vote passed, proceed to the [Cleanup section](#cleanup)

## Verification

You are free to make whatever checks of our release candidate artifacts suit your use, but before voting there are certain checks you must perform according to ASF policy. This section will walk you through the required checks and give some guidelines on additional checks you may find useful. Besides the fact that downloading the release artifacts must happen first, generally you can perform these in any order that suites you.

### Download release artifacts

You will need to download the release candidate files, include the artifacts and accompanying signatures and checksum files. The directory containing them should be in the [VOTE] thread. You can use wget or a similar tool to recursively grab all the files rather than download them one at a time. If you are not familiar with wget, it will create a nested set of directories based on the structure of the hosting site for release candidates.

For example, if we use the url from our exemplar VOTE email, the process would look like this:

    $ wget --recursive --no-parent --quiet 'https://dist.apache.org/repos/dist/dev/yetus/0.2.0-RC1/'
    $ find dist.apache.org/ -type f
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/CHANGES.md
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/CHANGES.md.asc
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/CHANGES.md.md5
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/CHANGES.md.mds
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/index.html
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/RELEASENOTES.md
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/RELEASENOTES.md.asc
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/RELEASENOTES.md.md5
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/RELEASENOTES.md.mds
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/yetus-0.2.0-bin.tar.gz
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/yetus-0.2.0-bin.tar.gz.asc
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/yetus-0.2.0-bin.tar.gz.md5
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/yetus-0.2.0-bin.tar.gz.mds
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/yetus-0.2.0-src.tar.gz
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/yetus-0.2.0-src.tar.gz.asc
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/yetus-0.2.0-src.tar.gz.md5
    dist.apache.org//repos/dist/dev/yetus/0.2.0-RC1/yetus-0.2.0-src.tar.gz.mds
    dist.apache.org//robots.txt

Lastly, if you haven't verified a release before you'll need to download and import the public keys for the project's release managers. This is the KEYS file that should have been mentioned in the [VOTE] thread. The specific output of the follow commands will vary depending on how many release mangers there have been and which keys, if any, you have previously imported.

    $ curl --output KEYS.yetus --silent 'https://www.apache.org/dist/yetus/KEYS'
    $ gpg --import KEYS.yetus
    gpg: key 0D80DB7C: "Sean Busbey (CODE SIGNING KEY) <busbey@apache.org>" not changed
    gpg: Total number processed: 1
    gpg:              unchanged: 1

### ASF required checks

ASF policies require that binding votes on releases be cast only after verifying proper licensing and provenance. For specific details, you should read the [ASF Release Policy's section entitled What Must Every ASF Release Contain?](http://www.apache.org/dev/release.html#what-must-every-release-contain) as well as the informational page [What We Sign](http://www.apache.org/info/verification.html). The following is a non-normative set of guidelines.

1. You MUST make sure each of the signatures match. For example, using gpg and taking a fictional source artifact:

        $ cd dist.apache.org/repos/dist/dev/yetus/0.2.0-RC1/
        $ gpg --verify yetus-0.2.0-src.tar.gz.asc yetus-0.2.0-src.tar.gz
        gpg: Signature made Fri Dec 11 11:50:56 2015 CST using RSA key ID 0D80DB7C
        gpg: Good signature from "Sean Busbey (CODE SIGNING KEY) <busbey@apache.org>"
As noted in the informational page [What We Sign](http://www.apache.org/info/verification.html), if you don't have the signer's key in your web of trust the output of the verify command will point this out. You should refer to it for guidance.

1. You MUST make sure the provided hashes match the provided artifact.

        $ gpg --print-mds yetus-0.2.0-src.tar.gz >yetus-0.2.0-src.tar.gz.my_mds
        $ diff yetus-0.2.0-src.tar.gz.mds yetus-0.2.0-src.tar.gz.my_mds
        $ md5 yetus-0.2.0-src.tar.gz >yetus-0.2.0-src.tar.gz.my_md5
        $ diff yetus-0.2.0-src.tar.gz.md5 yetus-0.2.0-src.tar.gz.my_md5
1. You MUST make sure artifacts abide by the ASF Licensing Policy. You should read through [the ASF Licensing Policy](https://www.apache.org/legal/resolved), especially if your vote will be binding. As a quick guide:
    * our software must be under the Apache Software License version 2.0 and this must be noted with a proper LICENSE and NOTICE file in each artifact that can hold them.
    * our source code must meet the ASF policy on proper license notifications. Read the ASF Legal Committee's [Source Header Licensing Guide](http://apache.org/legal/src-headers.html)
    * our LICENSE and NOTICE files must properly propogate licensing information for bundled products. The [Foundation's Licensing HOWTO Guide](http://www.apache.org/dev/licensing-howto.html) provides guidance on how these files should be maintained.
    * our software must only bundle compatibly licensed products; read [the Licensing Policy's Category A list for compatible licenses](https://www.apache.org/legal/resolved#category-a).
    * our software may only have a run time dependency on a product with a prohibit license if its use is optional; read [the Licensing Policy's Category X list for prohibited licenses](https://www.apache.org/legal/resolved#category-x) and [the Licensing Policy's explanation of optional runtime dependencies](https://www.apache.org/legal/resolved#optional).
1. You SHOULD make sure the source release artifact corresponds to the referenced commit hash in the [VOTE] thread. (This ASF policy is currently in DRAFT status.) Our eventual release tag is how we'll provide long term provinence information for our downstream users. Since the release's source code artifact will be the canonical represenation of the release we vote on, it's important that it match the contents of the version control system's tag. Given our example above, you can check this with recursive diff.

        $ mkdir yetus-0.2.0-src_unpack
        $ tar -C yetus-0.2.0-src_unpack -xzf yetus-0.2.0-src.tar.gz
        $ git clone --single-branch --depth=1 --branch 0.2.0-RC1 'https://git1-us-west.apache.org/repos/asf/yetus.git' yetus-0.2.0-RC1-tag
        $ diff -r yetus-0.2.0-RC1-tag yetus-0.2.0-src_unpack/yetus-0.2.0
        $ echo $?
        0
1. You MUST make sure any non-source artifacts can be derived from the source artifact. Since the source artifact is the canonical representation of our release, any other artifacts we distribute must be just for the convenience of our downstream users. As such, one must be able to derive them from the source artifact. Currently, you can generate all of the artifacts we distribute for convenience using the same build helper script used to create the release artifacts.

        $ mkdir yetus-0.2.0-src_unpack
        $ tar -C yetus-0.2.0-src_unpack -xzf yetus-0.2.0-src.tar.gz
        $ cd yetus-0.2.0-src_unpack/yetus-0.2.0
        $ ./build.sh
This will create a target/ directory that contains the tarball binary distribution. That tarball will also include e.g. the java jars we'll push to maven for our Audience Annotations project.

### Community recommended checks

If you've gone through all of the ASF required checks, you'll already have made use of both the shelldocs and releaddocmaker components and confirmed that the compilable components successfully compile.

1. Test Precommit. The smart-apply-patch and test-patch scripts don't get flexed as a part of the above candidate verification. If you have a downstream project you regularly use, it should suffice to attempt local verification of a contribution. If that project happens to be an ASF project with an example personality, this should be as simple as finding an issue in patch-available status.

        $ cd path/to/my/repo/for/hbase
        $ /some/path/to/the/unpacked/candidate/bin/test-patch --project=hbase HBASE-1772
        ...SNIP...
        -1 overall

        | Vote |       Subsystem |  Runtime   | Comment
        ============================================================================
        |   0  |         reexec  |  0m 0s     | Docker mode activated.
        |  +1  |      hbaseanti  |  0m 0s     | Patch does not have any anti-patterns.
        |  +1  |        @author  |  0m 0s     | The patch does not contain any @author
        |      |                 |            | tags.
        |  +1  |     test4tests  |  0m 0s     | The patch appears to include 2 new or
        |      |                 |            | modified test files.
        |  +1  |     mvninstall  |  4m 41s    | master passed
        |  +1  |        compile  |  1m 4s     | master passed with JDK v1.8.0_72
        |  +1  |        compile  |  0m 57s    | master passed with JDK v1.7.0_95
        |  +1  |     checkstyle  |  0m 36s    | master passed
        |  +1  |     mvneclipse  |  0m 35s    | master passed
        |  -1  |       findbugs  |  1m 6s     | hbase-client in master has 19 extant
        |      |                 |            | Findbugs warnings.
        |  -1  |       findbugs  |  2m 8s     | hbase-server in master has 84 extant
        |      |                 |            | Findbugs warnings.
        |  -1  |        javadoc  |  0m 23s    | hbase-client in master failed with JDK
        |      |                 |            | v1.8.0_72.
        |  -1  |        javadoc  |  0m 34s    | hbase-server in master failed with JDK
        |      |                 |            | v1.8.0_72.
        |  +1  |        javadoc  |  0m 57s    | master passed with JDK v1.7.0_95
        |  +1  |     mvninstall  |  1m 3s     | the patch passed
        |  +1  |        compile  |  0m 59s    | the patch passed with JDK v1.8.0_72
        |  +1  |          javac  |  0m 59s    | the patch passed
        |  +1  |        compile  |  0m 59s    | the patch passed with JDK v1.7.0_95
        |  +1  |          javac  |  0m 59s    | the patch passed
        |  +1  |     checkstyle  |  0m 32s    | the patch passed
        |  +1  |     mvneclipse  |  0m 28s    | the patch passed
        |  +1  |     whitespace  |  0m 0s     | Patch has no whitespace issues.
        |  +1  |    hadoopcheck  |  4m 28s    | Patch does not cause any errors with
        |      |                 |            | Hadoop 2.4.1 2.5.2 2.6.0.
        |  +1  |       findbugs  |  3m 37s    | the patch passed
        |  -1  |        javadoc  |  0m 24s    | hbase-client in the patch failed with
        |      |                 |            | JDK v1.8.0_72.
        |  -1  |        javadoc  |  0m 36s    | hbase-server in the patch failed with
        |      |                 |            | JDK v1.8.0_72.
        |  +1  |        javadoc  |  1m 2s     | the patch passed with JDK v1.7.0_95
        |  +1  |           unit  |  1m 23s    | hbase-client in the patch passed with
        |      |                 |            | JDK v1.8.0_72.
        |  -1  |           unit  |  67m 12s   | hbase-server in the patch failed with
        |      |                 |            | JDK v1.8.0_72.
        |  +1  |           unit  |  1m 28s    | hbase-client in the patch passed with
        |      |                 |            | JDK v1.7.0_95.
        |  -1  |           unit  |  66m 16s   | hbase-server in the patch failed with
        |      |                 |            | JDK v1.7.0_95.
        |  +1  |     asflicense  |  0m 30s    | Patch does not generate ASF License
        |      |                 |            | warnings.
        |      |                 |  177m 13s  |


                                    Reason | Tests
         JDK v1.8.0_72 Failed junit tests  |  hadoop.hbase.client.TestMultiParallel
         JDK v1.7.0_95 Failed junit tests  |  hadoop.hbase.client.TestMultiParallel


        || Subsystem || Report/Notes ||
        ============================================================================
        | Docker | Client=1.9.1 Server=1.9.1 Image:yetus/hbase:date2016-02-11 |
        | JIRA Patch URL | https://issues.apache.org/jira/secure/attachment/12787466/HBASE-1772.patch |
        | JIRA Issue | HBASE-15198 |
        | Optional Tests |  asflicense  javac  javadoc  unit  findbugs  hadoopcheck  hbaseanti  checkstyle  compile  |
        | uname | Linux 67e02eb9aeea 3.13.0-36-lowlatency #63-Ubuntu SMP PREEMPT Wed Sep 3 21:56:12 UTC 2014 x86_64 x86_64 x86_64 GNU/Linux |
        | Build tool | maven |
        | Personality | /testptch/patchprocess/precommit/personality/hbase.sh |
        | git revision | master / 81a6fff |
        | findbugs | v2.0.1 |
        | findbugs | /testptch/patchprocess/branch-findbugs-hbase-client-warnings.html |
        | findbugs | /testptch/patchprocess/branch-findbugs-hbase-server-warnings.html |
        | javadoc | /testptch/patchprocess/branch-javadoc-hbase-client-jdk1.8.0_72.txt |
        | javadoc | /testptch/patchprocess/branch-javadoc-hbase-server-jdk1.8.0_72.txt |
        | javadoc | /testptch/patchprocess/patch-javadoc-hbase-client-jdk1.8.0_72.txt |
        | javadoc | /testptch/patchprocess/patch-javadoc-hbase-server-jdk1.8.0_72.txt |
        | unit | /testptch/patchprocess/patch-unit-hbase-server-jdk1.8.0_72.txt |
        | unit | /testptch/patchprocess/patch-unit-hbase-server-jdk1.7.0_95.txt |
        | unit test logs |  /testptch/patchprocess/patch-unit-hbase-server-jdk1.8.0_72.txt /testptch/patchprocess/patch-unit-hbase-server-jdk1.7.0_95.txt |
        | modules | C: hbase-client hbase-server U: . |
        | Powered by | Apache Yetus 0.2.0   http://yetus.apache.org |
1. Test Audience Annotations. If you have a downstream project that relies on the audience annotations project, you should be able to install the jars locally and test with the updated verison.

        $ mkdir yetus-0.2.0-src_unpack
        $ tar -C yetus-0.2.0-src_unpack -xzf yetus-0.2.0-src.tar.gz
        $ cd yetus-0.2.0-src_unpack/yetus-0.2.0
        $ mvn --batch-mode -f yetus-project/pom.xml install
        ...SNIP...
        [INFO] ------------------------------------------------------------------------
        [INFO] BUILD SUCCESS
        [INFO] ------------------------------------------------------------------------
        [INFO] Total time: 3.539 s
        [INFO] Finished at: 2016-02-13T02:12:39-06:00
        [INFO] Final Memory: 14M/160M
        [INFO] ------------------------------------------------------------------------
        $ mvn --batch-mode -f audience-annotations-component/pom.xml install
        ...SNIP...
        [INFO] Reactor Summary:
        [INFO]
        [INFO] Apache Yetus - Audience Annotations ................ SUCCESS [  5.231 s]
        [INFO] Apache Yetus - Audience Annotations Component ...... SUCCESS [  0.037 s]
        [INFO] ------------------------------------------------------------------------
        [INFO] BUILD SUCCESS
        [INFO] ------------------------------------------------------------------------
        [INFO] Total time: 5.534 s
        [INFO] Finished at: 2016-02-13T02:13:32-06:00
        [INFO] Final Memory: 24M/230M
        [INFO] ------------------------------------------------------------------------
        $ cd path/to/your/project
        $ vim pom.xml # edit version to be e.g. 0.2.0
        $ mvn verify
        ...SNIP...
        [INFO] ------------------------------------------------------------------------
        [INFO] BUILD SUCCESS
        [INFO] ------------------------------------------------------------------------
        [INFO] Total time: 7.539 m
        [INFO] Finished at: 2016-02-13T02:13:39-06:00
        [INFO] Final Memory: 14M/160M
        [INFO] ------------------------------------------------------------------------

## Cleanup

Once a release candidate obtains majority approval from the PMC, there are several final maintenance tasks you must perform to close out the release.

1. Create short cut links to the vote thread (e.g., http://s.apache.org/yetus-0.2.0-rc1-vote) and the result (e.g., http://s.apache.org/yetus-0.2.0-vote-passes) that point to the archives on mail-archives.apache.org.  Be aware that it may take several hours for the archive to get the posts that need to be referenced.

1. Produce a signed release tag. You should create a signed tag and push it to the asf repo. The tag's message should include an asf-shortened links to the vote and results. It should be named 'rel/_version_' so that it will be immutable due to ASF infra's git configuration. Presuming we're working on the 0.2.0 release and the RC1 example above has passed:

        $ git config --global user.signingkey <your-key-id> # if you've never configured
        $ git tag --sign rel/0.2.0 1e8f4588906a51317207092bd97b35687f2e3fa3
Example commit message:

        YETUS-XXX. tag Apache Yetus 0.2.0 release.

        vote thread: http://s.apache.org/yetus-0.2.0-rc1-vote

        results: http://s.apache.org/yetus-0.2.0-vote-passes
Then push:

        $ git push origin rel/0.2.0
1. Move release artifacts to the distribution area. The release officially happens once the artifacts are pushed to the ASF distribution servers. From this server, the artifacts will automatically be copied to the long-term archive as well as the various mirrors that will be used by downstream users. These must be _exactly_ the artifacts from the RC that passed. Please note that currently only Yetus PMC members have write access to this space. If you are not yet on the PMC, please ask the PMC to post the artifacts.

        $ svn co https://dist.apache.org/repos/dist/release/yetus/ yetus-dist-release
        $ cd yetus-dist-release
        $ mkdir 0.2.0
        $ cp path/to/yetus-dist-dev/0.2.0-RC1/* 0.2.0
        $ svn add 0.2.0
        $ svn commit -m "Publish Apache Yetus 0.2.0"
It may take up to 24 hours for the artifacts to make their way to the various mirrors. You should not announce the release until after this period.
1. Add the release to the ASF reporter tool. To make our project reports for the ASF Board easier, you should include the release in the [Apache Committee Report Helper website](https://reporter.apache.org/addrelease.html?yetus). Be sure to use the date release artifacts first were pushed to the distribution area, which should be the  same release date as in JIRA. Note that this website is only available to PMC members. If you are not yet in the PMC, please ask them to add the release information.
1. Remove candidates from the staging area. Once you have moved the artifacts into the distribution area, they no longer need to be in the staging area and should be cleaned up as a courtesy to future release managers.

        $ svn co https://dist.apache.org/repos/dist/dev/yetus/ yetus-dist-dev
        $ cd yetus-dist-dev
        $ svn rm 0.2.0-RC*
        D         0.2.0-RC1/yetus-0.2.0-src.tar.gz.md5
        D         0.2.0-RC1/yetus-0.2.0-bin.tar.gz.asc
        D         0.2.0-RC1/RELEASENOTES.md
        D         0.2.0-RC1/CHANGES.md.mds
        D         0.2.0-RC1/CHANGES.md.md5
        D         0.2.0-RC1/yetus-0.2.0-src.tar.gz
        D         0.2.0-RC1/RELEASENOTES.md.asc
        D         0.2.0-RC1/yetus-0.2.0-bin.tar.gz.mds
        D         0.2.0-RC1/yetus-0.2.0-bin.tar.gz.md5
        D         0.2.0-RC1/yetus-0.2.0-src.tar.gz.asc
        D         0.2.0-RC1/CHANGES.md
        D         0.2.0-RC1/RELEASENOTES.md.mds
        D         0.2.0-RC1/CHANGES.md.asc
        D         0.2.0-RC1/RELEASENOTES.md.md5
        D         0.2.0-RC1/yetus-0.2.0-bin.tar.gz
        D         0.2.0-RC1/yetus-0.2.0-src.tar.gz.mds
        D         0.2.0-RC1
        $ svn commit -m "cleaning up release candidates from Apache 0.2.0 release process."
        Deleting       0.2.0-RC1

        Committed revision 1772.
1. Resolve release issue; it should be marked as "fixed."
1. Mark JIRA version as released. Browse to the [project version management page for the YETUS JIRA tracker](https://issues.apache.org/jira/plugins/servlet/project-config/YETUS/versions). Mouse over the version you are managing, click on the gear in the far right, and select Release.
1. Delete staging branch. Now that there is an immutable tag for the release, all commits leading up to that release will be maintained by git. Should we need a future maintenance release after this version, we can reestablish the branch based off of the release tag.

        $ git push origin :YETUS-XXX
1. You should update the documentation in the git master branch for the new release. Due to some limitations in our website rendering library, this currently involves some extra symlinks (see YETUS-192).

        $ cd asf-site-src
        $ # Add the release to the releases data file
        $ vim data/versions.yml
        $ # create symlinks for where the documentation generation will go
        $ cd source/documentation
        $ ln -s ../../../target/0.2.0/ 0.2.0
        $ ln -s ../../../target/0.2.0.html.md 0.2.0.html.md
        $ # add these symlinks to our rat exclusion file
        $ cd ../../..
        $ vim .rat-excludes
        $ # add changes to git
        $ git add -p
        $ git add asf-site-src/source/documentation/0.2.0*
        $ git commit
Example commit message:

        YETUS-XXX. add release 0.2.0.

            - list in releases
            - add symlinks for markdown 3 workaround of per-version generated docs
This should result in a fairly small diff

        $ git diff HEAD^
        diff --git a/.rat-excludes b/.rat-excludes
        index 9332463..7b5f415 100644
        --- a/.rat-excludes
        +++ b/.rat-excludes
        @@ -10,3 +10,5 @@ precommit-apidocs
         VERSION
         0.1.0
         0.1.0.html.md
        +0.2.0
        +0.2.0.html.md
        diff --git a/asf-site-src/data/versions.yml b/asf-site-src/data/versions.yml
        index ac9861c..4a4d4b5 100644
        --- a/asf-site-src/data/versions.yml
        +++ b/asf-site-src/data/versions.yml
        @@ -16,3 +16,4 @@
         # under the License.
         releases:
           - '0.1.0'
        +  - '0.2.0'
        diff --git a/asf-site-src/source/documentation/0.2.0 b/asf-site-src/source/documentation/0.2.0
        new file mode 120000
        index 0000000..158dc23
        --- /dev/null
        +++ b/asf-site-src/source/documentation/0.2.0
        @@ -0,0 +1 @@
        +../../../target/0.2.0/
        \ No newline at end of file
        diff --git a/asf-site-src/source/documentation/0.2.0.html.md b/asf-site-src/source/documentation/0.2.0.html.md
        new file mode 120000
        index 0000000..c14ca73
        --- /dev/null
        +++ b/asf-site-src/source/documentation/0.2.0.html.md
        @@ -0,0 +1 @@
        +../../../target/0.2.0.html.md
        \ No newline at end of file
You should then post this patch for review. Once you've gotten feedback, it's fine to push the patch to the ASF git repo immediately so long as the updated website is not published.
1. Publish website updates. After the 24 hour window needed for the release artifacts to make their way to the variety of mirrors, you should render the website and publish it using the instructions found in [Maintaining the Yetus Website](../website).
1. Remove old releases from distribution area. The ASF distribution area should only contain the most recent release for actively developed branches If your release is a maintenance release, delete the prior release. If your release marks the end of maintanence for an earlier minor or major release line, you should delete those versions from the distribution area.
1. Publish convenience artifacts (maven, homebrew, etc). Specifics to be documented later; see [YETUS-316](https://issues.apache.org/jira/browse/YETUS-316).
1. Draft an announcement email. The announcement email should briefly describe our project and provide links to our artifacts and documentation. For example,
        Subject: [ANNOUNCE] Apache Yetus 0.2.0 release

        Apache Yetus 0.2.0 Released!

        The Apache Software Foundation and the Apache Yetus Project are pleased to
        announce the release of version 0.2.0 of Apache Yetus.

        Apache Yetus is a collection of libraries and tools that enable contribution
        and release processes for software projects.  It provides a robust system
        for automatically checking new contributions against a variety of community
        accepted requirements, the means to document a well defined supported
        interface for downstream projects, and tooling to help release managers
        generate release documentation based on the information provided by
        community issue trackers and source repositories.


        This version marks the latest minor release representing the community's
        work over the last X months.


        To download please choose a mirror by visiting:

            https://yetus.apache.org/downloads/

        The relevant checksums files are available at:

            https://www.apache.org/dist/yetus/0.2.0/yetus-0.2.0-src.tar.gz.mds
            https://www.apache.org/dist/yetus/0.2.0/yetus-0.2.0-bin.tar.gz.mds

        Project member signature keys can be found at

           https://www.apache.org/dist/yetus/KEYS

        PGP signatures are available at:

            https://www.apache.org/dist/yetus/0.2.0/yetus-0.2.0-src.tar.gz.asc
            https://www.apache.org/dist/yetus/0.2.0/yetus-0.2.0-bin.tar.gz.asc

        The list of changes included in this release and release notes can be browsed at:

            https://yetus.apache.org/documentation/0.2.0/CHANGES/
            https://yetus.apache.org/documentation/0.2.0/RELEASENOTES/

        Documentation for this release is at:

            https://yetus.apache.org/documentation/0.2.0/

        On behalf of the Apache Yetus team, thanks to everyone who helped with this
        release!

        Questions, comments, and bug reports are always welcome on

            dev@yetus.apache.org

        --
        Meg Smith
        Apache Yetus PMC
If you'd like feedback on the draft, feel free to post it for review on your release issue.
1. Send announcement emails. After the 24 hour window needed for the release artifacts to make their way to the variety of mirrors, you should send the announcement email. The email should come from your apache.org email address and at a minimum should go to the dev@yetus.apache.org and announce@apache.org lists. For details see [the ASF Release Policy section How Should Releases Be Announced?](http://www.apache.org/dev/release.html#release-announcements). Additionally, you may want to send the announcement to the development lists of downstream projects we know are using Yetus components.
1. Send tweet. Once the message to the ASF-wide announce list has made it to the public archive, you should draft a tweet with a link to the announcement. You should use the ASF link shortener and a descriptive name. For example, the 0.2.0 release could use

        Apache Yetus 0.2.0 has been released:

        http://s.apache.org/yetus-0.2.0-announce
This tweet should come from the offical [@ApacheYetus](https://twitter.com/ApacheYetus/) account. Currently only PMC members have access to it. If you are not yet on the PMC, please ask for the PMC to post the tweet once your email is available in the archives.
