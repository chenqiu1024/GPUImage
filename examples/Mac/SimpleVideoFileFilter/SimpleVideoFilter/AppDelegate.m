#import "AppDelegate.h"
#import <GPUImage/GPUImage.h>

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

-(IBAction) onOpenFile:(id)sender {
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setPrompt:@"Open Source Media Files"];
    openPanel.allowedFileTypes = @[@"mp4", @"mov", @"avi", @"mkv", @"rmvb"];
    openPanel.allowsMultipleSelection = YES;
    openPanel.directoryURL = nil;
    NSLog(@"self.window=%@", self.window);
    [openPanel beginSheet:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == 0)
        {
//            [self runProcessingWithURL:openPanel.URL];
//            [self showProcessingUI];
        }
    }];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    simpleVideoFileFilterWindowController = [[SLSSimpleVideoFileFilterWindowController alloc] initWithWindowNibName:@"SLSSimpleVideoFileFilterWindowController"];
    [simpleVideoFileFilterWindowController showWindow:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
