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
package org.apache.yetus.maven.plugin.fileops;

import java.io.File;

import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.LifecyclePhase;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;

import org.apache.yetus.audience.InterfaceAudience;
import org.apache.yetus.audience.InterfaceStability;

/**
 * Goal which creates the X directories.
 */
@Mojo(name = "parallel-mkdirs",
      defaultPhase = LifecyclePhase.GENERATE_TEST_RESOURCES,
        threadSafe = true)
@InterfaceAudience.Private
@InterfaceStability.Unstable
public final class CreateDirsMojo extends AbstractMojo {

  /**
   * Location of the dirName.
   */
  @Parameter(defaultValue = "${project.build.directory}/test-dir")
  private File buildDir;

  /**
   * Thread count.
   */
  @Parameter(defaultValue = "1")
  private String forkCount;

  /**
   * Execute our plugin.
   * @throws MojoExecutionException  an error occurred
   */
  @InterfaceAudience.Private
  @InterfaceStability.Unstable
  public void execute() throws MojoExecutionException {
    int numDirs = getForkCount();

    mkParallelDirs(buildDir, numDirs);
  }

  /**
   * Get the real number of parallel threads.
   * @return int number of threads
   */
  @InterfaceAudience.Private
  @InterfaceStability.Unstable
  public int getForkCount() {
    int calcForkCount = 1;
    if (forkCount != null) {
      String trimProp = forkCount.trim();
      if (trimProp.endsWith("C")) {
        double multiplier = Double.parseDouble(
            trimProp.substring(0, trimProp.length() - 1));
        double calculated = multiplier * ((double) Runtime
            .getRuntime()
            .availableProcessors());
        if (calculated > 0d) {
          calcForkCount = Math.max((int) calculated, 1);
        }
      } else {
        calcForkCount = Integer.parseInt(forkCount);
      }
    }
    return calcForkCount;
  }

  /**
   * Make the directories.
   * @param pDir base directory
   * @param numDirs number of directories to create
   * @throws MojoExecutionException an error occurred
   */
  private void mkParallelDirs(final File pDir, final int numDirs)
      throws MojoExecutionException {
    for (int i = 1; i <= numDirs; i++) {
      File newDir = new File(pDir, String.valueOf(i));
      if (!newDir.exists()) {
        getLog().info("Creating " + newDir.toString());
        if (!newDir.mkdirs()) {
          throw new MojoExecutionException("Unable to create "
              + newDir.toString());
        }
      }
    }
  }
}
