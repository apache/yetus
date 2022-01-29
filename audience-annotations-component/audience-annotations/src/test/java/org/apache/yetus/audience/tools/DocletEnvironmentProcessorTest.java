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
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import javax.lang.model.element.Element;

import java.lang.annotation.Annotation;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/** Tests that will verify the annotation based javadoc exclusion logic */
public class DocletEnvironmentProcessorTest {
    /** The doclet processor that we test for proper configuration */
    private DocletEnvironmentProcessor processor;

    /** The environment that will host our annotated elements */
    private DocletEnvironment environment;

    @BeforeEach
    public void setup() {
        processor = new DocletEnvironmentProcessor();
        DocletEnvironment mockEnvironment = mock(DocletEnvironment.class);
        when(mockEnvironment.isIncluded(any())).thenReturn(true);
        environment = processor.wrap(mockEnvironment);
    }

    /**
     * Get an Element with no annotations.
     * @return the element
     */
    private Element get() {
        return new MockElement();
    }

    /**
     * Get an element with a single audience or stability annotations.
     * @param annotation the annotation to apply
     * @return the element
     */
    private Element get(final Class<? extends Annotation> annotation) {
        return new MockElement(annotation);
    }

    /**
     * Get an element with both audience and stability annotations.
     * @param audience the interface audience
     * @param stability the interface stability
     * @return the element
     */
    private Element get(final Class<? extends Annotation> audience,
                        final Class<? extends Annotation> stability) {
        return new MockElement(audience, stability);
    }

    @Test
    public void testStable() {
        processor.setStability(StabilityOption.STABLE);

        assertTrue(environment.isIncluded(get(InterfaceAudience.Public.class, InterfaceStability.Stable.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.Public.class, InterfaceStability.Evolving.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.Public.class, InterfaceStability.Unstable.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.Public.class)));
    }

    @Test
    public void testEvolving() {
        processor.setStability(StabilityOption.EVOLVING);

        assertTrue(environment.isIncluded(get(InterfaceAudience.Public.class, InterfaceStability.Stable.class)));
        assertTrue(environment.isIncluded(get(InterfaceAudience.Public.class, InterfaceStability.Evolving.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.Public.class, InterfaceStability.Unstable.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.Public.class)));
    }

    @Test
    public void testUnstable() {
        processor.setStability(StabilityOption.UNSTABLE);

        assertTrue(environment.isIncluded(get(InterfaceAudience.Public.class, InterfaceStability.Stable.class)));
        assertTrue(environment.isIncluded(get(InterfaceAudience.Public.class, InterfaceStability.Evolving.class)));
        assertTrue(environment.isIncluded(get(InterfaceAudience.Public.class, InterfaceStability.Unstable.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.Public.class)));
    }

    @Test
    public void testUnannotatedIncluded() {
        processor.setStability(StabilityOption.UNSTABLE);

        assertTrue(environment.isIncluded(get(InterfaceStability.Stable.class)));
        assertTrue(environment.isIncluded(get(InterfaceStability.Evolving.class)));
        assertTrue(environment.isIncluded(get(InterfaceStability.Unstable.class)));
        assertFalse(environment.isIncluded(get()));
    }

    @Test
    public void testPrivateExcluded() {
        processor.setStability(StabilityOption.UNSTABLE);
        processor.treatUnannotatedClassesAsPrivate();

        assertFalse(environment.isIncluded(get(InterfaceAudience.LimitedPrivate.class, InterfaceStability.Stable.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.LimitedPrivate.class, InterfaceStability.Evolving.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.LimitedPrivate.class, InterfaceStability.Unstable.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.LimitedPrivate.class)));

        assertFalse(environment.isIncluded(get(InterfaceAudience.Private.class, InterfaceStability.Stable.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.Private.class, InterfaceStability.Evolving.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.Private.class, InterfaceStability.Unstable.class)));
        assertFalse(environment.isIncluded(get(InterfaceAudience.Private.class)));

        assertFalse(environment.isIncluded(get(InterfaceStability.Stable.class)));
        assertFalse(environment.isIncluded(get(InterfaceStability.Evolving.class)));
        assertFalse(environment.isIncluded(get(InterfaceStability.Unstable.class)));
        assertFalse(environment.isIncluded(get()));
    }
}
