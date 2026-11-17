using System.Collections.Generic;

namespace Uno.Compiler.Foreign.Java
{
    // Kotlin source has its own keyword set. Names that collide with it have to be escaped
    // with backticks; the JVM name of the declaration is unaffected.
    internal static class KotlinIdentifiers
    {
        // Kotlin hard keywords can not be used as identifiers unless they are escaped with
        // backticks. Soft (modifier/context) keywords are valid identifiers and are
        // deliberately not escaped, to keep generated code readable.
        static readonly HashSet<string> Keywords = new HashSet<string>
        {
            "as", "break", "class", "continue", "do", "else", "false", "for", "fun",
            "if", "in", "interface", "is", "null", "object", "package", "return",
            "super", "this", "throw", "true", "try", "typealias", "typeof", "val",
            "var", "when", "while",
        };

        public static string Escape(string identifier)
        {
            return Keywords.Contains(identifier)
                ? "`" + identifier + "`"
                : identifier;
        }
    }
}
