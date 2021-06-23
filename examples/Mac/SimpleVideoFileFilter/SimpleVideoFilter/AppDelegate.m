#import "AppDelegate.h"
#import <GPUImage/GPUImage.h>

#import "bef_effect_api.h"

extern char* modelFinder(void* effectHandle, const char* dirPath, const char* modelName);

void testEffect()
{
    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFAAccelerated, 0,
        0
    };
//    NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
//                NSOpenGLPFADoubleBuffer, NSOpenGLPFADepthSize, 24,
//                NSOpenGLPFAAllowOfflineRenderers,
//                // Must specify the 3.2 Core Profile to use OpenGL 3.2
//                // NSOpenGLPFAOpenGLProfile,
//                // NSOpenGLProfileVersion3_2Core,
//                0};
    NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
    NSOpenGLContext* glCtx = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
    [glCtx makeCurrentContext];
    
    bef_effect_handle_t _effectHandle = NULL;
    if (NULL == _effectHandle)
    {
        bef_effect_create_handle(&_effectHandle, false);
        bef_effect_use_pipeline_processor(_effectHandle, false);
        bef_effect_set_render_api(_effectHandle, bef_render_api_gles30);
        bef_effect_init_with_resource_finder_v2(_effectHandle, 720, 1280, modelFinder, NULL ,"MacOS");

    //    bef_effect_composer_set_mode(_effectHandle, 1, 0);//A+B+C
        bef_effect_set_camera_device_position(_effectHandle, bef_camera_position_front);

        bool enable_new_algorithm = true;
        bef_effect_config_ab_value("enable_new_algorithm_system", &enable_new_algorithm, BEF_AB_DATA_TYPE_BOOL);
    }
    
    GLint inputTexture = 0;
    GLint outputTexture = 0;
    double timestamp = 0.0;///!!!CMTimeGetSeconds(frameTime);
    bef_effect_result_t result;
    result = bef_effect_set_width_height(_effectHandle, 720, 1280);//设定处理宽高给effect
    NSLog(@"result of bef_effect_set_width_height() = %d", result);
    result = bef_effect_algorithm_texture(_effectHandle, inputTexture, timestamp);//effect调资源包中设定的算法处理得到所需的该帧算法结果
    NSLog(@"result of bef_effect_algorithm_texture() = %d", result);
    result = bef_effect_process_texture(_effectHandle, inputTexture, outputTexture, timestamp);//处理inputTexture叠加特效输出到outputTexture
    NSLog(@"result of bef_effect_process_texture() = %d", result);
}

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
//    testEffect();///!!!
    simpleVideoFileFilterWindowController = [[SLSSimpleVideoFileFilterWindowController alloc] initWithWindowNibName:@"SLSSimpleVideoFileFilterWindowController"];
    [simpleVideoFileFilterWindowController showWindow:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
