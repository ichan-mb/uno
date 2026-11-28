using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.Versioning;

namespace Uno.Compiler.Backends.CIL
{
    public static class DotNet
    {
        public static readonly string RefAssemblyDirectory = GetRefAssemblyDirectory();

        public static readonly string RuntimeDirectory = GetRuntimeDirectory();

        [SupportedOSPlatform("windows")]
        public static readonly string WindowsDesktopAppDirectory = GetWindowsDesktopAppDirectory();

        // Returns something like:
        // * /usr/local/share/dotnet/packs/Microsoft.NETCore.App.Ref/10.0.1/ref/net10.0
        // * C:\Program Files\dotnet\packs\Microsoft.NETCore.App.Ref\10.0.1\ref\net10.0
        static string GetRefAssemblyDirectory()
        {
            string version;
            var dotnetDir = GetDotNetDirectory(out version);
            return Path.Combine(
                dotnetDir,
                "packs",
                "Microsoft.NETCore.App.Ref",
                version,
                "ref",
                // The reference pack of the runtime uno runs on: net<major>.0.
                "net" + version.Split('.')[0] + ".0"
            );
        }

        // Returns something like:
        // * /usr/local/share/dotnet and 6.0.8
        // * C:\Program Files\dotnet and 6.0.9
        static string GetDotNetDirectory(out string version)
        {
            var runtimeDir = GetRuntimeDirectory();
            version = Path.GetFileName(runtimeDir);
            var packageDir = Path.GetDirectoryName(runtimeDir);
            var sharedDir = Path.GetDirectoryName(packageDir);
            return Path.GetDirectoryName(sharedDir);
        }

        // Returns something like:
        // * /usr/local/share/dotnet/shared/Microsoft.NETCore.App/6.0.8
        // * C:\Program Files\dotnet\shared\Microsoft.NETCore.App\6.0.9
        static string GetRuntimeDirectory()
        {
            return RuntimeEnvironment.GetRuntimeDirectory()
                                     .TrimEnd(Path.DirectorySeparatorChar);
        }

        // Returns something like:
        // * C:\Program Files\dotnet\shared\Microsoft.WindowsDesktop.App\6.0.9
        [SupportedOSPlatform("windows")]
        static string GetWindowsDesktopAppDirectory()
        {
            string version;
            var dotnetDir = GetDotNetDirectory(out version);
            return Path.Combine(
                dotnetDir,
                "shared",
                "Microsoft.WindowsDesktop.App",
                version
            );
        }
    }
}
