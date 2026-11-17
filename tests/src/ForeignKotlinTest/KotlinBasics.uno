using Uno;
using Uno.Testing;
using Uno.Compiler.ExportTargetInterop;

// Tests for [Foreign(Language.Kotlin)]. Everything in this file is compiled for
// Android only; the non-Android test runner uses KotlinDummy below.
public extern(android) class KotlinBasics
{
    public static int StaticField = 0;

    public int InstanceField = 0;

    [Test]
    public void Test()
    {
        Assert.AreEqual(3, Add(1, 2));
        Assert.AreEqual("hello world", Greet("world"));
        Assert.AreEqual(7.5, Half(15));
        Assert.IsTrue(Negate(false));
        Assert.AreEqual(42, StaticFieldRoundTrip());
        Assert.AreEqual(3, ArrayLength(new int[] { 1, 2, 3 }));
        Assert.AreEqual("hello from a kotlin file", FromFile());

        Assert.AreEqual(8, InstanceAdd(7));
        Assert.AreEqual(11, InstanceFieldRoundTrip(5));
        Assert.IsTrue(IsNullObject(null));
    }

    // Uno objects are passed to Kotlin as com.uno.UnoObject.
    [Foreign(Language.Kotlin)]
    public static extern(android) bool IsNullObject(KotlinBasics o)
    @{
        return o == null
    @}

    [Foreign(Language.Kotlin)]
    public static extern(android) int Add(int a, int b)
    @{
        return a + b
    @}

    [Foreign(Language.Kotlin)]
    public static extern(android) string Greet(string name)
    @{
        return "hello " + name
    @}

    [Foreign(Language.Kotlin)]
    public static extern(android) double Half(double x)
    @{
        return x / 2.0
    @}

    [Foreign(Language.Kotlin)]
    public static extern(android) bool Negate(bool x)
    @{
        return !x
    @}

    // Reads and writes a Uno static field from Kotlin using UXL macros.
    [Foreign(Language.Kotlin)]
    public static extern(android) int StaticFieldRoundTrip()
    @{
        @{KotlinBasics.StaticField:Set(42)};
        return @{KotlinBasics.StaticField:Get()};
    @}

    // Uno arrays are exposed as the com.uno.*Array wrapper classes on the JVM, and are
    // nullable like every other Uno reference type.
    [Foreign(Language.Kotlin)]
    public static extern(android) int ArrayLength(int[] xs)
    @{
        return xs!!.copyArray().size
    @}

    // Calls into a hand written .kt file that was added to the project.
    [Foreign(Language.Kotlin)]
    [ForeignInclude(Language.Kotlin, "com.test.TestKotlin")]
    public static extern(android) string FromFile()
    @{
        return TestKotlin.hello()
    @}

    //------------------------------------------------------------

    [Foreign(Language.Kotlin)]
    public extern(android) int InstanceAdd(int x)
    @{
        return x + 1
    @}

    [Foreign(Language.Kotlin)]
    public extern(android) int InstanceFieldRoundTrip(int x)
    @{
        @{KotlinBasics:Of(_this).InstanceField:Set(x)};
        return @{KotlinBasics:Of(_this).InstanceField:Get()} + 6
    @}
}

public extern(!android) class KotlinDummy
{
    [Test]
    public void Test()
    {
        Assert.AreEqual(0, 0);
    }
}
