#import <Cocoa/Cocoa.h>

@protocol TranscodeDelegate <NSObject>

-(void) onTranscodingProgress:(float)progress fileURL:(NSString*)fileURL;
-(void) onTranscodingDone:(NSImage*)thumbnail fileURL:(NSString*)fileURL;

@end

extern NSArray<NSString* >* g_inputMP4Paths;

@interface SLSSimpleVideoFileFilterWindowController : NSWindowController

@property (strong) NSArray<NSString* >* urlStrings;

@property (weak) id<TranscodeDelegate> delegate;

@end
