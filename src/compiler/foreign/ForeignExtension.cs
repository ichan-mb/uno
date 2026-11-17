using System.Collections.Generic;
using Uno.Compiler.API.Backends;
using Uno.Compiler.API.Domain.IL;
using Uno.Compiler.Backends.CPlusPlus;
using Uno.Compiler.Foreign.Java;
using Uno.Compiler.Foreign.ObjC;
using Uno.Compiler.Foreign.Swift;

namespace Uno.Compiler.Foreign
{
    public class ForeignExtension : BackendExtension
    {
        CppBackend _backend;

        protected override void Initialize()
        {
            _backend = (CppBackend) Backend;
        }

        protected override void Begin()
        {
            AddTransform(new ForeignFilePass(Data.Extensions, Input.Bundle, _backend));

            var languages = new HashSet<string> { "CPlusPlus" };

            if (IsDefined("ANDROID"))
            {
                AddTransform(new ForeignJavaPass(_backend));
                languages.Add("Java");
                languages.Add("Kotlin");
            }

            if (IsDefined("FOREIGN_OBJC_SUPPORTED"))
            {
                AddTransform(new ForeignObjCPass(_backend));
                languages.Add("ObjC");
            }

            if (IsDefined("FOREIGN_SWIFT_SUPPORTED"))
            {
                AddTransform(new ForeignSwiftPass(_backend));
                languages.Add("Swift");
            }

            // CPLUSPLUS is always defined here
            AddTransform(new ForeignCPlusPlusPass(_backend));

            AddTransform(new ForeignLanguageCheck(_backend, languages));
        }
    }

    // Reports foreign methods written in a language that is not supported by the target
    // being built. Without this they would silently keep their @{ ... @} body, which
    // leads to confusing C++ errors later on.
    class ForeignLanguageCheck : ForeignPass
    {
        readonly HashSet<string> _supported;

        public ForeignLanguageCheck(CppBackend backend, HashSet<string> supported)
            : base(backend)
        {
            _supported = supported;
        }

        protected override bool MatchesLanguage(string language) => true;

        protected override void OnForeignFunction(Function f, List<string> annotations, string language)
        {
            if (!_supported.Contains(language))
                Log.Error(f.Source, ErrorCode.E0000,
                    "'" + language + "' foreign code is not supported for this target. " +
                    "Move it to a platform where it is available, or use 'extern( ... )' to exclude it.");
        }
    }
}
