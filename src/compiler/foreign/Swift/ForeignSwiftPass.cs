using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Uno.Compiler.API;
using Uno.Compiler.API.Domain.Extensions;
using Uno.Compiler.API.Domain.IL;
using Uno.Compiler.API.Domain.IL.Members;
using Uno.Compiler.Backends.CPlusPlus;
using Uno.Compiler.Foreign.ObjC;

namespace Uno.Compiler.Foreign.Swift
{
    // Swift can not be inlined into the generated Objective-C++ code the way Objective-C
    // bodies can. Instead this pass generates:
    //
    //   1. A Swift class with one static function per [Foreign(Language.Swift)] method.
    //      The class is emitted as `@objc`, so Objective-C++ can call it through the
    //      module's generated `-Swift.h` header.
    //
    //   2. A replacement body for the Uno method that calls the Swift function. All
    //      type conversions between Uno and the Swift/Objective-C boundary are handled
    //      by the Objective-C pass that this pass derives from.
    //
    //   3. A generated Objective-C bridge class per Uno type, used to implement the UXL
    //      macros (Get/Set/Call/Of) that appear inside Swift bodies. The Swift body calls
    //      the bridge, and the bridge implementation (in the type's .mm file) expands the
    //      macros to C++ exactly like regular foreign Objective-C code.
    //
    // The generated code is produced by the files next to this one:
    //
    //   SwiftTypeMap.cs  - Uno type -> (Swift type, Objective-C type)
    //   SwiftNaming.cs   - identifiers for generated declarations
    //   SwiftFile.cs     - the per-type aggregate of generated methods and bridges
    //   SwiftMacros.cs   - UXL macro expansion for Swift bodies
    //   SwiftWriter.cs   - emission of the .swift and .h files
    partial class ForeignSwiftPass : ForeignObjCPass
    {
        public ForeignSwiftPass(CppBackend backend)
            : base(backend)
        {
        }

        readonly Dictionary<DataType, SwiftFile> _files = new Dictionary<DataType, SwiftFile>();
        readonly HashSet<DataType> _objCIncludesSeen = new HashSet<DataType>();

        SwiftTypeMap _types;
        SwiftTypeMap Types => _types ?? (_types = new SwiftTypeMap(Essentials, ObjCObjectType, IntPtrType));

        protected override string ForeignLanguageName => "Swift";

        // Swift bodies are never inlined directly, because the body is replaced by a call to
        // the generated Swift class.
        protected override bool AlwaysWrapBody => true;

        protected override void OnForeignFunction(Function f, List<string> annotations, string language)
        {
            EnsureInitialized(f.Source, f);
            ValidateFunction(f);

            Helpers.TryAddProperty(
                f.DeclaringType,
                "FileExtension",
                new Element(f.Source, "mm"));

            var file = GetFile(f.DeclaringType);

            // The generated bridge header brings in the Uno runtime support (uSwift.h) and,
            // for Objective-C++, the module's generated Swift header. It is always included
            // instead of the Swift header directly, so that the wrapper protocols are
            // declared before the Swift generated declarations are parsed.
            Environment.Require(
                f.DeclaringType,
                "source.include",
                f.Source,
                file.BridgeHeaderName);

            foreach (var import in Helpers.GetForeignIncludes(f.DeclaringType, ForeignLanguageName))
                file.AddImport(import);

            if (_objCIncludesSeen.Add(f.DeclaringType))
            {
                var objCIncludes = Helpers.GetForeignIncludes(f.DeclaringType, "ObjC");

                if (objCIncludes.Count > 0)
                    Helpers.SourceInclude(objCIncludes, f.DeclaringType);
            }

            var foreignBody = Helpers.GetForeignCodeFromFunction(f);

            // Expand the body once, with Swift semantics. UXL macros become calls into the
            // generated Objective-C bridge class. The pass keeps no mutable "current
            // function" state: the context is threaded through the interceptor.
            var body = Environment.Expand(
                f.Source,
                new ExpandInterceptor((m, e, c, mc) => SwiftInterceptEntity(f, m, e, c, mc)),
                foreignBody,
                false,
                f,
                Helpers.GetExternFunctionScopes(f));

            // The instance pointer is only passed on when the body actually uses it. This
            // mirrors ForeignObjCPass.WrapBody, which makes the same decision from the same
            // text, and avoids a StrongUnoObject allocation on every call that ignores
            // `_this`.
            var usesThis = !f.IsStatic && foreignBody.Contains("_this");

            file.AddMethod(GenSwiftMethod(f, body, annotations, usesThis));

            // Replace the Uno body with a call to the generated Swift class.
            Helpers.ReplaceBody(f, WrapBody(f, foreignBody));
        }

        public override void End()
        {
            EnsureSwiftModuleName();

            foreach (var file in _files.Values.OrderBy(x => x.BridgeHeaderName))
            {
                WriteSwiftFile(file);
                WriteBridgeHeader(file);

                if (file.HasBridge)
                    WriteBridgeImplementation(file);
            }

            WriteSwiftBridgingHeader();
        }

        //-----------------------------------------------------
        // Validation

        void ValidateFunction(Function f)
        {
            // Framework targets can not use a Swift bridging header, which is how the
            // generated Swift code sees the Uno/Objective-C runtime types.
            if (Environment.IsLibrary)
                throw new Exception("Foreign Code Limitation: [Foreign(Language.Swift)] is not supported " +
                    "when building a library (-DLIBRARY), because Swift framework targets can not use a " +
                    "bridging header.\nFound in: " + f.FullName);

            if (f.DeclaringType.IsGenericType)
                throw new Exception("Foreign Code Limitation: The compiler cannot currently " +
                    "expose generic types to Swift.\nFound in: " + f.DeclaringType.FullName);

            if (!f.IsStatic && f.DeclaringType.IsStruct)
                throw new Exception("Foreign Code Limitation: Instance methods on structs can not " +
                    "be exposed to Swift.\nFound in: " + f.FullName);

            foreach (var p in f.Parameters)
                ValidateType(f, p.Type, "'" + p.UnoName + "'");

            ValidateType(f, f.ReturnType, "the return value");

            if (f.ReturnType.IsSubclassOfOrEqual(Essentials.Delegate))
                throw new Exception("Foreign Code Limitation: Swift foreign code can not return " +
                    "delegates.\nFound in: " + f.FullName);

            if (f.Parameters.Any(x => x.IsReference))
                throw new Exception("Foreign Code Limitation: Swift foreign code does not support " +
                    "out/ref parameters.\nFound in: " + f.FullName);
        }

        void ValidateType(Function f, DataType dt, string what)
        {
            SwiftTypeMap.Info info;
            string error;

            if (Types.TryGet(dt, out info, out error))
                return;

            throw new Exception("Foreign Code Limitation: " + error +
                " (" + what + ")\nFound in: " + f.FullName);
        }

        //-----------------------------------------------------
        // Swift body

        protected override string GetForeignBodyOverride(Function f, string[] foreignParamNames)
        {
            var file = GetFile(f.DeclaringType);
            var call = new StringBuilder("[" + file.ClassName + " " + MethodName(f));

            foreach (var name in foreignParamNames)
                call.Append(":" + name);

            call.Append("]");

            return f.ReturnType.IsVoid
                ? call + ";"
                : "return " + call + ";";
        }
    }
}
