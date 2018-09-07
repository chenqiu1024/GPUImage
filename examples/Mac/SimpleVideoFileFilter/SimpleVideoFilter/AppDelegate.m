#import "AppDelegate.h"
#import "MediaCollectionWindowController.h"
#import <GPUImage/GPUImage.h>

@interface AppDelegate () <TranscodeDelegate>

@property (weak) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSMenu* menu;
@property (weak) IBOutlet NSMenu* fileMenu;
@property (strong) NSMenuItem* fileMenuItem;
@property (strong) NSMenuItem* openMenuItem;
@property (strong) NSMenuItem* transcodeMenuItem;

@property (weak) IBOutlet NSProgressIndicator* progressIndicator;

@property (weak) IBOutlet NSCollectionView* collectionView;

@property (strong) MediaCollectionWindowController* collectionController;

-(IBAction)openFiles:(id)sender;

-(IBAction)startProcess:(id)sender;

@end

@implementation AppDelegate

-(IBAction)openFiles:(id)sender {
    self.fileMenuItem.enabled = NO;
    [self.menu update];
    self.openMenuItem.enabled = NO;
    self.openMenuItem.hidden = YES;
//    self.transcodeMenuItem.enabled = NO;
//    self.transcodeMenuItem.hidden = YES;
    [self.fileMenu update];
    
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
            /*
            MediaCollectionWindowController* collectionVC = [[MediaCollectionWindowController alloc] initWithWindowNibName:@"MediaCollectionWindowController"];
            collectionVC.fileURLS = [openPanel URLs];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [collectionVC reloadData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.progressIndicator stopAnimation:self];
                    [collectionVC showWindow:self];
                });
            });
            /*/
            if (self.collectionController)
            {
                [self.collectionController releaseResources];
            }
            self.collectionController = [[MediaCollectionWindowController alloc] initWithCollectionView:self.collectionView];
            self.collectionController.fileURLS = [openPanel URLs];
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self.collectionController reloadData];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.collectionController refreshViews];
                    [self.progressIndicator stopAnimation:self];

                    self.fileMenuItem.enabled = YES;
                    [self.menu update];
                    self.openMenuItem.enabled = YES;
                    self.openMenuItem.hidden = NO;
                    self.transcodeMenuItem.enabled = YES;
                    self.transcodeMenuItem.hidden = NO;
                    [self.fileMenu update];
                });
            });
            //*/
        }
    }];
}

-(IBAction)startProcess:(id)sender {
    SLSSimpleVideoFileFilterWindowController* transcodeWindowController = [[SLSSimpleVideoFileFilterWindowController alloc] initWithWindowNibName:@"SLSSimpleVideoFileFilterWindowController"];
    transcodeWindowController.delegate = self;
    transcodeWindowController.urlStrings = self.collectionController.sourceMediaPaths;
    [transcodeWindowController showWindow:self];
    self.transcodeMenuItem.enabled = NO;
    self.transcodeMenuItem.hidden = YES;
    [self.menu update];
}

-(void) onTranscodingDone:(NSImage *)thumbnail fileURL:(NSString *)fileURL {
    [self.collectionController setMediaThumbnail:thumbnail fileURL:fileURL];
}

-(void) onTranscodingProgress:(float)progress fileURL:(NSString *)fileURL {
    [self.collectionController setMediaTranscodingProgress:progress fileURL:fileURL];
}

-(void) onAllTranscodingDone:(SLSSimpleVideoFileFilterWindowController*)controller {
    [controller close];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    self.fileMenuItem = [self.menu itemWithTitle:@"File"];
    self.openMenuItem = [self.fileMenu itemWithTitle:@"Open..."];
    self.transcodeMenuItem = [self.fileMenu itemWithTitle:@"Transcode All"];
    self.transcodeMenuItem.enabled = NO;
    self.transcodeMenuItem.hidden = YES;
    [self.menu update];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
