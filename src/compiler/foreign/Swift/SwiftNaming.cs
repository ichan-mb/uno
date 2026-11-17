using System.Collections.Generic;
using System.Linq;
using Uno.Compiler.API.Domain.IL;

namespace Uno.Compiler.Foreign.Swift
{
    // Naming helpers for generated Swift and Objective-C declarations.
    partial class ForeignSwiftPass
    {
        // Kotlin-style keywords are not an issue here, but Uno member names can collide
        // with Swift keywords, and parameter names are emitted verbatim.
        static readonly HashSet<string> SwiftKeywords = new HashSet<string>
        {
            "associatedtype", "class", "deinit", "enum", "extension", "fileprivate", "func",
            "import", "init", "inout", "internal", "let", "open", "operator", "private",
            "protocol", "public", "rethrows", "static", "struct", "subscript", "typealias",
            "var", "break", "case", "continue", "default", "defer", "do", "else",
            "fallthrough", "for", "guard", "if", "in", "repeat", "return", "switch", "where",
            "while", "as", "Any", "catch", "false", "is", "nil", "super", "self", "Self",
            "throw", "throws", "true", "try",
        };

        static string EscapeIdentifier(string name)
        {
            return SwiftKeywords.Contains(name)
                ? "`" + name + "`"
                : name;
        }

        // Produces a valid, unambiguous identifier fragment from a Uno name.
        //
        // Uno full names consist of identifiers separated by '.', so escaping '_' as '__'
        // before mapping separators to '_' makes the result injective: 'A.B' becomes 'A_B',
        // while a type literally named 'A_B' becomes 'A__B'. Without this, two types would
        // silently share the same generated Swift class and header.
        internal static string Mangle(string name)
        {
            var sb = new System.Text.StringBuilder(name.Length);

            foreach (var c in name)
            {
                if (c == '_')
                    sb.Append("__");
                else if (char.IsLetterOrDigit(c))
                    sb.Append(c);
                else
                    sb.Append('_');
            }

            return sb.ToString();
        }

        static string MangleType(DataType dt)
        {
            return dt.IsArray
                ? MangleType(dt.ElementType) + "Array"
                : Mangle(dt.FullName);
        }

        // Derives a stable name fragment from the parameter types of a member, so that
        // overloads get distinct generated names without relying on visit order.
        static string NameSuffix(IEnumerable<DataType> parameterTypes)
        {
            var parts = parameterTypes.Select(MangleType).ToArray();

            return parts.Length == 0
                ? ""
                : "_" + string.Join("_", parts);
        }

        static string MethodName(Function f)
        {
            return "swift_" + Mangle(f.Name) + NameSuffix(f.Parameters.Select(x => x.Type));
        }
    }
}
