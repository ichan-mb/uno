using Uno;
using Uno.Compiler.ExportTargetInterop;

namespace Uno.Text.RegularExpressions
{
    [extern(DOTNET) DotNetType("System.Text.RegularExpressions.RegexOptions")]
    [Flags]
    public enum RegexOptions
    {
        None       = 0,
        IgnoreCase = 1
    }

    [extern(DOTNET) DotNetType("System.Text.RegularExpressions.Regex")]
    [Require("Header.Include", "regex")]
    public class Regex
    {
        [TargetSpecificType]
        [Set("TypeName", "std::regex *")]
        [Require("Source.Include", "regex")]
        extern(CPLUSPLUS) internal struct RegexHandle
        {
            public static RegexHandle Create(string pattern, RegexOptions options)
            @{
                const char *tmp = uAllocCStr(pattern);

                std::regex::flag_type opt = std::regex::extended;
                if (options & @{RegexOptions.IgnoreCase})
                    opt |= std::regex::icase;

                std::regex *ret;
                try
                {
                    ret = new std::regex(tmp, opt);
                }
                catch (std::regex_error e)
                {
                    uFreeCStr(tmp);
                    U_THROW(@{Uno.ArgumentException(string):New(uString::Utf8(e.what()))});
                }

                uFreeCStr(tmp);
                return ret;
            @}

            public static bool IsMatch(RegexHandle handle, string input)
            @{
                const char *tmp = uAllocCStr(input);
                bool ret = regex_search(tmp, *handle);
                uFreeCStr(tmp);
                return ret;
            @}
        }

        extern(CPLUSPLUS) RegexHandle _handle;

        public Regex(string pattern) : this(pattern, RegexOptions.None)
        {
        }

        public Regex(string pattern, RegexOptions options)
        {
            if (pattern == null)
                throw new ArgumentNullException("pattern");

            if defined(CPLUSPLUS)
                _handle = RegexHandle.Create(pattern, options);
            else
                build_error;
        }

        public bool IsMatch(string input)
        {
            if defined(CPLUSPLUS)
                return RegexHandle.IsMatch(_handle, input);
            else
                build_error;
        }
    }
}