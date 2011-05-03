// copyright 2009 ActiveVideo; license: MIT; see license.txt
package mmeta;

public class RuleFailure extends Exception {
    public String last = "";
    public String toString() { return "ERROR.last: "+ last; }
}

