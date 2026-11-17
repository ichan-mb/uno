using System.Collections.Generic;
using Uno.Compiler.API.Domain.IL;

namespace Uno.Compiler.Foreign.Swift
{
    // Everything generated for a single Uno type: the Swift class that holds the
    // [Foreign(Language.Swift)] bodies, and the Objective-C bridge that implements the
    // UXL macros used by those bodies.
    partial class ForeignSwiftPass
    {
        class SwiftFile
        {
            public readonly DataType Type;
            public readonly string ClassName;
            public readonly string BridgeClassName;
            public readonly string BridgeHeaderName;

            readonly HashSet<string> _imports = new HashSet<string>();
            readonly List<string> _methods = new List<string>();
            readonly List<string> _bridgeDeclarations = new List<string>();
            readonly List<string> _bridgeImplementations = new List<string>();
            readonly HashSet<string> _bridgeNames = new HashSet<string>();

            public SwiftFile(DataType dt)
            {
                Type = dt;

                var mangled = Mangle(dt.FullName);
                ClassName = "UnoSwift_" + mangled;
                BridgeClassName = "UnoSB_" + mangled;
                BridgeHeaderName = "uSwiftBridge_" + mangled + ".h";
            }

            public IEnumerable<string> Imports => _imports;
            public IEnumerable<string> Methods => _methods;
            public IEnumerable<string> BridgeDeclarations => _bridgeDeclarations;
            public IEnumerable<string> BridgeImplementations => _bridgeImplementations;
            public bool HasBridge => _bridgeImplementations.Count > 0;

            public void AddImport(string ns) => _imports.Add(ns);

            // Generated sources are stored without trailing whitespace, so the writer fully
            // controls the layout of the file it emits them into.
            public void AddMethod(string source) => _methods.Add(source.TrimEnd());

            public void AddBridge(string declaration, string implementation)
            {
                _bridgeDeclarations.Add(declaration.TrimEnd());
                _bridgeImplementations.Add(implementation.TrimEnd());
            }

            // Bridge names are derived from the Uno member they expose, so they are stable
            // across unrelated changes. The suffix loop is a last resort for the rare case
            // where two different members produce the same name.
            public string AllocateBridgeName(string hint)
            {
                var name = hint;
                var index = 2;

                while (!_bridgeNames.Add(name))
                    name = hint + "_" + index++;

                return name;
            }
        }

        SwiftFile GetFile(DataType dt)
        {
            SwiftFile result;

            if (!_files.TryGetValue(dt, out result))
            {
                result = new SwiftFile(dt);
                _files.Add(dt, result);
            }

            return result;
        }
    }
}
