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

import java.nio.file.Files;
import java.nio.file.FileAlreadyExistsException;
import java.nio.file.Path;
import java.nio.file.Paths;

//import org.apache.maven.execution.MavenSession;

import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.LifecyclePhase;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;

/**
 * Goal which creates symlinks.
 */
@Mojo(name = "symlink",
      defaultPhase = LifecyclePhase.PACKAGE,
      threadSafe = true)
public final class CreateSymLinkMojo extends AbstractMojo {

  /**
   * Location of the target.
   */
  @Parameter
  private String target;

  /**
   * the link to create.
   */
  @Parameter
  private String newLink;

  /**
   * ignore already exists errors.
   */
  @Parameter(defaultValue = "true")
  private Boolean ignoreExist;


  /**
   * starting directory for relatives.
   */
  @Parameter(defaultValue = "${project.build.directory}")
  private String basedir;

  /**
   * starting directory for relatives.
   * @throws   MojoExecutionException an error occurred
   */
  public void execute() throws MojoExecutionException {
    if (target == null) {
      throw new MojoExecutionException("target of symlink is undefined.");
    }

    if (newLink == null) {
      throw new MojoExecutionException("newLink of symlink is undefined.");
    }

    Path targetPath = Paths.get(target);
    Path newLinkPath = Paths.get(newLink);

    if (!newLinkPath.isAbsolute()) {
      newLinkPath = Paths.get(basedir, newLink);
    }

    try {
        Files.createSymbolicLink(newLinkPath, targetPath);
    } catch (FileAlreadyExistsException x) {
      if (!ignoreExist) {
        throw new MojoExecutionException("Unable to create "
            + newLinkPath.toString() + ": " + targetPath.toString() + " " + x);
      }
    } catch (Exception x) {
      throw new MojoExecutionException("Unable to create "
          + newLinkPath.toString() + ": " + targetPath.toString() + " " + x);
    }
  }
}
