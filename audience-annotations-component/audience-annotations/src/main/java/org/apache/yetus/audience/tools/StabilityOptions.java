/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.apache.yetus.audience.tools;

import jdk.javadoc.doclet.Doclet;

import java.util.List;

enum StabilityOption implements Doclet.Option {
  STABLE("-stable"),
  EVOLVING("-evolving"),
  UNSTABLE("-unstable");

  private final List<String> name;

  private StabilityOption(String name) {
    this.name = List.of(name);
  }

  @Override
  public int getArgumentCount() {
    return 0;
  }

  @Override
  public String getDescription() {
    return "Output only APIs annotated as " + getName().substring(1) + (this == STABLE ? "" : " or stronger");
  }

  @Override
  public Kind getKind() {
    return Kind.STANDARD;
  }

  public String getName() {
    return name.get(0);
  }

  @Override
  public List<String> getNames() {
    return name;
  }

  @Override
  public String getParameters() {
    return "";
  }

  @Override
  public boolean process(String option, List<String> arguments) {
    DocletEnvironmentProcessor.stability = this;
    return true;
  }
}
