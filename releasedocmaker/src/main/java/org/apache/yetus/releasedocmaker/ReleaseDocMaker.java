package org.apache.yetus.releasedocmaker;

import java.util.Arrays;
import java.util.LinkedList;
import java.util.List;

import org.python.core.Py;
import org.python.core.PyException;
import org.python.core.PySystemState;
import org.python.util.PythonInterpreter;

public class ReleaseDocMaker {
  public static void main(final String[] args) throws PyException {
    List<String> list = new LinkedList<String>(Arrays.asList(args));
    list.add(0,"releasedocmaker");
    String[] newargs = list.toArray(new String[list.size()]);
    PythonInterpreter.initialize(System.getProperties(), System.getProperties(), newargs);
    PySystemState systemState = Py.getSystemState();
    PythonInterpreter interpreter = new PythonInterpreter();
    systemState.__setattr__("_jy_interpreter", Py.java2py(interpreter));
    String command = "try:\n "
                     + "  import releasedocmaker\n "
                     + "  releasedocmaker.main()\n"
                     + "except "
                     + "  SystemExit: pass";
    interpreter.exec(command);
  }
}
