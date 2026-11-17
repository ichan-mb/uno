using Uno;
using Uno.Testing;
using Uno.Compiler.ExportTargetInterop;

// Tests for [Foreign(Language.Swift)]. Everything in this file is compiled for iOS
// only; other test runners use SwiftDummy below.
public extern(FOREIGN_SWIFT_SUPPORTED) class SwiftBasics
{
    public static int StaticField = 0;

    public int InstanceField = 0;

    [Test]
    public void Test()
    {
        Assert.AreEqual(3, Add(1, 2));
        Assert.AreEqual("hello world", Greet("world"));
        Assert.AreEqual(7.5, Half(15));
        Assert.IsFalse(Negate(false));
        Assert.AreEqual(42, StaticFieldRoundTrip());
        Assert.AreEqual(3, ArrayLength(new int[] { 1, 2, 3 }));
        Assert.AreEqual("hello from a swift file", FromFile());

        Assert.AreEqual(8, InstanceAdd(7));
        Assert.AreEqual(11, InstanceFieldRoundTrip(5));
        Assert.IsTrue(IsNullObject(null));
    }

    // Uno objects are passed to Swift as the UnoObject protocol.
    [Foreign(Language.Swift)]
    public static extern(iOS) bool IsNullObject(SwiftBasics o)
    @{
        return o == nil
    @}

    [Foreign(Language.Swift)]
    public static extern(iOS) int Add(int a, int b)
    @{
        return a + b
    @}

    [Foreign(Language.Swift)]
    public static extern(iOS) string Greet(string name)
    @{
        return "hello " + (name ?? "")
    @}

    [Foreign(Language.Swift)]
    public static extern(iOS) double Half(double x)
    @{
        return x / 2.0
    @}

    [Foreign(Language.Swift)]
    public static extern(iOS) bool Negate(bool x)
    @{
        return !x
    @}

    // Reads and writes a Uno static field from Swift using UXL macros.
    [Foreign(Language.Swift)]
    public static extern(iOS) int StaticFieldRoundTrip()
    @{
        @{SwiftBasics.StaticField:Set(42)};
        return @{SwiftBasics.StaticField:Get()}
    @}

    // Uno arrays are exposed as the UnoArray protocol in Swift.
    [Foreign(Language.Swift)]
    public static extern(iOS) int ArrayLength(int[] xs)
    @{
        return Int32(xs!.count())
    @}

    // Calls into a hand written Swift file that was added to the project. It lives in
    // the same Swift module, so no import is needed.
    [Foreign(Language.Swift)]
    public static extern(iOS) string FromFile()
    @{
        return HelloSwiftWorld().hello()
    @}

    //------------------------------------------------------------

    [Foreign(Language.Swift)]
    public extern(iOS) int InstanceAdd(int x)
    @{
        return x + 1
    @}

    [Foreign(Language.Swift)]
    public extern(iOS) int InstanceFieldRoundTrip(int x)
    @{
        @{SwiftBasics:Of(_this).InstanceField:Set(x)};
        return @{SwiftBasics:Of(_this).InstanceField:Get()} + 6
    @}
}

public extern(!FOREIGN_SWIFT_SUPPORTED) class SwiftDummy
{
    [Test]
    public void Test()
    {
        Assert.AreEqual(0, 0);
    }
}
