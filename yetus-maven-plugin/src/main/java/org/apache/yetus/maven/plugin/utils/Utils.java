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
package org.apache.yetus.maven.plugin.utils;

import java.io.IOException;
import java.io.OutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.util.Arrays;
import java.util.List;
import java.util.LinkedList;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;


import org.apache.yetus.audience.InterfaceAudience;
import org.apache.yetus.audience.InterfaceStability;


/**
 * Random utilities for running Yetus components.
 */
@InterfaceAudience.Private
@InterfaceStability.Unstable
public final class Utils {

  /**
   * Buffer size used while zipping and unzipping zip-ed archives.
   */
  private static final int BUFFER_SIZE = 8192;


  /**
   * InputStream from the classpath that has our archive.
   */
  private ZipInputStream zipFile;

  /**
   * extracted dir+bin.
   */
  private File binDir;


  /**
   * Constructor for generic utilities.
   */
  public Utils() {
    this.zipFile = new ZipInputStream(this.getClass()
          .getClassLoader()
          .getResourceAsStream("yetus-bin.zip"));
  }

  /**
   * Execute the yetus command with the given parameters.
   * @param cmd command to execute
   * @param args to that command
   * @throws IOException an error occurred
   * @throws InterruptedException an error occurred
   * @return int process return code
   */
  public int execCmd(final String cmd, final String... args)
      throws IOException, InterruptedException {
    File cmdFile = new File(binDir, cmd);
    String realCmd = cmdFile.toString();

    String[] params = args;

    List<String> list = new LinkedList<String>(Arrays.asList(args));
    list.add(0, realCmd);
    params = list.toArray(new String[list.size()]);

    ProcessBuilder pb = new ProcessBuilder(params);
    pb.inheritIO();
    Process p = pb.start();
    return p.waitFor();
  }

  /**
   * Extract the yetus-bin file in the dest directory.
   * @param destDir The unzip directory where to extractthe  file.
   * @throws IOException an error occurred
   */
  public void extractYetus(final File destDir) throws IOException {
    this.binDir = new File(destDir, "bin");

    if (binDir.isDirectory()) {
      return;
    }
    try {
      ZipEntry entry;
      while ((entry = zipFile.getNextEntry()) != null) {
        if (!entry.isDirectory()) {
            File file = new File(destDir, entry.getName());
            if (!file.getParentFile().mkdirs()) {
              if (!file.getParentFile().isDirectory()) {
                throw new IOException("Mkdirs failed to create "
                  + file.getParentFile().toString());
              }
            }
            OutputStream out = new FileOutputStream(file);
            try {
              byte[] buffer = new byte[BUFFER_SIZE];
              int i;
              while ((i = zipFile.read(buffer)) != -1) {
                out.write(buffer, 0, i);
              }
            } finally {
              out.close();
            }
            file.setExecutable(true);
            file.setReadable(true);
            file.setWritable(true);
        }
      }
    } finally {
      zipFile.close();
    }
  }

}
