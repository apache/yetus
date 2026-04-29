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
import java.util.HashSet;
import java.util.Set;

/**
 * A {@link jdk.javadoc.doclet.Doclet}
 * for excluding elements that are annotated with
 * {@link org.apache.yetus.audience.InterfaceAudience.Private} or
 * {@link org.apache.yetus.audience.InterfaceAudience.LimitedPrivate}.
 * It delegates to the Standard Doclet, and takes the same options.
 * Subclasses may override {@link #getName()}, {@link #getSupportedOptions()},
 * and {@link #run(DocletEnvironment)} to customize behavior.
 */
@InterfaceAudience.Public
@InterfaceStability.Evolving
public class ExcludePrivateAnnotationsStandardDoclet extends StandardDoclet {
  /** Default constructor. */
  public ExcludePrivateAnnotationsStandardDoclet() {
    super();
  }

  /** The doclet environment processor. */
  private DocletEnvironmentProcessor processor =
      new DocletEnvironmentProcessor();

  /**
   * Returns the processor used to filter the doclet environment.
   * @return the doclet environment processor
   */
  protected DocletEnvironmentProcessor getProcessor() {
    return processor;
  }

  /**
   * {@inheritDoc}
   * Returns the name of this doclet.
   * Subclasses should override to return a distinct name.
   * @return doclet name
   */
  @Override
  public String getName() {
    return "ExcludePrivateAnnotationsStandard";
  }

  /**
   * {@inheritDoc}
   * Returns the supported options, including stability filter options.
   * Subclasses may override to add or remove options.
   * @return set of supported options
   */
  @Override
  public Set<Option> getSupportedOptions() {
    Set<Option> options = new HashSet<>(super.getSupportedOptions());
    Set<StabilityOption> stabilityOptions =
        EnumSet.allOf(StabilityOption.class);
    stabilityOptions.forEach(o -> o.setProcessor(processor));
    options.addAll(stabilityOptions);
    return options;
  }

  /**
   * {@inheritDoc}
   * Runs the doclet, wrapping the environment to filter private elements.
   * Subclasses may override to apply additional filtering.
   * @param environment the doclet environment
   * @return true if successful
   */
  @Override
  public boolean run(final DocletEnvironment environment) {
    return super.run(processor.wrap(environment));
  }
}
