namespace Uno.Compiler.Foreign.Java
{
    // The Java foreign code pass emits code for two JVM languages. They share the
    // same JNI ABI and the same runtime support classes, so only the syntax and the
    // type names differ.
    internal enum JvmDialect
    {
        Java,
        Kotlin,
    }

    internal static class JvmDialectExtensions
    {
        public static bool IsKotlin(this JvmDialect dialect) => dialect == JvmDialect.Kotlin;

        public static string FileExtension(this JvmDialect dialect) => dialect.IsKotlin() ? "kt" : "java";

        public static string LanguageName(this JvmDialect dialect) => dialect.IsKotlin() ? "Kotlin" : "Java";
    }
}
