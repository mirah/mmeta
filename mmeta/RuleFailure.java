// copyright 2009 ActiveVideo; license: MIT; see license.txt
package mmeta;

public class RuleFailure extends RuntimeException {
    public String last = "";
    public String toString() { return "ERROR.last: "+ last; }
}

