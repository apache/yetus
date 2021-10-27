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

import jdk.javadoc.doclet.Reporter;
import org.apache.yetus.audience.InterfaceAudience;
import org.apache.yetus.audience.InterfaceStability;

import java.util.Locale;

/**
 * A <a href="https://docs.oracle.com/javase/8/docs/jdk/api/javadoc/doclet/">Doclet</a>
 * that only includes class-level elements that are annotated with
 * {@link org.apache.yetus.audience.InterfaceAudience.Public}.
 * Class-level elements with no annotation are excluded.
 * In addition, all elements that are annotated with
 * {@link org.apache.yetus.audience.InterfaceAudience.Private} or
 * {@link org.apache.yetus.audience.InterfaceAudience.LimitedPrivate}
 * are also excluded.
 * It delegates to the Standard Doclet, and takes the same options.
 */
@InterfaceAudience.Public
@InterfaceStability.Evolving
public class IncludePublicAnnotationsStandardDoclet extends ExcludePrivateAnnotationsStandardDoclet {
  @Override
  public void init(Locale locale, Reporter reporter) {
    DocletEnvironmentProcessor.treatUnannotatedClassesAsPrivate = true;
    super.init(locale, reporter);
  }

  @Override
  public String getName() {
    return "IncludePublicAnnotationsStandard";
  }
}
