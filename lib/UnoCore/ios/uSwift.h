#pragma once

// Support header for [Foreign(Language.Swift)].
//
// It is included by the generated ObjC bridge headers (see uSwiftBridge_*.h)
// and, through the generated Swift bridging header, by the Swift compiler. Both
// need to agree on the names of the Uno wrapper types, but only the
// Objective-C++ side needs their actual definitions, so the two modes
// deliberately see different amounts of detail.

#ifdef __cplusplus

// Objective-C++: the Uno runtime and the real wrapper types.
#include <uObjC.Foreign.h>

#else

// Swift: only the protocol names matter for type checking. The runtime headers
// pull in C++, so they can not be used here.
#import <Foundation/Foundation.h>

@protocol UnoObject <NSObject>
@end

@protocol UnoArray <NSObject>
- (id)objectAtIndexedSubscript:(int)idx;
- (void)setObject:(id)obj atIndexedSubscript:(int)idx;
- (NSUInteger)count;
- (NSArray *)copyArray;
@end

#endif
