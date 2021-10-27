package org.apache.yetus.audience.tools;

import com.sun.source.util.DocTrees;
import jdk.javadoc.doclet.DocletEnvironment;
import org.apache.yetus.audience.InterfaceAudience;
import org.apache.yetus.audience.InterfaceStability;

import javax.lang.model.SourceVersion;
import javax.lang.model.element.Element;
import javax.lang.model.element.TypeElement;
import javax.lang.model.util.Elements;
import javax.lang.model.util.Types;
import javax.tools.JavaFileManager;
import javax.tools.JavaFileObject;
import java.util.Set;

class DocletEnvironmentProcessor {
  static boolean treatUnannotatedClassesAsPrivate = false;
  static StabilityOption stability = StabilityOption.UNSTABLE;

  private DocletEnvironmentProcessor() { }

  static DocletEnvironment wrap(DocletEnvironment environment) {
    return new DocletEnvironment() {
      @Override
      public Set<? extends Element> getSpecifiedElements() {
        return environment.getSpecifiedElements();
      }

      @Override
      public Set<? extends Element> getIncludedElements() {
        // TODO Do we need to handle exclusions here too?
        return environment.getIncludedElements();
      }

      @Override
      public DocTrees getDocTrees() {
        return environment.getDocTrees();
      }

      @Override
      public Elements getElementUtils() {
        return environment.getElementUtils();
      }

      @Override
      public Types getTypeUtils() {
        return environment.getTypeUtils();
      }

      @Override
      public boolean isIncluded(Element e) {
        return !excluded(e) && environment.isIncluded(e);
      }

      @Override
      public boolean isSelected(Element e) {
        return environment.isSelected(e);
      }

      @Override
      public JavaFileManager getJavaFileManager() {
        return environment.getJavaFileManager();
      }

      @Override
      public SourceVersion getSourceVersion() {
        return environment.getSourceVersion();
      }

      @Override
      public ModuleMode getModuleMode() {
        return environment.getModuleMode();
      }

      @Override
      public JavaFileObject.Kind getFileKind(TypeElement type) {
        return environment.getFileKind(type);
      }

      private boolean excluded(Element e) {
        if (e.getAnnotation(InterfaceAudience.Private.class) != null
            || e.getAnnotation(InterfaceAudience.LimitedPrivate.class) != null) {
          return true;
        }

        switch (stability) {
          case STABLE:
            if (e.getAnnotation(InterfaceStability.Evolving.class) != null) return true;
          case EVOLVING:
            if (e.getAnnotation(InterfaceStability.Unstable.class) != null) return true;
          case UNSTABLE:
            break;
        }

        if (treatUnannotatedClassesAsPrivate) {
          return e.getKind().isClass() || e.getKind().isInterface();
        }

        return false;
      }
    };
  }

}
