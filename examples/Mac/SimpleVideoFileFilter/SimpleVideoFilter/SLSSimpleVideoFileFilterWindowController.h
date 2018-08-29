#import <Cocoa/Cocoa.h>

extern NSArray<NSString* >* g_inputMP4Paths;

@interface SLSSimpleVideoFileFilterWindowController : NSWindowController

@property (strong) NSArray<NSString* >* urlStrings;

@end
