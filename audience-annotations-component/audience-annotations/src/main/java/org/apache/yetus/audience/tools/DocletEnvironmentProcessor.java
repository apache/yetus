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
import org.apache.yetus.audience.InterfaceAudience;
import org.apache.yetus.audience.InterfaceStability;

import javax.lang.model.element.Element;

class DocletEnvironmentProcessor {
  private boolean treatUnannotatedClassesAsPrivate = false;
  private StabilityOption stability = StabilityOption.UNSTABLE;

  public void treatUnannotatedClassesAsPrivate() {
    this.treatUnannotatedClassesAsPrivate = true;
  }

  public void setStability(final StabilityOption stabilityOption) {
    this.stability = stabilityOption;
  }

  /**
   * Wrapper class that overrides the set of included elements.
   * The HtmlDoclet downcasts the parameter to a DocEnvImpl, so we
   * have to subclass that.
   */
  class DocEnvImpl extends jdk.javadoc.internal.tool.DocEnvImpl {
    DocEnvImpl(jdk.javadoc.internal.tool.DocEnvImpl environment) {
      super(environment.toolEnv, environment.etable);
    }

    @Override
    public boolean isIncluded(final Element e) {
      return !excluded(e) && super.isIncluded(e);
    }

    /**
     * Check if an element should be excluded by our annotation rules
     * @param e the element to check
     * @return true iff the element should be excluded
     */
    private boolean excluded(final Element e) {
      // Exclude private and limited private types
      if (e.getAnnotation(InterfaceAudience.Private.class) != null) {
        return true;
      }
      if (e.getAnnotation(InterfaceAudience.LimitedPrivate.class) != null) {
        return true;
      }
      if (e.getAnnotation(InterfaceAudience.Public.class) == null) {
        // No audience annotations
        if (treatUnannotatedClassesAsPrivate) {
          // Exclude classes and interfaces if they are not annotated
          return e.getKind().isClass() || e.getKind().isInterface();
        }
      }

      // At this point, everything is either public audience or unannotated
      // and treat-as-public, which means they must have a stability
      // annotation as well.

      // Filter types based on stability
      if (e.getAnnotation(InterfaceStability.Unstable.class) != null) {
        return stability == StabilityOption.STABLE
            || stability == StabilityOption.EVOLVING;
      }
      if (e.getAnnotation(InterfaceStability.Evolving.class) != null) {
        return stability == StabilityOption.STABLE;
      }
      // Public, but no stability? This is an error, so we exclude
      return e.getAnnotation(InterfaceStability.Stable.class) == null;
    }
  }

  DocletEnvironment wrap(final DocletEnvironment environment) {
    return new DocEnvImpl((jdk.javadoc.internal.tool.DocEnvImpl) environment);
  }

}
