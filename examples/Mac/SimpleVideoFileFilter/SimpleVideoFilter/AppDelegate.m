#import "AppDelegate.h"
#import "MediaCollectionWindowController.h"
#import <GPUImage/GPUImage.h>


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSProgressIndicator* progressIndicator;

-(IBAction)openFiles:(id)sender;

@end

@implementation AppDelegate

-(IBAction)openFiles:(id)sender {
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    [openPanel setPrompt: @"Open Source Media Files"];
    
    openPanel.allowedFileTypes = [NSArray arrayWithObjects: @"mp4", @"mov", @"avi", @"mkv", @"rmvb", @"jpg", @"dng", nil];
    openPanel.allowsMultipleSelection = YES;
    openPanel.directoryURL = nil;
    
    
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if (returnCode == 1)
        {
            //            NSURL* fileUrl = [[openPanel URLs] objectAtIndex:0];
            //            // 获取文件内容
            //            NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingFromURL:fileUrl error:nil];
            //            NSString *fileContext = [[NSString alloc] initWithData:fileHandle.readDataToEndOfFile encoding:NSUTF8StringEncoding];
            //
            //            // 将 获取的数据传递给 ViewController 的 TextView
            //            ViewController *mainViewController = (ViewController *)[self gainMainViewController].contentViewController;
            //            mainViewController.showCodeTextView.string = fileContext;
            [self.progressIndicator startAnimation:self];
            
            MediaCollectionWindowController* collectionVC = [[MediaCollectionWindowController alloc] initWithWindowNibName:@"MediaCollectionWindowController"];
            collectionVC.fileURLS = [openPanel URLs];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [collectionVC reloadData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.progressIndicator stopAnimation:self];
                    [collectionVC showWindow:self];
                });
            });
        }
    }];
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
