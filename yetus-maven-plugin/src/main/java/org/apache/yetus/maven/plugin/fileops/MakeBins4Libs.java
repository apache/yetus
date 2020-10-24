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
import java.io.PrintWriter;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.attribute.PosixFilePermission;
import java.util.HashSet;
import java.util.Set;

import org.apache.maven.plugin.AbstractMojo;
import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.LifecyclePhase;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;

import org.apache.commons.io.FilenameUtils;
import org.apache.commons.io.IOUtils;

import org.apache.yetus.audience.InterfaceAudience;
import org.apache.yetus.audience.InterfaceStability;

/**
 * Goal which creates symlinks.
 */
@Mojo(name = "bin4libs",
      defaultPhase = LifecyclePhase.PACKAGE,
      threadSafe = true)
@InterfaceAudience.Private
@InterfaceStability.Unstable
public final class MakeBins4Libs extends AbstractMojo {

  /**
   * bin dir.
   */
  @Parameter(defaultValue = "bin")
  private String bindir;

  /**
   * lib dir.
   */
  @Parameter(defaultValue = "lib")
  private String libdir;

  /**
   * License to use as a header.
   */
  @Parameter(defaultValue = "ASL20")
  private String license;

  /**
   * parent of bin and lib dir, if relative.
   */
  @Parameter(defaultValue =
      "${project.build.directory}/${project.artifactId}-${project.version}")
  private String basedir;

  /**
   * wrapper to put down.
   */
  private String wrapper = "exec \"$(dirname -- \"${BASH_SOURCE-0}\")/../";

  /**
   * The file encoding to use when reading/writing the source files.
   */
  @Parameter (property = "encoding",
              defaultValue = "${project.build.sourceEncoding}")
  private String encoding;

  /**
   * Execute our plugin.
   * @throws MojoExecutionException  an error occurred
   */
  public void execute() throws MojoExecutionException {

    Path libPath = Paths.get(libdir);
    Path binPath = Paths.get(bindir);

    if (!libPath.isAbsolute()) {
      libPath = Paths.get(basedir, libdir);
    }

    if (!binPath.isAbsolute()) {
      binPath = Paths.get(basedir, bindir);
    }

    try {
      binPath.toFile().mkdir();
    } catch (Exception x) {
      throw new MojoExecutionException("Unable to create "
          + binPath.toString() + ": " + x);
    }

    Set<PosixFilePermission> perms = new HashSet<PosixFilePermission>();
    perms.add(PosixFilePermission.OWNER_READ);
    perms.add(PosixFilePermission.OWNER_WRITE);
    perms.add(PosixFilePermission.OWNER_EXECUTE);
    perms.add(PosixFilePermission.GROUP_READ);
    perms.add(PosixFilePermission.GROUP_EXECUTE);
    perms.add(PosixFilePermission.OTHERS_READ);
    perms.add(PosixFilePermission.OTHERS_EXECUTE);

    File libFile = libPath.toFile();
    if (libFile == null) {
      throw new MojoExecutionException("Cannot convert "
          + libPath.toString());
    }

    File[] libListOfFiles = libFile.listFiles();
    if (libListOfFiles == null) {
      throw new MojoExecutionException("No files in " + libPath.toString());
    }
    System.out.println("Processing dir " + libPath.toString());

    for (int i = 0; i < libListOfFiles.length; i++) {
      if ((libListOfFiles[i] != null) && (libListOfFiles[i].isFile())) {
        String basename = FilenameUtils
            .getBaseName(libListOfFiles[i].getName());
        String theName = FilenameUtils.getName(libListOfFiles[i].getName());
        String binName = Paths.get(binPath.toString(), basename).toString();
        System.out.println("Creating file " + binName);

        try {
          PrintWriter binFile = new PrintWriter(binName, encoding);
          String noneString = "none";

          binFile.println("#!/usr/bin/env bash");

          if (!license.equals(noneString)) {
            InputStream inLicense = this.getClass()
                                        .getClassLoader()
                                        .getResourceAsStream("licenses/"
                                          + license + ".txt");
            IOUtils.copy(inLicense, binFile);
            inLicense.close();
          }
          binFile.println(wrapper + libdir + "/" + theName + "\" \"$@\"");
          binFile.close();
          Files.setPosixFilePermissions(Paths.get(binName), perms);
        } catch (Exception x) {
          throw new MojoExecutionException("Unable to create "
              + binName + ": " + x);

        }
      }
    }
  }
}
