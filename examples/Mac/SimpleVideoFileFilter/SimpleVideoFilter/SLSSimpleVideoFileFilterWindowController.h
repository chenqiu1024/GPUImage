#import <Cocoa/Cocoa.h>

@class SLSSimpleVideoFileFilterWindowController;

@protocol TranscodeDelegate <NSObject>

-(void) onTranscodingProgress:(float)progress fileURL:(NSString*)fileURL;
-(void) onTranscodingDone:(NSImage*)thumbnail fileURL:(NSString*)fileURL;
-(void) onAllTranscodingDone:(SLSSimpleVideoFileFilterWindowController*)controller;

@end

extern NSArray<NSString* >* g_inputMP4Paths;

@interface SLSSimpleVideoFileFilterWindowController : NSWindowController

@property (strong) NSArray<NSString* >* urlStrings;

@property (weak) id<TranscodeDelegate> delegate;

@end
