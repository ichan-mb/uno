using System.Collections.Generic;
using Uno.Compiler.API;
using Uno.Compiler.API.Domain.IL;
using Uno.Compiler.API.Domain.IL.Members;
using Uno.Compiler.Backends.CPlusPlus;

namespace Uno.Compiler.Foreign.Java
{
    partial class ForeignJavaPass : ForeignPass
    {
        bool _initialized;
        readonly Dictionary<DataType, JavaClass> TopLevelJavaClasses = new Dictionary<DataType, JavaClass>();
        readonly Dictionary<DataType, JavaClass> TopLevelKotlinClasses = new Dictionary<DataType, JavaClass>();
        internal static DataType BoxedJavaObject;
        internal static DataType UnoToJavaBoxingClass;
        Entrypoints BlockHost;
        public Converters.Converter Convert;

        protected override bool MatchesLanguage(string language) => language == "Java" || language == "Kotlin";

        public ForeignJavaPass(CppBackend backend) : base(backend) {}

        void EnsureInitialized()
        {
            if (!_initialized)
            {
                BoxedJavaObject = ILFactory.GetType("Java.Object");
                _initialized = true;
                Convert = new Converters.Converter(BoxedJavaObject, Essentials, ILFactory, Helpers);
                BlockHost = new Entrypoints(Environment, Disk, ILFactory, Convert);
                UnoToJavaBoxingClass = ILFactory.GetType("Uno.Compiler.ExportTargetInterop.Foreign.Android.JavaUnoObject");
            }
        }

        protected override void OnForeignFunction(Function f, List<string> annotations, string language)
        {
            // Setup
            EnsureInitialized();
            Helpers.CacheContext(null, f.Source);

            var dialect = language == "Kotlin" ? JvmDialect.Kotlin : JvmDialect.Java;

            var fm = new ForeignMethod(f, Essentials, Convert, Helpers, annotations, language);
            GenDelegatePlumbing(f);

            // The dialect is captured by the interceptor instead of being stored on the
            // pass, so a macro expansion can never pick up the language of a previously
            // processed function.
            var interceptor = new ExpandInterceptor(
                (m, e, c, mc) => InterceptEntity(dialect, m, e, c, mc));

            // Generate new java/kotlin code
            var jcls = GetTargetClass(f.DeclaringType, Environment, dialect);
            jcls.AddForeignMethod(fm, interceptor);

            // replace the extern body string with the jni calls
            Helpers.ReplaceBody(f, fm.GetCallFromUno());

            // add c++ headers to type
            Helpers.SourceInclude(fm.CppHeadersForDeclaringType, ((Method)f).DeclaringType);
        }

        public override void End()
        {
            EnsureInitialized();
            EnableKotlinBuild();
            BlockHost.WriteJava();
            WriteJavaClasses();
            WriteDelegateTypeJavaFiles();
            BlockHost.WriteCpp(Helpers);
        }

        // Kotlin support is opted in automatically as soon as a method is declared with
        // [Foreign(Language.Kotlin)]. This wires up the Kotlin Gradle plugin and the
        // standard library, and flags the build scripts to enable Kotlin compilation.
        void EnableKotlinBuild()
        {
            if (TopLevelKotlinClasses.Count == 0)
                return;

            Environment.Require("kotlin.enabled", "true");
            Environment.Require("gradle.dependency.classPath", "org.jetbrains.kotlin:kotlin-gradle-plugin:@(kotlin.version)");
            Environment.Require("gradle.dependency.implementation", "org.jetbrains.kotlin:kotlin-stdlib:@(kotlin.version)");
        }

        void WriteJavaClasses()
        {
            foreach (var jcls in TopLevelJavaClasses.Values)
                jcls.WriteJavaClass(Disk);

            foreach (var kcls in TopLevelKotlinClasses.Values)
                kcls.WriteJavaClass(Disk);
        }

        void WriteDelegateTypeJavaFiles()
        {
            foreach (var d in DelegatesSeen.Keys)
            {
                var filePath = Convert.Name.JavaDelegateName(d, true).Replace(".", "/") + ".java";
                var path = Environment.Combine(Environment.GetString("java.sourceDirectory"), filePath);
                Disk.WriteAllText(path, DelegatesSeen[d]);
            }
        }

        // Returns the dialect the given Uno function was declared with. Only valid for
        // functions that have a [Foreign] attribute for one of the JVM languages.
        internal JvmDialect GetFunctionDialect(Function f)
        {
            var langString = Helpers.GetForeignAttribute(f);
            return langString == "Kotlin" ? JvmDialect.Kotlin : JvmDialect.Java;
        }

        // java classes
        JavaClass GetTargetClass(DataType dt, IEnvironment env, JvmDialect dialect)
        {
            var classes = dialect.IsKotlin() ? TopLevelKotlinClasses : TopLevelJavaClasses;

            if (!classes.ContainsKey(dt))
            {
                if (dt.IsNestedType)
                {
                    var parent = GetTargetClass(dt.ParentType, env, dialect);
                    if (parent.StaticNestedClasses.ContainsKey(dt))
                    {
                        return parent.StaticNestedClasses[dt];
                    }
                    else
                    {
                        var newNested = new JavaClass(dt, Helpers, Convert, BlockHost, env, dialect);
                        parent.StaticNestedClasses[dt] = newNested;
                        return newNested;
                    }
                }
                else
                {
                    classes[dt] = new JavaClass(dt, Helpers, Convert, BlockHost, env, dialect);
                }
            }
            return classes[dt];
        }
    }
}
