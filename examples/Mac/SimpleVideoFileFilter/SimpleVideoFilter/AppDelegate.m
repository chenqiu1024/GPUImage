#import "AppDelegate.h"
#import <GPUImage/GPUImage.h>

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSCollectionView* collectionView;

-(IBAction)openFiles:(id)sender;

@end

@implementation AppDelegate

-(IBAction)openFiles:(id)sender {
    NSLog(@"Open Files");
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
//    simpleVideoFileFilterWindowController = [[SLSSimpleVideoFileFilterWindowController alloc] initWithWindowNibName:@"SLSSimpleVideoFileFilterWindowController"];
//    [simpleVideoFileFilterWindowController showWindow:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
