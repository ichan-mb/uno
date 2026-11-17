using Uno.Compiler.API.Domain.IL.Members;

namespace Uno.Compiler.Foreign.Java.Converters
{
    internal partial class Converter
    {
        public class ParamConverter
        {
            readonly Converters.Converter _convert;

            public ParamConverter(Converters.Converter convert)
            {
                _convert = convert;
            }

            public string UnoToJavaParameter(Parameter p)
            {
                return "final " + _convert.Type.UnoToJavaType(p.Type, false) + " " + p.UnoName;
            }

            public string UnoToKotlinParameter(Parameter p)
            {
                return KotlinIdentifiers.Escape(p.UnoName) + ": " +
                    _convert.Type.UnoToKotlinType(p.Type, _convert.Type.IsKotlinNullable(p.Type));
            }
        }
    }
}
