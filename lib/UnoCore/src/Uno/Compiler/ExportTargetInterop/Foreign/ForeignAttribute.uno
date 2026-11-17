namespace Uno.Compiler.ExportTargetInterop
{
    public enum Language { Java, ObjC, CPlusPlus, Swift, Kotlin }

    [AttributeUsage(AttributeTargets.Method | AttributeTargets.Constructor | AttributeTargets.Property | AttributeTargets.Delegate)]
    public sealed class ForeignAttribute : Attribute
    {
        public readonly Language Language;

        public ForeignAttribute(Language language)
        {
            Language = language;
        }
    }
}
