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
package org.apache.yetus.maven.plugin.shelldocs;

import java.util.ArrayList;

import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.LifecyclePhase;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;

import org.apache.yetus.audience.InterfaceAudience;
import org.apache.yetus.audience.InterfaceStability;
import org.apache.yetus.shelldocs.ShellDocs;

/**
 * Goal which executes releasedocmaker.
 */
@Mojo(name = "shelldocs",
      defaultPhase = LifecyclePhase.PRE_SITE,
        threadSafe = true)
@InterfaceAudience.Private
@InterfaceStability.Unstable
public final class ShellDocsMojo extends AbstractMojo {

  /**
   * Run in --lint mode.
   */
  @Parameter(defaultValue = "false")
  private Boolean lint;

  /**
   * Run in --skipprnorep mode.
   */
  @Parameter(defaultValue = "false")
  private Boolean skipprnorep;

  /**
   * Location of output.
   */
  @Parameter(defaultValue = "${project.build.directory}/generated-site/markdown/${project.name}.md")
  private String output;

  /**
   * Version to generate.
   */
  @Parameter(defaultValue = "${project.basedir}/src/main/shell")
  private String[] inputs;

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
    String[] args = argList.toArray(new String[0]);

    ShellDocs shelldocs = new ShellDocs();
    shelldocs.main(args);
  }


  /**
   * Based upon what we got from maven, build our shelldocs command line params.
   */
  private void buildArgs() {

    if (lint) {
      argList.add("--lint");
    }

    argList.add("--output");
    argList.add(output);

    for (String p: inputs) {
      argList.add("--input");
      argList.add(p);
    }

    if (skipprnorep) {
      argList.add("--skipprnorep");
    }

  }

}
