/*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.yetus.maven.plugin.rdm;

import java.io.File;
import java.util.ArrayList;
import org.apache.yetus.maven.plugin.utils.Utils;

import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.LifecyclePhase;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;

import org.apache.yetus.audience.InterfaceAudience;
import org.apache.yetus.audience.InterfaceStability;
import org.apache.yetus.releasedocmaker.ReleaseDocMaker;

/**
 * Goal which executes releasedocmaker.
 */
@Mojo(name = "releasedocmaker",
      defaultPhase = LifecyclePhase.PRE_SITE,
        threadSafe = true)
@InterfaceAudience.Private
@InterfaceStability.Unstable
public final class ReleaseDocMakerMojo extends AbstractMojo {

  /**
   * Location of output.
   */
  @Parameter
  private String baseUrl;

  /**
   * Location of the dirName.
   */
  @Parameter(defaultValue = "${project.build.directory}")
  private File buildDir;

  /**
   * Create diretory versions.
   */
  @Parameter(defaultValue = "false")
  private Boolean dirversions;

  /**
   * Create file versions.
   */
  @Parameter(defaultValue = "false")
  private Boolean fileversions;

  /**
   * label for incompatible issues
   */
  @Parameter
  private String incompatibleLabel;

  /**
   * Create an index.
   */
  @Parameter(defaultValue = "false")
  private Boolean index;

  /**
   * Put the ASF License on generated files.
   */
  @Parameter(defaultValue = "false")
  private Boolean license;

  /**
   * Run in --lint mode.
   */
  @Parameter(defaultValue = "false")
  private Boolean lint;

  /**
   * Location of output.
   */
  @Parameter(defaultValue = "${project.build.directory}/generated-site/markdown")
  private String outputDir;

  /**
   * Put the ASF License on generated files.
   */
  @Parameter(defaultValue = "${project.name}")
  private String[] projects;

  /**
   * Title of project.
   */
  @Parameter
  private String projectTitle;

  /**
   * Treat versions as a range.
   */
  @Parameter(defaultValue = "false")
  private Boolean range;

  /**
   * Drop reporter/assignee
   */
  @Parameter(defaultValue = "false")
  private Boolean skipcredits;

  /**
   * Set the sort order
   */
  @Parameter(defaultValue = "older")
  private String sortorder;

  /**
   * Set the type order
   */
  @Parameter(defaultValue = "resolutiondate")
  private String sorttype;

  /**
   * Use today.
   */
  @Parameter(defaultValue = "false")
  private Boolean useToday;

  /**
   * Version to generate.
   */
  @Parameter(defaultValue = "${project.version}")
  private String[] versions;

  /**
   * Build our argument list to pass to the executor.
   */
  private ArrayList<String> argList = new ArrayList<String>();

  /**
   * Execute our plugin.
   * @throws MojoExecutionException  an error occurred
   */
  @InterfaceAudience.Private
  @InterfaceStability.Unstable
  public void execute() throws MojoExecutionException {

    buildArgs();
    String [] args = argList.toArray(new String[0]);

    ReleaseDocMaker rdm=new ReleaseDocMaker();
    ReleaseDocMaker.main(args);
  }


  /**
   * Based upon what we got from maven, build our rdm command line params.
   */
  private void buildArgs() {

    if (baseUrl != null ) {
      argList.add("--baseurl");
      argList.add(baseUrl);
    }

    if (dirversions) {
      argList.add("--dirversions");
    }

    if (fileversions) {
      argList.add("--fileversions");
    }

    if (incompatibleLabel != null) {
      argList.add("--incompatiblelabel");
      argList.add(incompatibleLabel);
    }

    if (index) {
      argList.add("--index");
    }

    if (license) {
      argList.add("--license");
    }

    if (lint) {
      argList.add("--lint");
    }

    argList.add("--outputdir");
    argList.add(outputDir);

    for (String p: projects) {
      argList.add("--project");
      argList.add(p);
    }

    if (projectTitle != null) {
      argList.add("--projecttitle");
      argList.add(projectTitle);
    }

    if (range) {
      argList.add("--range");
    }

    if (skipcredits) {
      argList.add("--skipcredits");
    }

    if (sortorder != null) {
      argList.add("--sortorder");
      argList.add(sortorder);
    }

    if (sorttype != null) {
      argList.add("--sorttype");
      argList.add(sorttype);
    }

    if (useToday) {
      argList.add("--usetoday");
    }

    for (String v: versions) {
      argList.add("--version");
      argList.add(v);
    }

  }

}
