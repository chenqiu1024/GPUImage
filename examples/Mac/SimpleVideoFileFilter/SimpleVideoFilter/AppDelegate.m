#import "AppDelegate.h"
#import <GPUImage/GPUImage.h>

#import "bef_effect_api.h"

extern char* modelFinder(void* effectHandle, const char* dirPath, const char* modelName);

GLuint createTexture(int width, int height)
{
    GLuint _texture = 0;;
//    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &_texture);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    // This is necessary for non-power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, 0);
    glBindTexture(GL_TEXTURE_2D, 0);
    return _texture;
}

void testEffect(GLint inputTexture, GLint outputTexture, bool createContext)
{
    const int width = 720, height = 1280;
    if (createContext)
    {
//        NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
//            NSOpenGLPFADoubleBuffer,
//            NSOpenGLPFAAccelerated, 0,
//            0
//        };
        NSOpenGLPixelFormatAttribute pixelFormatAttributes[] = {
                    NSOpenGLPFADoubleBuffer, NSOpenGLPFADepthSize, 24,
                    NSOpenGLPFAAllowOfflineRenderers,
                    // Must specify the 3.2 Core Profile to use OpenGL 3.2
                    NSOpenGLPFAOpenGLProfile,
                     NSOpenGLProfileVersion3_2Core,
//                    NSOpenGLProfileVersion4_1Core,
                    0};
        NSOpenGLPixelFormat* pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:pixelFormatAttributes];
        NSOpenGLContext* glCtx = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:nil];
        [glCtx makeCurrentContext];
    }
    
    bef_effect_result_t result;
    bef_effect_handle_t _effectHandle = NULL;
    if (NULL == _effectHandle)
    {
        result = bef_effect_create_handle(&_effectHandle, false);
        NSLog(@"result of bef_effect_create_handle() = %d", result);
        bef_effect_use_pipeline_processor(_effectHandle, false);
        bef_effect_set_render_api(_effectHandle, bef_render_api_gles30);
        bef_effect_init_with_resource_finder_v2(_effectHandle, width, height, modelFinder, NULL ,"MacOS");

    //    bef_effect_composer_set_mode(_effectHandle, 1, 0);//A+B+C
        bef_effect_set_camera_device_position(_effectHandle, bef_camera_position_front);

        bool enable_new_algorithm = true;
        bef_effect_config_ab_value("enable_new_algorithm_system", &enable_new_algorithm, BEF_AB_DATA_TYPE_BOOL);
    }
    
    if (inputTexture < 0)
    {
        inputTexture = createTexture(width, height);
    }
    if (outputTexture < 0)
    {
        outputTexture = createTexture(width, height);
    }
    
    double timestamp = 0.0;///!!!CMTimeGetSeconds(frameTime);
    result = bef_effect_set_width_height(_effectHandle, width, height);//设定处理宽高给effect
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
//    testEffect(-1, -1, true);///!!!
    simpleVideoFileFilterWindowController = [[SLSSimpleVideoFileFilterWindowController alloc] initWithWindowNibName:@"SLSSimpleVideoFileFilterWindowController"];
    [simpleVideoFileFilterWindowController showWindow:self];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

@end
