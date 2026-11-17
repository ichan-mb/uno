using System;
using System.Collections.Generic;
using System.Linq;
using Uno.Compiler.API;
using Uno.Compiler.API.Domain.IL;
using Uno.Compiler.API.Domain.IL.Members;

namespace Uno.Compiler.Foreign.Java
{
    internal class ForeignMethod
    {
        readonly IEssentials _essentials;
        public readonly Function InitialUnoMethod;
        public readonly string JavaName;
        public readonly List<string> CppHeadersForDeclaringType;
        public readonly List<string> Annotations;
        public readonly Converters.Converter Convert;
        public readonly ForeignHelpers Helpers;

        // The foreign language this method was declared with. Java and Kotlin share the
        // same JNI plumbing, but are emitted as different source languages.
        public readonly string Language;

        public string JniSignature => Convert.Signature.GetJniSignature(InitialUnoMethod);
        public bool IsStatic => InitialUnoMethod.IsStatic;
        public DataType UnoReturnType => InitialUnoMethod.ReturnType;

        public ForeignMethod(Function f, IEssentials essentials, Converters.Converter convert, ForeignHelpers helpers, List<string> annotations, string language)
        {
            _essentials = essentials;
            Convert = convert;
            Helpers = helpers;
            Language = language;
            CppHeadersForDeclaringType = new List<string> {
                    "jni.h",
                    "uDroid/JNIHelper.h",
                    "@{global::Android.Base.Wrappers.JWrapper:include}",
                    "@{global::Android.Base.Wrappers.JavaObjectHelper:include}",
                    "@{" + ForeignJavaPass.UnoToJavaBoxingClass.FullName + ":include}"
            };
            Annotations = annotations;
            ValidateMethod(f, essentials);
            InitialUnoMethod = f;
            JavaName = convert.Name.JavaMethodName(f);
        }

        void ValidateMethod(ParametersMember f, IEssentials essentials)
        {
            if (f.Parameters.Any(x => x.Type.IsGenericType))
                throw new Exception("Foreign Code Limitation: The compiler cannot currently convert generics arguments to a " + Language + " type.\nFound in: " + f.FullName);
            if (f.ReturnType.IsGenericType)
                throw new Exception("Foreign Code Limitation: The compiler cannot currently handle generics return types.\nFound in: " + f.FullName);

            // Java has no out/ref parameters, and the JNI bridge has no way to write the
            // value back. Reject them instead of silently passing them by value.
            if (f.Parameters.Any(x => x.IsReference))
                throw new Exception("Foreign Code Limitation: " + Language + " foreign code does not support " +
                    "out/ref parameters. Return the value instead, or write it to a Uno field or property.\nFound in: " + f.FullName);

            foreach (var p in f.Parameters)
            {
                if ((p.Type.IsEnum ? p.Type.Base : p.Type) == _essentials.Byte)
                    throw new Exception("Foreign Code Limitation: Method '" + f.FullName + "' has an argument '" + p.UnoName + "' of type byte. " + Language + " does not support byte. It does however support sbyte.");
            }

            if ((f.ReturnType.IsEnum ? f.ReturnType.Base : f.ReturnType) == _essentials.Byte)
                throw new Exception("Foreign Code Limitation: Method '" + f.FullName + "' has a return type of byte. " + Language + " does not support byte. It does however support sbyte.");
        }


        public string GetCallFromUno()
        {
            return new UnoCallToForeignMethod(this, Convert, JavaName).ToSource();
        }

        // This is another cludge method. I need names to use in the c++ that don't clash
        // with the actual arg names. AFAIK we don't have an API I can use to request safe
        // names so I settled with sticking enough underscores at the front to not collide.
        // Of course, this being a cludge, it doesnt look at field names, etc.
        internal string GetSafeVarPrefixForCpp()
        {
            var wip = "_";
            while (InitialUnoMethod.Parameters.Any(x => x.Name.StartsWith(wip)))
            {
                wip += "_";
            }
            return wip;
        }
    }
}
