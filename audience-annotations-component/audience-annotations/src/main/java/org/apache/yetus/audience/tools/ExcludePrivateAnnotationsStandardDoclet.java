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

import jdk.javadoc.doclet.DocletEnvironment;
import jdk.javadoc.doclet.StandardDoclet;
import org.apache.yetus.audience.InterfaceAudience;
import org.apache.yetus.audience.InterfaceStability;

import java.util.EnumSet;
import java.util.Set;
import java.util.TreeSet;

/**
 * A <a href="https://docs.oracle.com/javase/8/docs/jdk/api/javadoc/doclet/">Doclet</a>
 * for excluding elements that are annotated with
 * {@link org.apache.yetus.audience.InterfaceAudience.Private} or
 * {@link org.apache.yetus.audience.InterfaceAudience.LimitedPrivate}.
 * It delegates to the Standard Doclet, and takes the same options.
 */
@InterfaceAudience.Public
@InterfaceStability.Evolving
public class ExcludePrivateAnnotationsStandardDoclet extends StandardDoclet {
  @Override
  public String getName() {
    return "ExcludePrivateAnnotationsStandard";
  }

  @Override
  public Set<Option> getSupportedOptions() {
    Set<Option> options = new TreeSet<>(super.getSupportedOptions());
    options.addAll(EnumSet.allOf(StabilityOption.class));
    return options;
  }

  @Override
  public boolean run(DocletEnvironment environment) {
    return super.run(DocletEnvironmentProcessor.wrap(environment));
  }
}
