using System;
using System.Collections.Generic;
using System.Linq;
using Uno.Compiler.API.Domain.IL;
using Uno.Compiler.API.Domain.IL.Members;

namespace Uno.Compiler.Foreign.Java
{

    // This file focuses on handling calls from java to uno
    // these occur when the user has added macros inside the
    // uno foreign method.

    internal partial class ForeignJavaPass : ForeignPass
    {
        //-----------------------------------------------------
        // Dispatch
        //
        // Take Call macro expansion and create java & uno code for call to native.
        //
        // The dialect of the body being expanded is passed in explicitly instead of being
        // stored on the pass, so expansion can not accidentally pick up the language of a
        // previously processed function.

        string InterceptEntity(JvmDialect dialect, string macroText, string expansionResult, object context, Macros.MacroCall call)
        {
            var callArgs = call.Arguments;
            if (context is Function)
                return InterceptCall(dialect, expansionResult, (Function)context, callArgs);
            if (context is Field)
                return InterceptField(macroText, expansionResult, (Field)context, callArgs);
            if (context is Property)
                return InterceptProperty(macroText, expansionResult, (Property)context, callArgs);
            if (context is DataType && callArgs == null && call.Method == null)
                return InterceptType(dialect, (DataType)context);
            // we dont manipulate it
            return expansionResult;
        }

        //-----------------------------------------------------
        // Types

        string InterceptType(JvmDialect dialect, DataType dt)
        {
            if (dt == Essentials.Byte)
                throw new System.Exception("Foreign Code Limitation: Tried to expand @{byte} but this is unsuppored in Java. It does however support sbyte.");

            if (dt is API.Domain.IL.Types.DelegateType)
                GenDelegatePlumbing((API.Domain.IL.Types.DelegateType)dt);

            return dialect.IsKotlin()
                ? Convert.Type.UnoToKotlinType(dt)
                : Convert.Type.UnoToJavaType(dt, false);
        }

        //-----------------------------------------------------
        // Fields & Properties

        string InterceptField(string macroText, string expansionResult, Field field, object callArgs)
        {
            var isGetter = !macroText.Contains(":set(", StringComparison.InvariantCultureIgnoreCase);
            var ufunc = new ForeignMacroExpr(field, isGetter, Convert, Helpers);
            var entrypointName = Convert.Name.GenNativeFieldName(field, isGetter);

            // Add requirements
            BlockHost.RequireMember(field);
            BlockHost.Include(field.DeclaringType);
            BlockHost.Include(ufunc.EntrypointIncludes);

            // Generate c++ entrypoint
            BlockHost.AddCppEntrypoint(ufunc, entrypointName);

            // Generate java native method
            BlockHost.NativeJavaMethods.Add(ufunc.GenJavaNativeMethod(entrypointName));

            // Generate java call to java native method
            var args = callArgs == null ? new List<string>() : new List<string>((List<string>)callArgs);
            return ufunc.GenCallToNativeMethod(entrypointName, args);
        }

        string InterceptProperty(string macroText, string expansionResult, Property property, object callArgs)
        {
            var isGetter = !macroText.Contains(":set(", StringComparison.InvariantCultureIgnoreCase);
            var ufunc = new ForeignMacroExpr(property, isGetter, Convert, Helpers);
            var entrypointName = Convert.Name.GenNativePropertyName(property, isGetter);

            // Add requirements
            BlockHost.RequireMember(property);
            BlockHost.Include(property.DeclaringType);
            BlockHost.Include(ufunc.EntrypointIncludes);

            // Generate c++ entrypoint
            BlockHost.AddCppEntrypoint(ufunc, entrypointName);

            // Generate java native method
            BlockHost.NativeJavaMethods.Add(ufunc.GenJavaNativeMethod(entrypointName));

            // Generate java call to java native method
            var args = callArgs == null ? new List<string>() : new List<string>((List<string>)callArgs);
            return ufunc.GenCallToNativeMethod(entrypointName, args);
        }

        //-----------------------------------------------------
        // Calls

        string InterceptCall(JvmDialect dialect, string expansionResult, Function func, object callArgs)
        {
            return InterceptCall(dialect, func, callArgs);
        }

        string InterceptCall(JvmDialect dialect, Function func, object callArgs)
        {
            var langString = Helpers.GetForeignAttribute(func);
            if (langString != null && MatchesLanguage(langString))
                return InterceptCallToForeign(func, callArgs);
            else
                return InterceptCallToUno(dialect, func, callArgs);
        }

        string InterceptCallToForeign(Function func, object callArgs)
        {
            // In this case we dont want to call via uno, just work out the
            // java method name and call it directly.
            //
            // The target class name is derived from the declaring type rather than looked up,
            // so that a call between foreign methods does not create an empty generated
            // class for a type that has no foreign methods of its own.
            var javaMethodName = Convert.Name.JavaMethodName(func);
            var className = Convert.Name.ComForeignClassName(func.DeclaringType, GetFunctionDialect(func));
            var args = callArgs == null ? "" : string.Join(", ", (List<string>)callArgs);
            var javaCall = className + "." + javaMethodName + "(" + args + ")";
            return javaCall;
        }

        string InterceptCallToUno(JvmDialect dialect, Function func, object callArgs)
        {
            var ufunc = new ForeignMacroExpr(func, Convert, Helpers);
            var entrypointName = Convert.Name.GenNativeMethodName(func);

            // Add requirements
            BlockHost.RequireMember(func);
            BlockHost.Include(ufunc.EntrypointIncludes);

            // Generate c++ entrypoint
            BlockHost.AddCppEntrypoint(ufunc, entrypointName);

            // Generate java native method
            BlockHost.NativeJavaMethods.Add(ufunc.GenJavaNativeMethod(entrypointName));

            // Generate java call to java native method
            var args = (List<string>)callArgs;
            var castedArgs = dialect.IsKotlin()
                ? args
                : (IEnumerable<string>)ufunc.Params.Zip(args, (x, y) => x.JavaArgCast + y);
            return ufunc.GenCallToNativeMethod(entrypointName, new List<string>(castedArgs));
        }
    }
}
