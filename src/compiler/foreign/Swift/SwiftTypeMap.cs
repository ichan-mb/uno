using System;
using System.Collections.Generic;
using Uno.Compiler.API;
using Uno.Compiler.API.Domain.IL;
using Uno.Compiler.API.Domain.IL.Types;

namespace Uno.Compiler.Foreign.Swift
{
    // Maps an Uno type to the two representations used by the Swift foreign code support:
    //
    //   Swift - the type as seen by the body written in Swift
    //   ObjC  - the type as written in the generated Objective-C bridge header, which is
    //           also the type the generated Objective-C++ code passes at the call site
    //
    // Both views come out of the same lookup so they can not drift apart: a type is either
    // representable in both, or rejected with an explanation.
    class SwiftTypeMap
    {
        public struct Info
        {
            public readonly string Swift;
            public readonly string ObjC;

            public Info(string swift, string objc)
            {
                Swift = swift;
                ObjC = objc;
            }
        }

        readonly DataType _string;
        readonly DataType _objCObject;
        readonly DataType _intPtr;

        public SwiftTypeMap(IEssentials essentials, DataType objCObject, DataType intPtr)
        {
            _string = essentials.String;
            _objCObject = objCObject;
            _intPtr = intPtr;
        }

        public Info Get(DataType dt)
        {
            Info info;
            string error;

            if (!TryGet(dt, out info, out error))
                throw new Exception("Uno->Swift error: " + error);

            return info;
        }

        public bool TryGet(DataType dt, out Info info, out string error)
        {
            error = null;
            info = default(Info);

            if (dt.IsVoid)
            {
                info = new Info("Void", "void");
                return true;
            }

            if (dt.IsEnum)
                return TryGet(dt.Base, out info, out error);

            switch (dt.FullName)
            {
                case "bool":   info = new Info("Bool",   "BOOL");     return true;
                case "sbyte":  info = new Info("Int8",   "int8_t");   return true;
                case "byte":   info = new Info("UInt8",  "uint8_t");  return true;
                case "short":  info = new Info("Int16",  "int16_t");  return true;
                case "ushort": info = new Info("UInt16", "uint16_t"); return true;
                case "int":    info = new Info("Int32",  "int32_t");  return true;
                case "uint":   info = new Info("UInt32", "uint32_t"); return true;
                case "long":   info = new Info("Int64",  "int64_t");  return true;
                case "ulong":  info = new Info("UInt64", "uint64_t"); return true;
                case "char":   info = new Info("UInt16", "uint16_t"); return true;
                case "float":  info = new Info("Float",  "float");    return true;
                case "double": info = new Info("Double", "double");   return true;
            }

            if (dt == _string)
            {
                info = new Info("String?", "NSString* _Nullable");
                return true;
            }

            if (dt == _objCObject)
            {
                info = new Info("AnyObject?", "id _Nullable");
                return true;
            }

            if (dt == _intPtr)
            {
                info = new Info("UnsafeMutableRawPointer?", "void* _Nullable");
                return true;
            }

            if (dt.IsArray)
            {
                info = new Info("UnoArray?", "id<UnoArray> _Nullable");
                return true;
            }

            if (dt.IsDelegate)
                return TryGetDelegate((DelegateType)dt, out info, out error);

            if (dt.IsClass || dt.IsInterface)
            {
                info = new Info("UnoObject?", "id<UnoObject> _Nullable");
                return true;
            }

            error = dt.IsStruct
                ? "Uno structs can not be passed to Swift ('" + dt.FullName + "')."
                : "The compiler does not know how to convert '" + dt.FullName + "' to a Swift type.";

            return false;
        }

        bool TryGetDelegate(DelegateType dt, out Info info, out string error)
        {
            info = default(Info);
            error = null;

            var swiftParameters = new List<string>();
            var objCParameters = new List<string>();

            foreach (var p in dt.Parameters)
            {
                Info parameterInfo;

                if (!TryGet(p.Type, out parameterInfo, out error))
                {
                    error = "Delegate parameter '" + p.Name + "' can not be passed to Swift. " + error;
                    return false;
                }

                swiftParameters.Add(parameterInfo.Swift);
                objCParameters.Add(parameterInfo.ObjC);
            }

            Info returnInfo;

            if (!TryGet(dt.ReturnType, out returnInfo, out error))
            {
                error = "Delegate return value can not be passed to Swift. " + error;
                return false;
            }

            var swiftList = string.Join(", ", swiftParameters);
            var objCList = string.Join(", ", objCParameters);

            info = dt.ReturnType.IsVoid
                ? new Info(
                    "(@escaping (" + swiftList + ") -> Void)?",
                    "void (^ _Nullable)(" + objCList + ")")
                : new Info(
                    "(@escaping (" + swiftList + ") -> " + returnInfo.Swift + ")?",
                    returnInfo.ObjC + " (^ _Nullable)(" + objCList + ")");

            return true;
        }
    }
}
