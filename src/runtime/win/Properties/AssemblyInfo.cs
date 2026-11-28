// GlobalAssemblyInfo.props turns off the generated assembly attributes, which would otherwise
// mark this Windows-only loader as such; without it every WinForms call warns (CA1416).
[assembly: System.Runtime.Versioning.SupportedOSPlatform("windows7.0")]
