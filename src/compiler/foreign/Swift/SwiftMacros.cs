using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using Uno.Compiler.API.Domain.IL;
using Uno.Compiler.API.Domain.IL.Members;
using Uno.Compiler.API.Domain.IL.Types;
using Uno.IO;

namespace Uno.Compiler.Foreign.Swift
{
    // Implements the UXL macros (Get/Set/Call/Of) that appear inside Swift bodies.
    //
    // Swift can not contain C++, so a macro is turned into a call to a generated
    // Objective-C bridge method. The bridge is declared in the type's generated header (and
    // is therefore callable from Swift), and implemented in the type's .mm file, where the
    // equivalent macro is expanded to C++ exactly like normal foreign Objective-C code.
    //
    // This mirrors Java/Macros.cs, which does the same thing through JNI entrypoints.
    partial class ForeignSwiftPass
    {
        string SwiftInterceptEntity(Function context, string macroText, string expansionResult, object entity, Macros.MacroCall call)
        {
            switch (entity)
            {
                case DataType dt when call.Method == null:
                    return Types.Get(dt).Swift;

                case Field field:
                    return GenFieldBridge(context, field, macroText, call.Arguments);

                case Property property:
                    return GenPropertyBridge(context, property, macroText, call.Arguments);

                case Function function:
                    return GenCallBridge(context, function, call.Arguments);

                case ArrayType arrayType:
                    return GenArrayBridge(context, arrayType, macroText, call.Arguments);

                default:
                    throw new Exception("Foreign Swift code: unsupported UXL macro '{" + macroText + "}'.");
            }
        }

        string GenFieldBridge(Function context, Field field, string macroText, List<string> callArgs)
        {
            callArgs = callArgs ?? new List<string>();

            var isGetter = !macroText.Contains(":set(", StringComparison.InvariantCultureIgnoreCase);
            var argNames = BridgeArgNames(callArgs.Count);
            var typeName = field.DeclaringType.FullName;

            string macro;

            if (field.IsStatic)
            {
                macro = isGetter
                    ? "@{" + typeName + "." + field.UnoName + "}"
                    : "@{" + typeName + "." + field.UnoName + ":set(" + argNames[0] + ")}";
            }
            else
            {
                macro = isGetter
                    ? "@{" + typeName + ":Of(" + argNames[0] + ")." + field.UnoName + ":get()}"
                    : "@{" + typeName + ":Of(" + argNames[0] + ")." + field.UnoName + ":set(" + argNames[1] + ")}";
            }

            var parameters = new List<DataType>();

            if (!field.IsStatic)
                parameters.Add(field.DeclaringType);

            if (!isGetter)
                parameters.Add(field.ReturnType);

            var returnType = isGetter ? field.ReturnType : Essentials.Void;
            var nameHint = "callUno_" + Mangle(field.UnoName) + (isGetter ? "_get" : "_set");

            return AddBridgeMethod(context, field.DeclaringType, nameHint, macro, parameters, argNames, callArgs, returnType);
        }

        string GenPropertyBridge(Function context, Property property, string macroText, List<string> callArgs)
        {
            callArgs = callArgs ?? new List<string>();

            var isGetter = !macroText.Contains(":set(", StringComparison.InvariantCultureIgnoreCase);
            var argNames = BridgeArgNames(callArgs.Count);
            var typeName = property.DeclaringType.FullName;

            string macro;

            if (property.IsStatic)
            {
                macro = isGetter
                    ? "@{" + typeName + "." + property.UnoName + "}"
                    : "@{" + typeName + "." + property.UnoName + ":set(" + argNames[0] + ")}";
            }
            else
            {
                macro = isGetter
                    ? "@{" + typeName + ":Of(" + argNames[0] + ")." + property.UnoName + ":get()}"
                    : "@{" + typeName + ":Of(" + argNames[0] + ")." + property.UnoName + ":set(" + argNames[1] + ")}";
            }

            var parameters = new List<DataType>();

            if (!property.IsStatic)
                parameters.Add(property.DeclaringType);

            if (!isGetter)
                parameters.Add(property.ReturnType);

            var returnType = isGetter ? property.ReturnType : Essentials.Void;
            var nameHint = "callUno_" + Mangle(property.UnoName) + (isGetter ? "_get" : "_set");

            return AddBridgeMethod(context, property.DeclaringType, nameHint, macro, parameters, argNames, callArgs, returnType);
        }

        string GenCallBridge(Function context, Function function, List<string> callArgs)
        {
            callArgs = callArgs ?? new List<string>();

            var argNames = BridgeArgNames(callArgs.Count);
            var isStatic = function.IsStatic;
            var offset = isStatic ? 0 : 1;

            var callTypes = function.Parameters.Select(x => x.Type.FullName);
            var callArguments = argNames.Skip(offset);

            string macro;

            if (function.IsConstructor)
            {
                macro = "@{" + function.DeclaringType.FullName + "(" + string.Join(",", callTypes) + "):new(" +
                    string.Join(",", callArguments) + ")}";
            }
            else
            {
                var of = isStatic
                    ? ""
                    : ":of(" + argNames[0] + ")";

                macro = "@{" + function.DeclaringType.FullName + of + "." + function.UnoName +
                    "(" + string.Join(",", callTypes) + "):call(" + string.Join(",", callArguments) + ")}";
            }

            var parameters = new List<DataType>();

            if (!isStatic)
                parameters.Add(function.DeclaringType);

            parameters.AddRange(function.Parameters.Select(x => x.Type));

            return AddBridgeMethod(context, function.DeclaringType, "callUno_" + Mangle(function.UnoName),
                macro, parameters, argNames, callArgs, function.ReturnType);
        }

        string GenArrayBridge(Function context, ArrayType arrayType, string macroText, List<string> callArgs)
        {
            callArgs = callArgs ?? new List<string>();

            var isGetter = !macroText.Contains(":set(", StringComparison.InvariantCultureIgnoreCase);
            var argNames = BridgeArgNames(callArgs.Count);
            var typeName = arrayType.ElementType.FullName + "[]";

            // Array macros always have the array as the first argument, followed by the
            // index (and the value for setters).
            var macro = isGetter
                ? "@{" + typeName + ":Of(" + argNames[0] + ").Get(" + argNames[1] + ")}"
                : "@{" + typeName + ":Of(" + argNames[0] + ").Set(" + argNames[1] + "," + argNames[2] + ")}";

            var parameters = new List<DataType> { arrayType, Essentials.Int };

            if (!isGetter)
                parameters.Add(arrayType.ElementType);

            var returnType = isGetter ? arrayType.ElementType : Essentials.Void;
            var nameHint = "callUno_" + MangleType(arrayType.ElementType) + "Array_" + (isGetter ? "get" : "set");

            return AddBridgeMethod(context, arrayType, nameHint, macro, parameters, argNames, callArgs, returnType);
        }

        static string[] BridgeArgNames(int count)
        {
            var result = new string[count];

            for (var i = 0; i < count; i++)
                result[i] = "__a" + i;

            return result;
        }

        // Generates the Objective-C bridge method and its implementation, and returns the
        // Swift call expression.
        string AddBridgeMethod(
            Function context,
            DataType owner,
            string nameHint,
            string unoMacro,
            List<DataType> parameterTypes,
            string[] argNames,
            List<string> callArgs,
            DataType returnType)
        {
            var file = GetFile(owner);
            var name = file.AllocateBridgeName(nameHint + NameSuffix(parameterTypes));

            var signature = new StringBuilder("+ (" + Types.Get(returnType).ObjC + ")" + name);

            for (var i = 0; i < parameterTypes.Count; i++)
            {
                // Note: the space before the ':' on the second and later parameters is
                // required. Without it the compiler reads the previous parameter name as
                // part of the selector, and the method is not callable from Swift.
                signature.Append(i == 0 ? "" : " ")
                    .Append(":(")
                    .Append(Types.Get(parameterTypes[i]).ObjC)
                    .Append(")")
                    .Append(argNames[i]);
            }

            // Pin the name the Objective-C selector gets in Swift. Without this the Swift
            // importer applies its own renaming rules (it can drop a trailing word that
            // looks like a type), and our generated calls would not bind.
            var swiftLabels = new StringBuilder();

            for (var i = 0; i < parameterTypes.Count; i++)
                swiftLabels.Append("_:");

            var declaration = signature.ToString() +
                " NS_SWIFT_NAME(" + name + "(" + swiftLabels.ToString() + "));";

            // The bridge is emitted at file scope, outside the namespace that holds the
            // Uno types, so the macro must be expanded without a function context. That
            // makes the decompiler fully qualify the names it emits (::g::Foo). Expanding
            // with the context of the foreign function would produce bare names that only
            // resolve inside the type's own namespace.
            var expanded = Preprocess(
                context.Source,
                unoMacro,
                null,
                Helpers.GetExternFunctionScopes(context));

            string implementation;

            using (var tw = new StringWriter())
            {
                using (var ftw = new TextFormatter(tw))
                {
                    ftw.WriteLine(signature.ToString());
                    ftw.Indent("{");
                    ftw.WriteLine("@autoreleasepool");
                    ftw.Indent("{");
                    ftw.WriteLines(returnType.IsVoid ? expanded + ";" : "return " + expanded + ";");
                    ftw.Unindent("}");
                    ftw.Unindent("}");
                }

                implementation = tw.ToString();
            }

            file.AddBridge(declaration, implementation);

            return file.BridgeClassName + "." + name + "(" + string.Join(", ", callArgs) + ")";
        }
    }
}
