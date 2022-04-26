<!--
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
<!-- markdownlint-disable no-bare-urls -->

# Managing a Release

<!-- MarkdownTOC levels="1,2" autolink="true" bullets="-,+,*" -->

- [Dependencies](#dependencies)
- [Setup](#setup)
- [Verify Changelog and Release Notes](#verify-changelog-and-release-notes)
- [Release Candidate\(s\)](#release-candidates)
- [Verification](#verification)
- [Cleanup](#cleanup)

<!-- /MarkdownTOC -->

The Apache Yetus community encourages all committers to help on driving releases. To that end, this section seeks to outline the tools and process you'll use when managing a release. Note that these are our community norms; they do not supersede foundation policy should the two disagree.

## Dependencies

First, let's review what you'll need to complete all steps of the process.

### Committer Access

While the Yetus project aims to get new contributors involved in as much of the project as possible, ASF policy requires that all [Release Managers be committers on the project](https://www.apache.org/foundation/glossary.html#ReleaseManager). As a practical matter, [release candidates are staged in a project-specific svn repository that only project committers have write access to](https://www.apache.org/dev/release.html#stage).

### Hardware You Own and Physically Control

ASF release policy requires that release manager verification and signing of artifacts take place on hardware you have as much control over as possible. This is because your private signing keys will be involved and those _should_ only be accessible on such hardware, to minimize the exposure to third parties. For more details, [see the ASF release policy's relevant text](https://www.apache.org/dev/release.html#owned-controlled-hardware).

### Cryptographic Signing Tools and Keys

Everything distributed by an ASF project must be signed before distribution (ref ASF release policy [on releases](https://www.apache.org/dev/release.html#what-must-every-release-contain) and [supplemental artifacts](https://www.apache.org/dev/release.html#distribute-other-artifacts)). The short version of the rationale is that downstream users should be able to verify that the artifacts they make use of were ones blessed by the project PMC. For a longer explanation, [see the ASF release signing document's motivation section](https://www.apache.org/dev/release-signing.html#motivation).

In practice, the requirement for artifact signing is handled via OpenPGP signatures. For all practical purposes, this means you'll need to use Gnu Privacy Guard (aka GnuPG or GPG). It also means you'll need to have a public/private key pair you control that is published in your name. Thankfully, the ASF provides an excellent overview to using GPG in [the ASF OpenPGP guide](https://www.apache.org/dev/openpgp.html). In particular, if you don't already have a published key be sure to follow the instructions in the section [How To Generate A Strong Key](https://www.apache.org/dev/openpgp.html#generate-key).

### Version Control System Tools

In addition to the git tools you normally use to interact with the Yetus project, managing a release also requires a properly configured Apache Subversion installation. This additional tool is because both the staging area for release candidates and the final distribution mechanism for PMC approved releases rely on Subversion.

The Subversion project provides a nice set of pointers to installing on various OSes, in most cases via package managers, on their page [Apache Subversion Binary Packages](https://subversion.apache.org/packages.html). Alternatively, you could start with a source release and manually build the necessary tools by starting at [Apache Subversion - Download Source Code](https://subversion.apache.org/download.cgi).

### Project Specific Build Tools

To create our convenience binary artifact and the Apache Maven plug-ins, you'll need to build both our project docs and all of the individual components.
All of the tools will be in the Docker container that is launched by using the `./start-build-dev.sh` script. Note that you will need to have a properly
configured GnuPG and Maven settings.xml setup.

## Setup

When you first start managing a given release, you'll have to take care of the following tasks. Except for creating the release staging branch, these can be done in any order.

### Verify the Year

Before attempting to do a release, verify that the documentation, website, etc, has the current year in the copyright notices.  Given that fixing that requires a patch, this should be done in advance of other release work!

### Ensure Your Public Key is in KEYS

Like many ASF projects, we provide a single file that downstream folks can use to verify our release artifacts. It's located in the project's distribution area <https://downloads.apache.org/yetus>. You can read about this file in the [ASF guide to release signing](https://www.apache.org/dev/release-signing) section. If your public key is not already included in [the KEYS file](https://downloads.apache.org/yetus/KEYS), you will need to add it. You can either follow the instructions in the previously mentioned guide or those at the top of the actual KEYS file. In any case, you will need to use Subversion to update the KEYS file in the project's distribution area. Note that this area is writable only by the project PMC. If you are not yet on the PMC, your last step should be providing a patch rather than committing.

Example commands:

```bash
$ svn co https://dist.apache.org/repos/dist/release/yetus yetus-dist-release
$ cd yetus-dist-release
$ (gpg --list-sigs <your key name> && gpg --armor --export <your key name>) >> KEYS
$ svn diff
$ svn commit -m "Added myself to KEYS."
```

### Work in JIRA

Like the rest of our project activity, we'll use an issue in JIRA to track managing the release. You should create this issue and assign it to yourself. As you make your way through the process of creating and running votes on release candidates, this issue will give you a centralized place to collect pointers to your work.

1. Browse to the ASF JIRA instance's "create issue" page: <https://issues.apache.org/jira/secure/CreateIssue!default.jspa>
1. Select "Yetus" for the Project and "Task" for the issue type. Click "Next".
1. On the next screen, use a subject line like "Release VERSION", with an appropriate version number. Fill in the following fields and click "Create".
   - The component should be "website and documentation"
   - Affects Version and Fix Version should both be the version you are releasing
   - Assignee should be you
   - Add a description similar to "Generate release candidates as needed to create a VERSION release." with an appropriate version number.
1. Next, create a shortened link to the JIRA version's release notes. This link should use the ASF link shortener, <https://s.apache.org/>. To find the appropriate release notes page:
   - Browse to the Yetus JIRA versions page: <https://issues.apache.org/jira/browse/YETUS/?selectedTab=com.atlassian.jira.jira-projects-plugin:versions-panel>
   - Click on the Name of the release you are managing
   - Click on the "Release Notes" button. If it isn't shown, click on the "Summary" button in the left menu
   - Copy this URL
1. Browse to the ASF URL shortener: <https://s.apache.org/>
1. Paste the URL into the "URI" field
1. Set the optional key field to 'yetus-_version_-jira'
   For example, on the 0.7.0 release, you would use `https://issues.apache.org/jira/secure/ReleaseNote.jspa?projectId=12318920&version=12334330` for the URI field and 'yetus-0.7.0-jira' for the key.
1. Finally, you should create a JIRA version that matches the release _following_ the one you are managing. This action is so that folks can continue to work on things that won't make it into the in-progress release while we evaluate candidates.
    1. Browse to the ASF JIRA project management page for versions: <https://issues.apache.org/jira/plugins/servlet/project-config/YETUS/versions>
    1. Fill in a version one minor version up from the release you're managing. E.g., when managing the 0.7.0 release, fill in 0.8.0.
    1. Set a start date of today.
    1. Click "Add"

### Work in Git

Once you have an issue to track things, git branches will be needed in order to make the necessary
PRs.  A script is provided to make this easier:

- Major Release:

  ```bash
  $ release/initial-patches.sh --jira=<release JIRA> --version=<X.0.0>
  ```

- Minor release:

  ```bash
  $ release/initial-patches.sh --jira=<release JIRA>
  ```

- Micro release:

  ```bash
  $ release/initial-patches.sh --jira=<release JIRA> --startingbranch=rel/<previous micro version>
  ```

These commands will create one or two branches:

- _JIRA_-release with updated poms that match the release you are working on
- _JIRA_-main with updated poms that match the next SNAPSHOT release

Verify the automated commits to these branches are correct and create the necessary PRs.
Once Apache Yetus checks finish, merge to their respective branches. (You do not need approval.)

## Verify Changelog and Release Notes

Before starting work on the release candidate, it is generally a good idea to look over
the changelog and release notes.  These files are part of our distribution and if they
are incorrect, will require a new RC. Therefore, before cutting a new release, make sure
they do not have errors or missing information.  The easiest way to do this check is to
run through the [website](../website) directions to update the live website. After doing
that work, they should be listed [here](/downloads/releasenotes/) as the top entry.

## Release Candidate(s)

Depending on how candidate evaluation goes, you may end up performing these steps multiple times. Before you start, you'll need to decide when you want each candidate's vote thread to end. ASF policy requires a minimum voting period of 72 hours (ref [ASF Voting Policy](https://www.apache.org/foundation/voting.html)), so you should ensure enough padding to complete the candidate generation process in time. Ideally, you would plan to post the vote thread on a Friday morning (US time) with a closing date on Monday morning (US time).

1. Update JIRA version release date. Browse to the JIRA project version management page <https://issues.apache.org/jira/plugins/servlet/project-config/YETUS/versions>, mark the version as 'Release', and set the release date. Our generated release notes will use this date. Note that this will close the version and no one will be able to assign new JIRA issues to it.  However it is required for the `build-and-sign` step below.
1. Update your `${HOME}/.m2/settings.xml` file to include the Maven snapshot information as indicated on <https://www.apache.org/dev/publishing-maven-artifacts.html>
1. Build release artifacts. Run the following from the _release staging branch_ (`JIRA-release`) created by the `release/initial-patches.sh` script and run these commands:

   ```bash
   $ git checkout YETUS-XXX-release
   $ ./start-build-env.sh
   (container build and eventually a shell in your source repo)
   $ release/build-and-sign.sh --asfrelease
   $ ls -lah yetus-dist/target/artifacts/*
   ```

1. Before exiting the container, peruse the `/tmp/build-log` directory to see if any relevant errors occurred.
1. Exit the container.
1. Check out the staging area for release candidates and make a directory for this candidate, somewhere outside of your working directory. Copy the artifacts from the previous step into place. For example, when working on RC1 for the 0.7.0 release

   ```bash
   $ svn co https://dist.apache.org/repos/dist/dev/yetus/ yetus-dist-dev
   $ cd yetus-dist-dev
   $ mkdir 0.7.0-RC1
   $ cd 0.7.0-RC1
   $ cp path/to/yetus/yetus-dist/target/artifacts/* .
   ```

1. Push the release candidate to staging distribution. This will make the artifacts visible for the vote.

   ```bash
   $ cd ..
   $ svn add 0.7.0-RC1
   $ svn commit -m "stage Apache Yetus 0.7.0-RC1"
   Afterward, the artifacts should be visible via the web under the same URL used when checking out. In the case of 0.7.0-RC1: <https://dist.apache.org/repos/dist/dev/yetus/0.7.0-RC1/>
   ```

1. Examine staged maven build. Go to the [ASF repository](https://repository.apache.org/) and log in with your asf LDAP credentials. Look for the staging repository with a name that includes "yetus". Clicking on it will give you a link to an "Open" repository. You can examine the structure in the Nexus API while you're logged in. If it looks essentially correct, "Close" the repository. Refreshing and clicking on the repository will give you a link in the Summary tab that other folks can use to interact with the repository.
1. Create a short link that should point to some online timezone conversion utility that will point to when the vote will end. ASF votes often use timeanddate.com's Event Time Announcer: <https://www.timeanddate.com/worldclock/fixedform.html>.
1. Call a vote on the release candidate. At this point, you have everything you need to call a vote. Your vote thread must contain "[VOTE]" in the subject line, a link to the candidate staging area you created, a source repository commit hash, and voting rules. It should also contain hashes for the artifacts. Here is an example draft for 0.7.0-RC1, update it as appropriate for your release:

        Subject: [VOTE] Apache Yetus 0.7.0-RC1

        Artifacts are available:

        https://dist.apache.org/repos/dist/dev/yetus/0.7.0-RC1/

        As of this vote the relevant sha512 hashes are:
        SHA512 (CHANGELOG.md) = 6dbb09360b3116d12aed275d223f43b50a95e80aab1981d5bb61886ceb4b3b57475c976e9465f3fb28daaf62b8cae113b8ee87eae35a212c861fbc434632073b
        SHA512 (RELEASENOTES.md) = 72a12eb96f32d35a7660967caf2ce5261bd7829ddc56962c97c7b1e71cebfa026c055258a9db1b475581ca0a3ae13d9f9651724573cacaaad9972a89ff809875
        SHA512 (yetus-0.7.0-bin.tar.gz) = 28f8c94fb2e22a70674be6070f63badf98e1b022ee25c171fff9629d82ca899fc7eb509ffee2a5c50f2bec10cbb20632fb9fddcab5ebcf5c2511a3ae7edbc56b
        SHA512 (yetus-0.7.0-src.tar.gz) = 316cf36c97b301233a9b163c8b8d7ec47bdd3d042b1821820b8ac917e5668e610ec8c35fd438e45a64e05215b183ce1ad7321065883fb84ccac8b4744a7fb73e

        Source repository commit: 1e8f4588906a51317207092bd97b35687f2e3fa3
        Maven staging repository: https://repository.apache.org/content/repositories/orgapacheyetus-1011

        Our KEYS file is at: https://downloads.apache.org/yetus/KEYS
        All artifacts are signed with my key (DEADBEEF)

        JIRA version: https://s.apache.org/yetus-0.7.0-jira

        Please take a few minutes to verify the release[1] and vote on releasing it:

        [ ] +1 Release this package as Apache Yetus 0.7.0
        [ ] +0 no opinion
        [ ] -1 Do not release this package because...

        The vote will be subject to Majority Approval[2] and will close at 8:00 PM
        UTC on Monday, Xxx XXth, 2018[3].

        [1]: https://www.apache.org/info/verification.html
        [2]: https://www.apache.org/foundation/glossary.html#MajorityApproval
        [3]: to find this in your local timezone see:
        https://s.apache.org/yetus-0.7.0-rc1-close
1. Close the vote after the deadline. Once the deadline in the vote thread passes, tally the vote and post a suitable response that changes the subject line to start with "[RESULT]". If the vote failed, ensure there are issues in JIRA for any problems brought up. When they are closed, repeat the steps for creating a release candidate. If the vote passed, proceed to the [Cleanup section](#cleanup)

## Verification

You are free to make whatever checks of our release candidate artifacts suit your use, but before voting, there are certain checks you must perform according to ASF policy. This section will walk you through the required checks and give some guidelines on additional checks you may find useful. Besides the fact that downloading the release artifacts must happen first, generally, you can perform these in any order that suits you.

### Download release artifacts

You will need to download the release candidate files, include the artifacts and accompanying signatures and checksum files. The directory containing them should be in the [VOTE] thread. You can use wget or a similar tool to recursively grab all the files rather than download them one at a time. If you are not familiar with wget, it will create a nested set of directories based on the structure of the hosting site for release candidates.

For example, if we use the URL from our exemplar VOTE email, the process would look like this:

```bash
$ wget --recursive --no-parent --quiet 'https://dist.apache.org/repos/dist/dev/yetus/0.7.0-RC1/'
$ find dist.apache.org/ -type f

dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/CHANGELOG.md
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/CHANGELOG.md.asc
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/CHANGELOG.md.sha512
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/CHANGELOG.md.mds
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/index.html
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/RELEASENOTES.md
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/RELEASENOTES.md.asc
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/RELEASENOTES.md.sha512
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/RELEASENOTES.md.mds
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/apache-yetus-0.7.0-bin.tar.gz
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/apache-yetus-0.7.0-bin.tar.gz.asc
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/apache-yetus-0.7.0-bin.tar.gz.sha512
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/apache-yetus-0.7.0-bin.tar.gz.mds
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/apache-yetus-0.7.0-src.tar.gz
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/apache-yetus-0.7.0-src.tar.gz.asc
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/apache-yetus-0.7.0-src.tar.gz.sha512
dist.apache.org//repos/dist/dev/yetus/0.7.0-RC1/apache-yetus-0.7.0-src.tar.gz.mds
dist.apache.org//robots.txt
```

Lastly, if you haven't verified a release before, you'll need to download and import the public keys for the project's release managers. The public keys are located in the KEYS file that should have been mentioned in the [VOTE] thread announcement. The specific output of the following commands will vary depending on how many release managers there have been and which keys, if any, you have previously imported.

```bash
$ curl --output KEYS.yetus --silent 'https://downloads.apache.org/yetus/KEYS'
$ gpg --import KEYS.yetus
gpg: key 0D80DB7C: "Sean Busbey (CODE SIGNING KEY) <busbey@apache.org>" not changed
gpg: Total number processed: 1
gpg:              unchanged: 1
```

### ASF required checks

ASF policies require that binding votes on releases be cast only after verifying proper licensing and provenance. For specific details, you should read the [ASF Release Policy's section entitled What Must Every ASF Release Contain?](https://www.apache.org/dev/release.html#what-must-every-release-contain) as well as the informational page [What We Sign](https://www.apache.org/info/verification.html). The following is a non-normative set of guidelines.

1. You MUST make sure each of the signatures matches. As noted in the informational page [What We Sign](https://www.apache.org/info/verification.html), if you don't have the signer's key in your web of trust the output of the verify command will point this out. You should refer to it for guidance. For example, using gpg and taking a fictional source artifact:

   ```bash
   $ cd dist.apache.org/repos/dist/dev/yetus/0.7.0-RC1/
   $ gpg --verify apache-yetus-0.7.0-src.tar.gz.asc apache-yetus-0.7.0-src.tar.gz
   gpg: Signature made Fri Dec 11 11:50:56 2015 CST using RSA key ID 0D80DB7C
   gpg: Good signature from "Sean Busbey (CODE SIGNING KEY) <busbey@apache.org>"
   ```

1. You MUST make sure the provided hashes match the provided artifact.

   ```bash
   $ gpg --print-mds apache-yetus-0.7.0-src.tar.gz >apache-yetus-0.7.0-src.tar.gz.my_mds
   $ diff apache-yetus-0.7.0-src.tar.gz.mds apache-yetus-0.7.0-src.tar.gz.my_mds
   $ shasum -a 512 apache-yetus-0.7.0-src.tar.gz >apache-yetus-0.7.0-src.tar.gz.my_sha512
   $ diff apache-yetus-0.7.0-src.tar.gz.sha512 apache-yetus-0.7.0-src.tar.gz.my_sha512
   ```

1. You MUST make sure artifacts abide by the ASF Licensing Policy. You should read through [the ASF Licensing Policy](https://www.apache.org/legal/resolved), especially if your vote will be binding. As a quick guide:
   - Our software must be under the Apache Software License version 2.0 and this must be noted with a proper `LICENSE` and `NOTICE` file in each artifact that can hold them.
   - Our source code must meet the ASF policy on proper license notifications. Read the ASF Legal Committee's [Source Header Licensing Guide](https://apache.org/legal/src-headers.html)
   - Our `LICENSE` and `NOTICE` files must correctly propagate licensing information for bundled products. The [Foundation's Licensing HOWTO Guide](https://www.apache.org/dev/licensing-howto.html) provides guidance on how these files should be maintained.
   - Our software must only bundle compatibly licensed products; read [the Licensing Policy's Category A list for compatible licenses](https://www.apache.org/legal/resolved#category-a).
   - Our software may only have a runtime dependency on a product with a prohibit license if its use is optional; read [the Licensing Policy's Category X list for prohibited licenses](https://www.apache.org/legal/resolved#category-x) and [the Licensing Policy's explanation of optional runtime dependencies](https://www.apache.org/legal/resolved#optional).
1. You SHOULD make sure the source release artifact corresponds to the referenced commit hash in the [VOTE] thread. (This ASF policy is currently in DRAFT status.) The release tag is how we'll provide long-term provenance information for our downstream users. Since the release's source code artifact will be the canonical representation of the release we vote on, it is essential that it matches the contents of the version control system's tag. Given our example above, you can check this with recursive diff.

    NOTE: The `maven` plug-in that we use does not include some git control files like `.gitignore` and `.gitattributes`.  Additionally, it adds a `DEPENDENCIES` file.

   ```bash
   $ mkdir apache-yetus-0.7.0-src_unpack
   $ tar -C apache-yetus-0.7.0-src_unpack -xzf apache-yetus-0.7.0-src.tar.gz
   $ git clone --single-branch --depth=1 --branch YETUS-585 'https://github.com/apache/yetus.git' apache-yetus-0.7.0-RC1-tag
   $ diff -r apache-yetus-0.7.0-RC1-tag apache-yetus-0.7.0-src_unpack/apache-yetus-0.7.0
   ```

1. You MUST make sure any non-source artifacts can be derived from the source artifact. Since the source artifact is the canonical representation of our release, any other artifacts we distribute must be just for the convenience of our downstream users. As such, one must be able to derive them from the source artifact. Currently, you can generate all of the artifacts we distribute for convenience using the same commands used to create the release artifacts.

   ```bash
   $ mkdir apache-yetus-0.7.0-src_unpack
   $ tar -C apache-yetus-0.7.0-src_unpack -xzf apache-yetus-0.7.0-src.tar.gz
   $ cd apache-yetus-0.7.0-src_unpack/apache-yetus-0.7.0
   $ mvn clean install
   ```

This will create a `yetus-dist/target/` directory that contains the tarball binary distribution files.

### Community recommended checks

If you've gone through all of the ASF required checks, you'll already have made use of both the shelldocs and releasedocmaker components and confirmed that the compilable components successfully compile.

1. Test Precommit. The smart-apply-patch and test-patch scripts don't get flexed as a part of the above candidate verification. If you have a downstream project you regularly use, it should suffice to attempt local verification of a contribution. If that project happens to be an ASF project with an example personality, this should be as simple as finding an issue in patch-available status.

      ```bash
       $ cd path/to/my/repo/for/hbase
       $ /some/path/to/the/unpacked/candidate/bin/test-patch --project=hbase HBASE-1772
       ...SNIP...
       -1 overall

       | Vote |       Subsystem |  Runtime   | Comment
       ============================================================================
       |   0  |         reexec  |  0m 0s     | Docker mode activated.
       |  +1  |      hbaseanti  |  0m 0s     | Patch does not have any anti-patterns.
       |  +1  |        @\author  |  0m 0s     | The patch does not contain any @\author
       |      |                 |            | tags.
       |  +1  |     test4tests  |  0m 0s     | The patch appears to include 2 new or
       |      |                 |            | modified test files.
       |  +1  |     mvninstall  |  4m 41s    | main passed
       |  +1  |        compile  |  1m 4s     | main passed with JDK v1.8.0_72
       |  +1  |        compile  |  0m 57s    | main passed with JDK v1.7.0_95
       |  +1  |     checkstyle  |  0m 36s    | main passed
       |  +1  |     mvneclipse  |  0m 35s    | main passed
       |  -1  |       findbugs  |  1m 6s     | hbase-client in main has 19 extant
       |      |                 |            | Findbugs warnings.
       |  -1  |       findbugs  |  2m 8s     | hbase-server in main has 84 extant
       |      |                 |            | Findbugs warnings.
       |  -1  |        javadoc  |  0m 23s    | hbase-client in main failed with JDK
       |      |                 |            | v1.8.0_72.
       |  -1  |        javadoc  |  0m 34s    | hbase-server in main failed with JDK
       |      |                 |            | v1.8.0_72.
       |  +1  |        javadoc  |  0m 57s    | main passed with JDK v1.7.0_95
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
       | git revision | main / 81a6fff |
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
       | Powered by | Apache Yetus 0.7.0   http://yetus.apache.org |
      ```

1. Test Audience Annotations. If you have a downstream project that relies on the audience annotations project, you should be able to install the jars locally and test with the updated version.

    ```bash
    $ mkdir apache-yetus-0.7.0-src_unpack
    $ tar -C apache-yetus-0.7.0-src_unpack -xzf apache-yetus-0.7.0-src.tar.gz
    $ cd apache-yetus-0.7.0-src_unpack/yetus-0.7.0
    $ mvn --batch-mode install
    ...SNIP...
    [INFO] ------------------------------------------------------------------------
    [INFO] BUILD SUCCESS
    [INFO] ------------------------------------------------------------------------
    [INFO] Total time: 3.539 s
    [INFO] Finished at: 2016-02-13T02:12:39-06:00
    [INFO] Final Memory: 14M/160M
    [INFO] ------------------------------------------------------------------------
    $ cd path/to/your/project
    $ vim pom.xml # edit version to be e.g. 0.7.0
    $ mvn verify
    ...SNIP...
    [INFO] ------------------------------------------------------------------------
    [INFO] BUILD SUCCESS
    [INFO] ------------------------------------------------------------------------
    [INFO] Total time: 7.539 m
    [INFO] Finished at: 2016-02-13T02:13:39-06:00
    [INFO] Final Memory: 14M/160M
    [INFO] ------------------------------------------------------------------------
    ```

## Cleanup

Once a release candidate obtains majority approval from the PMC, there are several final maintenance tasks you must perform to close out the release.

### Core Release Tasks

1. Update the documentation in the git main branch for the new release.  Remove the oldest release and add the latest.

   ```bash
   $ release/update-doc-versions.sh --version=<x.y.z -- version WITHOUT the rel/!>
   $ git add -p
   $ git add asf-site-src/data/versions.yml
   $ git add asf-site-src/data/htaccess.yml
   $ git commit
   ```

   - Example commit message:

   ```text
   YETUS-XXX. add release 0.7.0.

   - list in releases
   - remove 0.4.0, add 0.7.0 to docs and downloads
   ```

1. Commit the patch to the ASF source repo immediately, but do not update the website just yet.
1. Create shortcut links to the vote thread (e.g., <https://s.apache.org/yetus-0.7.0-rc1-vote>) and the result (e.g., <https://s.apache.org/yetus-0.7.0-vote-passes>) that point to the archives on mail-archives.apache.org.  Be aware that it may take several hours for the archive to get the posts that need to be referenced.
1. Produce a signed release tag. You should create a signed tag and push it to the asf repo. The tag's message should include ASF-shortened links to the vote and results. It should be named 'rel/_version_' so that it will be immutable due to ASF infra's git configuration. Presuming we're working on the 0.7.0 release and the RC1 example above has passed:

        $ git config --global user.signingkey <your-key-id> # if you've never configured
        $ git tag --sign rel/0.7.0 1e8f4588906a51317207092bd97b35687f2e3fa3
    Example commit message:

        YETUS-XXX. tag Apache Yetus 0.7.0 release.

        vote thread: https://s.apache.org/yetus-0.7.0-rc1-vote

        results: https://s.apache.org/yetus-0.7.0-vote-passes
    Then push:

        $ git push origin rel/0.7.0
1. Move release artifacts to the distribution area. The release officially happens once the artifacts are pushed to the ASF distribution servers. From this server, the artifacts will automatically be copied to the long-term archive as well as the various mirrors that will be used by downstream users. These must be _exactly_ the artifacts from the RC that passed. Please note that currently, only Yetus PMC members have write access to this space. If you are not yet on the PMC, please ask the PMC to post the artifacts.

        $ svn co https://dist.apache.org/repos/dist/release/yetus/ yetus-dist-release
        $ cd yetus-dist-release
        $ mkdir 0.7.0
        $ cp path/to/yetus-dist-dev/0.7.0-RC1/* 0.7.0
        $ svn add 0.7.0
        $ svn commit -m "Publish Apache Yetus 0.7.0"
1. Add the release to the ASF reporter tool. To make our project reports for the ASF Board easier, you should include the release in the [Apache Committee Report Helper website](https://reporter.apache.org/addrelease.html?yetus). Be sure to use the date release artifacts first were pushed to the distribution area, which should be the same release date as in JIRA. Note that this website is only available to PMC members. If you are not yet in the PMC, please ask them to add the release information.  Additionally, it will not let you set a future date.
1. Remove candidates from the staging area. Once you have moved the artifacts into the distribution area, they no longer need to be in the staging area and should be cleaned up as a courtesy to future release managers.

        $ svn co https://dist.apache.org/repos/dist/dev/yetus/ yetus-dist-dev
        $ cd yetus-dist-dev
        $ svn rm 0.7.0-RC*
        D         0.7.0-RC1/apache-yetus-0.7.0-src.tar.gz.sha512
        D         0.7.0-RC1/apache-yetus-0.7.0-bin.tar.gz.asc
        D         0.7.0-RC1/RELEASENOTES.md
        D         0.7.0-RC1/CHANGELOG.md.mds
        D         0.7.0-RC1/CHANGELOG.md.sha512
        D         0.7.0-RC1/apache-yetus-0.7.0-src.tar.gz
        D         0.7.0-RC1/RELEASENOTES.md.asc
        D         0.7.0-RC1/apache-yetus-0.7.0-bin.tar.gz.mds
        D         0.7.0-RC1/apache-yetus-0.7.0-bin.tar.gz.sha512
        D         0.7.0-RC1/apache-yetus-0.7.0-src.tar.gz.asc
        D         0.7.0-RC1/CHANGELOG.md
        D         0.7.0-RC1/RELEASENOTES.md.mds
        D         0.7.0-RC1/CHANGELOG.md.asc
        D         0.7.0-RC1/RELEASENOTES.md.sha512
        D         0.7.0-RC1/apache-yetus-0.7.0-bin.tar.gz
        D         0.7.0-RC1/apache-yetus-0.7.0-src.tar.gz.mds
        D         0.7.0-RC1
        $ svn commit -m "cleaning up release candidates from Apache Yetus 0.7.0 release process."
        Deleting       0.7.0-RC1

        Committed revision 1772.
1. Resolve release issue; it should be marked as "fixed."
1. Go to the [ASF repository](https://repository.apache.org/) and click 'Release' to put the RC Maven artifacts into the release repository.
1. Mark JIRA version as released. Browse to the [project version management page for the YETUS JIRA tracker](https://issues.apache.org/jira/plugins/servlet/project-config/YETUS/versions). Mouse over the version you are managing, click on the gear in the far right and select Release.
1. Delete staging branch. Now that there is an immutable tag for the release, all commits leading up to that release will be maintained by git. Should we need a future maintenance release after this version, we can reestablish the branch based off of the release tag.
        $ git push origin :YETUS-XXX
1. Remove old releases from the distribution area. The ASF distribution area should only contain the most recent release for actively developed branches If your release is a maintenance release, delete the prior release. If your release marks the end of maintenance for an earlier minor or major release line, you should delete those versions from the distribution area.
1. Draft an announcement email. The announcement email should briefly describe our project and provide links to our artifacts and documentation. For example,
        Subject: [ANNOUNCE] Apache Yetus 0.7.0 release

        Apache Yetus 0.7.0 Released!

        The Apache Software Foundation and the Apache Yetus Project are pleased to
        announce the release of version 0.7.0 of Apache Yetus.

        Apache Yetus is a collection of libraries and tools that enable contribution
        and release processes for software projects.  It provides a robust system
        for automatically checking new contributions against a variety of community
        accepted requirements, the means to document a well defined supported
        interface for downstream projects, and tools to help release managers
        generate release documentation based on the information provided by
        community issue trackers and source repositories.


        This version marks the latest minor release representing the community's
        work over the last X months.


        To download, please choose a mirror by visiting:

            https://yetus.apache.org/downloads/

        The relevant checksums files are available at:

            https://downloads.apache.org/yetus/0.7.0/apache-yetus-0.7.0-src.tar.gz.sha512
            https://downloads.apache.org/yetus/0.7.0/apache-yetus-0.7.0-src.tar.gz.mds
            https://downloads.apache.org/yetus/0.7.0/apache-yetus-0.7.0-bin.tar.gz.sha512
            https://downloads.apache.org/yetus/0.7.0/apache-yetus-0.7.0-bin.tar.gz.mds

        Project member signature keys can be found at

           https://downloads.apache.org/yetus/KEYS

        PGP signatures are available at:

            https://downloads.apache.org/yetus/0.7.0/apache-yetus-0.7.0-src.tar.gz.asc
            https://downloads.apache.org/yetus/0.7.0/apache-yetus-0.7.0-bin.tar.gz.asc

        The list of changes included in this release and release notes can be browsed at:

            https://yetus.apache.org/documentation/0.7.0/CHANGELOG/
            https://yetus.apache.org/documentation/0.7.0/RELEASENOTES/

        Documentation for this release is at:

            https://yetus.apache.org/documentation/0.7.0/

        On behalf of the Apache Yetus team, thanks to everyone who helped with this
        release!

        Questions, comments, and bug reports are always welcome on

            dev@yetus.apache.org

        --
        Meg Smith
        Apache Yetus PMC
    If you'd like feedback on the draft, feel free to post it for review on your release issue.
1. Wait 24 hours for mirrors to get properly updated before continuing.

### Documentation

1. Publish website updates. See [Maintaining the Yetus Website](../website).
1. Verify that https://yetus.apache.org/latest.tgz and https://yetus.apache.org/latest.tgz.asc download the newly released version.

### Homebrew

1. Update the `yetus-homebrew` repo by using the release script. It will tag _and sign_ (so GPG needs to work!) the top of the tree to point to the release. (Homebrew only uses top of tree, so branches are pointless.)

  ```bash
  $ ./release.sh YETUS-XXX <x.y.z -- version WITHOUT the rel/!>
  ```

1. Test the formula:

  ```bash
   $ # test the formula:
   $ brew install --build-from-source Formula/yetus.rb
    # or if you already have it installed:
   $ brew upgrade --build-from-source Formula/yetus.rb
   ```

1. If all looks good, push it live.

### Github Marketplace Action

1. Verify that the [Github Container Registry](https://github.com/orgs/apache/packages?repo_name=yetus) has both repositories updated with the tagged release.
1. Update the `yetus-test-patch-action` repo by using the release script to create a branch which will then tag _and sign_ (so GPG needs to work!) that branch:

  ```bash
  $ ./release.sh YETUS-XXX <x.y.z -- version WITHOUT the rel/!>
  ```

1. Verify the branch and the tag match and that the container version matches the Apache Yetus release.
1. Push the branch:

  ```bash
  $ git push origin x.y.z
  ```

1. Verify that the tag built in Github Actions.
1. Go to [Draft a release](https://github.com/aw-was-here/yetus-test-patch-action/releases/new?marketplace=true)
1. Type the tag that you just pushed into the 'tag' box.
1. Use categories 'Code quality' and 'Continuous integration'
1. Release Title should reflect the version
1. Describe this release should be a cut-down version of the announcement email (drop SHA and direct download links. main page, github actions, and release notes should be mentioned). See [Releases](https://github.com/apache/yetus-test-patch-action/releases) for examples.
1. Mark 'This is a pre-release'
1. Verify everything looks good.
1. Publish release

### Make it Official

1. Send announcement emails. The email should come from your apache.org email address and at a minimum should go to the dev@yetus.apache.org list. For details see [the ASF Release Policy section How Should Releases Be Announced?](https://www.apache.org/dev/release.html#release-announcements). Additionally, you may want to send the announcement to the development lists of downstream projects we know are using Yetus components.
