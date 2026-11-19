using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Uno.Compiler.API;
using Uno.Configuration;
using Uno.Diagnostics;
using Uno.Logging;

namespace Uno.Build.Targets.Utilities
{
    /// <summary>
    /// Locates the Android SDK and a JDK when *.unoconfig* and the environment variables
    /// checked in android.uxl have not configured them. Public so that hosts running uno
    /// in-process (fuse-preview) find the same SDK and JDK as the build.
    /// </summary>
    public static class AndroidToolchain
    {
        /// <summary>Oldest JDK supported by the Android Gradle Plugin used by the app template.</summary>
        const int MinJavaVersion = 17;

        static readonly string[] SdkVariables = { "ANDROID_SDK", "ANDROID_HOME", "ANDROID_SDK_ROOT" };

        /// <summary>
        /// Sets `config.android.sdk` and `config.java.jdk` to detected values. Project config is
        /// applied after this runs and therefore wins, so only the environment is checked here.
        /// </summary>
        public static void SetDefaults(IEnvironment env)
        {
            if (!HasEnvironmentVariable(SdkVariables))
            {
                var sdk = FindSdk();
                if (sdk != null)
                {
                    env.Set("config.android.sdk", sdk);
                    Trace("Android SDK: " + sdk);
                }
            }

            if (!HasUsableJavaHome())
            {
                var jdk = FindJdk();
                if (jdk != null)
                {
                    env.Set("config.java.jdk", jdk);
                    Trace("Java JDK: " + jdk);
                }
            }
        }

        // A JAVA_HOME known to be older than the Android Gradle Plugin needs would fail the
        // build, so a detected JDK is used instead. One of unknown version is trusted.
        static bool HasUsableJavaHome()
        {
            var javaHome = Environment.GetEnvironmentVariable("JAVA_HOME");
            if (string.IsNullOrEmpty(javaHome))
                return false;

            var version = GetJavaVersion(javaHome);
            return version == 0 || version >= MinJavaVersion;
        }

        static void Trace(string message)
        {
            if (Log.Default.IsVerbose)
                Log.Default.WriteLine(message);
        }

        static bool HasEnvironmentVariable(params string[] keys)
        {
            foreach (var key in keys)
                if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable(key)))
                    return true;
            return false;
        }

        /// <summary>
        /// Resolves the SDK the same way android.uxl does, for tools that run outside the build.
        /// </summary>
        public static string ResolveSdk()
        {
            return GetConfiguredSdk()
                   ?? FindSdk()
                   // Throws the standard "not configured" error.
                   ?? UnoConfig.Current.GetFullPath("android.sdk", "android.sdk.directory");
        }

        static string GetConfiguredSdk()
        {
            foreach (var key in new[] { "android.sdk", "android.sdk.directory" })
            {
                var paths = UnoConfig.Current.GetFullPathArray(key);
                if (paths.Length > 0)
                    return paths[0];
            }

            return null;
        }

        /// <summary>
        /// The first valid SDK named by ANDROID_SDK, ANDROID_HOME or ANDROID_SDK_ROOT, else the
        /// first valid SDK in the default location for this OS, else null.
        /// </summary>
        public static string FindSdk()
        {
            foreach (var key in SdkVariables)
            {
                var dir = Environment.GetEnvironmentVariable(key);
                if (IsSdkDirectory(dir))
                    return Path.GetFullPath(dir);
            }

            return GetSdkCandidates().FirstOrDefault(IsSdkDirectory);
        }

        static IEnumerable<string> GetSdkCandidates()
        {
            if (OperatingSystem.IsWindows())
            {
                yield return Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "Android", "Sdk");
            }
            else if (OperatingSystem.IsMacOS())
            {
                yield return Path.Combine(PlatformDetection.HomeDirectory, "Library", "Android", "sdk");
            }
            else
            {
                yield return Path.Combine(PlatformDetection.HomeDirectory, "Android", "Sdk");
                yield return Path.Combine(PlatformDetection.HomeDirectory, "Android", "sdk");
            }
        }

        static bool IsSdkDirectory(string dir)
        {
            return !string.IsNullOrEmpty(dir) &&
                   Directory.Exists(Path.Combine(dir, "platforms")) &&
                   Directory.Exists(Path.Combine(dir, "build-tools"));
        }

        /// <summary>
        /// The first JDK of version 17 or newer among the usual install locations for this OS,
        /// Android Studio's own first, else null. JAVA_HOME is not checked.
        /// </summary>
        public static string FindJdk()
        {
            // The first candidate that is recent enough wins, so Android Studio's own JDK is
            // preferred over whatever else is installed. A JRE has a "release" file too, but
            // Gradle cannot build with it.
            foreach (var dir in GetJdkCandidates())
                if (GetJavaVersion(dir) >= MinJavaVersion && HasJavac(dir))
                    return dir;

            return null;
        }

        /// <summary>
        /// The major Java version of the JDK in <paramref name="jdkDirectory"/>, read from its
        /// "release" file, or 0 when it is unknown.
        /// </summary>
        public static int JavaVersion(string jdkDirectory)
        {
            return GetJavaVersion(jdkDirectory);
        }

        static bool HasJavac(string dir)
        {
            return File.Exists(Path.Combine(dir, "bin", OperatingSystem.IsWindows() ? "javac.exe" : "javac"));
        }

        static IEnumerable<string> GetJdkCandidates()
        {
            if (OperatingSystem.IsMacOS())
            {
                yield return "/Applications/Android Studio.app/Contents/jbr/Contents/Home";

                foreach (var root in new[]
                         {
                             Path.Combine(PlatformDetection.HomeDirectory, "Library", "Java", "JavaVirtualMachines"),
                             "/Library/Java/JavaVirtualMachines"
                         })
                    foreach (var home in SortByVersion(
                                 EnumerateDirectories(root).Select(dir => Path.Combine(dir, "Contents", "Home"))))
                        yield return home;
            }
            else if (OperatingSystem.IsWindows())
            {
                var programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
                var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);

                yield return Path.Combine(programFiles, "Android", "Android Studio", "jbr");
                // Per-user installs, and the JetBrains Toolbox.
                yield return Path.Combine(localAppData, "Android", "Android Studio", "jbr");
                yield return Path.Combine(localAppData, "Programs", "Android Studio", "jbr");

                foreach (var root in new[]
                         {
                             Path.Combine(programFiles, "Java"),
                             Path.Combine(programFiles, "Eclipse Adoptium"),
                             Path.Combine(programFiles, "Microsoft"),
                             Path.Combine(localAppData, "Programs", "Eclipse Adoptium")
                         })
                    foreach (var dir in SortByVersion(EnumerateDirectories(root)))
                        yield return dir;
            }
            else
            {
                var home = PlatformDetection.HomeDirectory;

                yield return Path.Combine(home, "android-studio", "jbr");
                yield return "/opt/android-studio/jbr";
                yield return "/usr/local/android-studio/jbr";
                yield return "/snap/android-studio/current/jbr";
                yield return Path.Combine(home, ".local", "share", "JetBrains", "Toolbox", "apps", "android-studio", "jbr");

                foreach (var dir in SortByVersion(EnumerateDirectories("/usr/lib/jvm")))
                    yield return dir;

                foreach (var dir in SortByVersion(EnumerateDirectories(Path.Combine(home, ".sdkman", "candidates", "java"))))
                    yield return dir;
            }

            // Installed by the JetBrains Toolbox / IDEA "Download JDK" feature on all platforms.
            foreach (var dir in SortByVersion(EnumerateDirectories(Path.Combine(PlatformDetection.HomeDirectory, ".jdks"))))
                yield return dir;
        }

        // Directory listings come in no particular order on Linux, so without this the JDK
        // picked from a folder holding several would change from machine to machine.
        static IEnumerable<string> SortByVersion(IEnumerable<string> homes)
        {
            return homes.OrderByDescending(GetJavaVersion).ThenBy(home => home, StringComparer.Ordinal);
        }

        static IEnumerable<string> EnumerateDirectories(string dir)
        {
            try
            {
                return Directory.Exists(dir)
                    ? Directory.GetDirectories(dir)
                    : Array.Empty<string>();
            }
            catch (Exception)
            {
                return Array.Empty<string>();
            }
        }

        static int GetJavaVersion(string jdkDirectory)
        {
            // Read the version from the JDK's "release" file rather than running java.
            var release = Path.Combine(jdkDirectory, "release");

            try
            {
                if (!File.Exists(release))
                    return 0;

                const string key = "JAVA_VERSION=";

                foreach (var line in File.ReadLines(release))
                {
                    if (!line.StartsWith(key, StringComparison.Ordinal))
                        continue;

                    return ParseJavaVersion(line.Substring(key.Length).Trim().Trim('"'));
                }
            }
            catch (Exception)
            {
                // Ignore.
            }

            return 0;
        }

        static int ParseJavaVersion(string version)
        {
            var parts = version.Split('.');

            if (!int.TryParse(parts[0], out var major))
                return 0;

            // 1.8.0_514 (JDK 8 and earlier) -- report 8, not 1.
            if (major == 1 && parts.Length > 1 && int.TryParse(parts[1], out var legacy))
                return legacy;

            return major;
        }
    }
}
