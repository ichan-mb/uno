using System;
using System.Collections.Generic;
using System.IO;
using Uno.Compiler.API.Domain.Extensions;
using Uno.Compiler.API.Domain.IL;
using Uno.Compiler.Backends.CPlusPlus;
using Uno.Compiler.Foreign.ObjC;
using Uno.IO;

namespace Uno.Compiler.Foreign
{
    public class ForeignFilePass : Pass
    {
        readonly SourceBundle Bundle;
        readonly ExtensionRoot Extensions;
        readonly CppBackend Backend;

        public ForeignFilePass(
            ExtensionRoot extensions,
            SourceBundle bundle,
            CppBackend backend)
            : base(backend)
        {
            Extensions = extensions;
            Bundle = bundle;
            Backend = backend;
        }

        public override void Run()
        {
            var seen = new List<SourceBundle>();
            var toProcess = new List<SourceBundle> {Bundle};

            while (toProcess.Count > 0)
            {
                var bundle = toProcess[0];
                toProcess.RemoveAt(0);
                seen.Add(bundle);

                foreach (var f in bundle.ForeignSourceFiles)
                {
                    if (f.SourceKind != ForeignItem.Kind.Unknown &&
                        Environment.Test(bundle.Source, f.Condition))
                    {
                        var originalSource = new Source(bundle, bundle.SourceDirectory.TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar);
                        var copyFileType = f.GetCopyFileType();
                        Extensions.CopyFiles.Add(new CopyFile(
                            new SourceValue(originalSource, f.UnixPath),
                            CopyFileFlags.ProcessFile,
                            GetRequiredDestination(f, originalSource),
                            new SourceValue(originalSource, f.Condition),
                            new SourceValue(originalSource, copyFileType),
                            x => Preprocess(f, x)));
                        if (!string.IsNullOrEmpty(copyFileType))
                           Environment.Require(copyFileType, new SourceValue(originalSource, f.UnixPath));
                    }
                }

                foreach (var p in bundle.References)
                    if (!seen.Contains(p))
                        toProcess.Add(p);
            }
        }

        string Preprocess(ForeignItem f, string code)
        {
            switch (f.SourceKind)
            {
                case ForeignItem.Kind.ObjCHeader:
                case ForeignItem.Kind.ObjCSource:
                    return new ForeignObjCPass(Backend).Preprocess(new Source(f.UnixPath), code);
                case ForeignItem.Kind.Java:
                default: return code;
            }
        }

        SourceValue? GetRequiredDestination(ForeignItem fsource, Source projectSource)
        {
            var isJava = fsource.SourceKind == ForeignItem.Kind.Java;
            var isKotlin = fsource.SourceKind == ForeignItem.Kind.Kotlin;

            if (!isJava && !isKotlin)
                return null;

            var sourceDirectory = Environment.GetString("java.sourceDirectory");
            if (string.IsNullOrEmpty(sourceDirectory))
                return null;

            var fullSourcePath = fsource.UnixPath.UnixToNative()
                    .ToFullPath(projectSource.Bundle.SourceDirectory);
            var packageName = GetPackageName(fullSourcePath, fsource.SourceKind);
            return new SourceValue(projectSource, sourceDirectory + "/" + packageName.Replace('.', '/') + Path.GetFileName(fsource.UnixPath));
        }

        // Extracts the package declared at the top of a Java or Kotlin source file. Both use
        // a `package` directive, but only Java terminates it with a semicolon. The directory
        // the file is copied to must match the package for Java; Kotlin only needs the file
        // to end up somewhere the Kotlin compiler looks.
        static string GetPackageName(string path, ForeignItem.Kind kind)
        {
            using (var reader = new StreamReader(path))
            {
                var inBlockComment = false;

                while (!reader.EndOfStream)
                {
                    var line = reader.ReadLine().Trim();

                    if (inBlockComment)
                    {
                        var end = line.IndexOf("*/", StringComparison.Ordinal);

                        if (end < 0)
                            continue;

                        inBlockComment = false;
                        line = line.Substring(end + 2).Trim();
                    }

                    if (line.Length == 0 || line.StartsWith("//", StringComparison.Ordinal))
                        continue;

                    if (line.StartsWith("/*", StringComparison.Ordinal))
                    {
                        var end = line.IndexOf("*/", 2, StringComparison.Ordinal);

                        if (end < 0)
                        {
                            inBlockComment = true;
                            continue;
                        }

                        line = line.Substring(end + 2).Trim();

                        if (line.Length == 0)
                            continue;
                    }

                    if (!IsPackageDirective(line, out var name))
                        continue;

                    // Drop a trailing line comment.
                    var comment = name.IndexOf("//", StringComparison.Ordinal);

                    if (comment >= 0)
                        name = name.Substring(0, comment).Trim();

                    if (kind == ForeignItem.Kind.Java)
                    {
                        if (name.Length == 0 || name[name.Length - 1] != ';')
                            throw new Exception("Foreign Code Error: Malformed java package line. Missing semicolon");

                        name = name.Substring(0, name.Length - 1).Trim();
                    }
                    else if (name.EndsWith(";", StringComparison.Ordinal))
                    {
                        name = name.Substring(0, name.Length - 1).Trim();
                    }

                    return name + ".";
                }
            }

            return "";
        }

        static bool IsPackageDirective(string line, out string name)
        {
            name = null;

            const string keyword = "package";

            if (line.Length <= keyword.Length ||
                !line.StartsWith(keyword, StringComparison.Ordinal) ||
                !char.IsWhiteSpace(line[keyword.Length]))
                return false;

            name = line.Substring(keyword.Length).Trim();
            return true;
        }
    }
}
