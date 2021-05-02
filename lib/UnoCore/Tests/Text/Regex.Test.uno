using Uno;
using Uno.Text.RegularExpressions;
using Uno.Testing;

namespace Uno.Text.Test
{
    public class RegexTest
    {
        void CreateRegexNull()
        {
            var regex = new Regex(null);
            Assert.AreEqual(null, regex);
        }

        void CreateRegexInvalid()
        {
            var regex = new Regex("[a");
            Assert.AreEqual(null, regex);
        }

        [Test]
        public void Basic()
        {
            var regex = new Regex("[a-z]+");
            Assert.AreEqual(true, regex.IsMatch("foo"));
            Assert.AreEqual(true, regex.IsMatch(" foo"));
            Assert.AreEqual(false, regex.IsMatch("FOO"));

            Assert.Throws<ArgumentNullException>(CreateRegexNull);
            Assert.Throws<ArgumentException>(CreateRegexInvalid);
        }

        [Test]
        public void MatchStartAndEnd()
        {
            var regexStart = new Regex("^[a-z]+");
            Assert.AreEqual(true, regexStart.IsMatch("foo"));
            Assert.AreEqual(false, regexStart.IsMatch(" foo"));

            var regexEnd = new Regex("[a-z]+$");
            Assert.AreEqual(true, regexEnd.IsMatch("foo"));
            Assert.AreEqual(false, regexEnd.IsMatch("foo "));

            var regexStartAndEnd = new Regex("^[a-z]+$");
            Assert.AreEqual(true, regexStartAndEnd.IsMatch("foo"));
            Assert.AreEqual(false, regexStartAndEnd.IsMatch(" foo"));
            Assert.AreEqual(false, regexStartAndEnd.IsMatch("foo "));
            Assert.AreEqual(false, regexStartAndEnd.IsMatch(" foo "));
        }

        [Test]
        [Ignore("Inconsistency between std::regex and System.Text.RegularExpressions.Regex", "CPLUSPLUS")]
        public void BracketSlash()
        {
            var regex = new Regex("[\\d]+");
            Assert.AreEqual(true, regex.IsMatch("123"));
            Assert.AreEqual(false, regex.IsMatch("\\"));
            Assert.AreEqual(false, regex.IsMatch("d"));
        }

        [Test]
        public void Unicode1()
        {
            var regex = new Regex("[\u00C5]+", RegexOptions.IgnoreCase);
            Assert.AreEqual(true, regex.IsMatch("\u00C5"));
            Assert.AreEqual(true, regex.IsMatch("\u00E5"));
        }

        [Test]
        [Ignore("No real support for Unicode", "CPLUSPLUS")]
        public void Unicode2()
        {
            var regex = new Regex("[\u04D2]+", RegexOptions.IgnoreCase);
            Assert.AreEqual(true, regex.IsMatch("\u04D2"));
            Assert.AreEqual(true, regex.IsMatch("\u04D3"));
            Assert.AreEqual(false, regex.IsMatch("\xD2"));
            Assert.AreEqual(false, regex.IsMatch("\x92"));
        }

        [Test]
        [Ignore("No real support for Unicode", "CPLUSPLUS")]
        public void Unicode3()
        {
            // 'DESERET CAPITAL LETTER LONG I' (U+10400)
            var regex = new Regex("[\uD801\uDC00]+", RegexOptions.IgnoreCase);
            Assert.AreEqual(true, regex.IsMatch("\uD801\uDC00"));
            Assert.AreEqual(true, regex.IsMatch("\uD801\uDC28"));
        }

        [Test]
        public void IgnoreCase()
        {
            var regex = new Regex("[a-z]+", RegexOptions.IgnoreCase);
            Assert.AreEqual(true, regex.IsMatch("foo"));
            Assert.AreEqual(true, regex.IsMatch("FOO"));
        }

        [Test]
        public void EmptyMatch()
        {
            var regex = new Regex("[a-z]?");
            Assert.AreEqual(true, regex.IsMatch("foo"));
            Assert.AreEqual(true, regex.IsMatch("FOO"));
        }
    }
}