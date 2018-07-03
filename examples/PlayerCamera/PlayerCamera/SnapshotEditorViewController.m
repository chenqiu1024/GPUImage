//
//  SnapshotEditorViewController.m
//  GijkPlayer
//
//  Created by DOM QIU on 2018/7/2.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "SnapshotEditorViewController.h"
#import "iflyMSC/IFlyFaceDetector.h"
#import "iflyMSC/IFlyFaceSDK.h"
#import "ISRDataHelper.h"
#import "IFlyFaceDetectResultParser.h"
#import <GPUImage.h>

#pragma mark    UIElementsView

CGPoint transformPointByFillMode(CGPoint pointInSource, CGSize sourceSize, CGSize destSize, GPUImageFillModeType fillMode) {
    float sx, sy;
    switch (fillMode)
    {
        case kGPUImageFillModeStretch:
            sx = destSize.width / sourceSize.width;
            sy = destSize.height / sourceSize.height;
            break;
        case kGPUImageFillModePreserveAspectRatio:
            if (sourceSize.height * destSize.width / sourceSize.width <= destSize.height)
            {
                sx = sy = destSize.width / sourceSize.width;
            }
            else
            {
                sx = sy = destSize.height / sourceSize.height;
            }
            break;
        case kGPUImageFillModePreserveAspectRatioAndFill:
            if (sourceSize.height * destSize.width / sourceSize.width > destSize.height)
            {
                sx = sy = destSize.width / sourceSize.width;
            }
            else
            {
                sx = sy = destSize.height / sourceSize.height;
            }
            break;
        default:
            sx = 1.f;
            sy = 1.f;
            break;
    }
    return CGPointMake(destSize.width / 2 + (pointInSource.x - sourceSize.width / 2) * sx,
                       destSize.height / 2 + (pointInSource.y - sourceSize.height / 2) * sy);
}

CGRect transformRectByFillMode(CGRect rectInSource, CGSize sourceSize, CGSize destSize, GPUImageFillModeType fillMode) {
    CGPoint p0 = rectInSource.origin;
    CGPoint p1 = CGPointMake(rectInSource.origin.x + rectInSource.size.width, rectInSource.origin.y + rectInSource.size.height);
    p0 = transformPointByFillMode(p0, sourceSize, destSize, fillMode);
    p1 = transformPointByFillMode(p1, sourceSize, destSize, fillMode);
    return CGRectMake(p0.x, p0.y, p1.x - p0.x, p1.y - p0.y);
}

@interface UIElementsView : UIView
{
    CGContextRef context;
}

@property (nonatomic, strong) NSArray* personFaces;
@property (nonatomic, assign) CGSize sourceImageSize;
@property (nonatomic, assign) GPUImageFillModeType fillMode;

@end

@implementation UIElementsView

-(void) drawPointWithPoints:(NSArray*)arrPersons{
    context = UIGraphicsGetCurrentContext();
    if (context)
    {
        CGContextSetRGBFillColor(context, 0.f, 0.75f, 0.25f, 1.f);
        CGContextClearRect(context, self.bounds);
    }
    /*
    CGRect rect = CGRectMake(0, 0, self.bounds.size.width / 2, self.bounds.size.height / 2);
    // 左上
    CGContextMoveToPoint(context, rect.origin.x, rect.origin.y+rect.size.height/8);
    CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y);
    CGContextAddLineToPoint(context, rect.origin.x+rect.size.width/8, rect.origin.y);
    
    //右上
    CGContextMoveToPoint(context, rect.origin.x+rect.size.width*7/8, rect.origin.y);
    CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y);
    CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y+rect.size.height/8);
    
    //左下
    CGContextMoveToPoint(context, rect.origin.x, rect.origin.y+rect.size.height*7/8);
    CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y+rect.size.height);
    CGContextAddLineToPoint(context, rect.origin.x+rect.size.width/8, rect.origin.y+rect.size.height);
    
    
    //右下
    CGContextMoveToPoint(context, rect.origin.x+rect.size.width*7/8, rect.origin.y+rect.size.height);
    CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y+rect.size.height);
    CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y+rect.size.height*7/8);
    /*/
    for (NSDictionary* dicPerson in self.personFaces)
    {
        if ([dicPerson objectForKey:KCIFlyFaceResultPointsKey])
        {
            for (NSString* strPoints in [dicPerson objectForKey:KCIFlyFaceResultPointsKey])
            {
                CGPoint p = CGPointFromString(strPoints) ;
                p = transformPointByFillMode(p, self.sourceImageSize, self.bounds.size, self.fillMode);
                CGContextAddEllipseInRect(context, CGRectMake(p.x - 1 , p.y - 1 , 2 , 2));
            }
        }
        
        BOOL isOriRect = NO;
        if ([dicPerson objectForKey:KCIFlyFaceResultRectOri])
        {
            isOriRect = [[dicPerson objectForKey:KCIFlyFaceResultRectOri] boolValue];
        }
        
        if ([dicPerson objectForKey:KCIFlyFaceResultRectKey])
        {
            CGRect rect = CGRectFromString([dicPerson objectForKey:KCIFlyFaceResultRectKey]);
            rect = transformRectByFillMode(rect, self.sourceImageSize, self.bounds.size, self.fillMode);
            if (isOriRect)
            {//完整矩形
                CGContextAddRect(context,rect);
            }
            else
            { //只画四角
                // 左上
                CGContextMoveToPoint(context, rect.origin.x, rect.origin.y+rect.size.height/8);
                CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width/8, rect.origin.y);
                
                //右上
                CGContextMoveToPoint(context, rect.origin.x+rect.size.width*7/8, rect.origin.y);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y+rect.size.height/8);
                
                //左下
                CGContextMoveToPoint(context, rect.origin.x, rect.origin.y+rect.size.height*7/8);
                CGContextAddLineToPoint(context, rect.origin.x, rect.origin.y+rect.size.height);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width/8, rect.origin.y+rect.size.height);
                
                
                //右下
                CGContextMoveToPoint(context, rect.origin.x+rect.size.width*7/8, rect.origin.y+rect.size.height);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y+rect.size.height);
                CGContextAddLineToPoint(context, rect.origin.x+rect.size.width, rect.origin.y+rect.size.height*7/8);
            }
        }
    }
    //*/
    [[UIColor greenColor] set];
    CGContextSetLineWidth(context, 2);
    CGContextStrokePath(context);
}

- (void)drawRect:(CGRect)rect {
    [self drawPointWithPoints:self.personFaces] ;
}

@end

@interface SnapshotEditorViewController ()

@property (nonatomic, strong) UIElementsView* uiElementsView;

@property (nonatomic, strong) IBOutlet UINavigationBar* navBar;
@property (nonatomic, strong) IBOutlet UINavigationItem* navItem;

@end

@implementation SnapshotEditorViewController

@synthesize uiElementsView;

-(void) dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"] style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    self.navItem.leftBarButtonItem = dismissButtonItem;
    self.navItem.title = @"Picture Editor";
    
    self.navBar.translucent = YES;
    UIColor* translucentColor = [UIColor clearColor];
    CGRect rect = CGRectMake(0, 0, self.view.bounds.size.width, 64);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [translucentColor CGColor]);
    CGContextFillRect(context, rect);
    UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [self.navBar setShadowImage:image];
    [self.navBar setBackgroundImage:image forBarMetrics:UIBarMetricsDefault];
    // https://www.jianshu.com/p/fa27ab9fb172
    
    [self setNeedsStatusBarAppearanceUpdate];
    
    // Do any additional setup after loading the view.
    if (!self.image)
        return;
    
    IFlyFaceDetector* faceDetector = [IFlyFaceDetector sharedInstance];
    NSString* detectResultString = [faceDetector detectARGB:self.image];
    NSArray* faceDetectResult = [IFlyFaceDetectResultParser parseFaceDetectResult:detectResultString];
    NSLog(@"FaceDetect in (%f, %f) result = '%@', array=%@", self.image.size.width, self.image.size.height, detectResultString, faceDetectResult);
    
    GPUImageView* gpuImageView = (GPUImageView*)self.view;
    GPUImagePicture* picture = [[GPUImagePicture alloc] initWithImage:self.image];
    [picture addTarget:gpuImageView];
    [picture processImage];
    
    self.uiElementsView = [[UIElementsView alloc] initWithFrame:self.view.bounds];
    self.uiElementsView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.uiElementsView];
    self.uiElementsView.personFaces = faceDetectResult;
    self.uiElementsView.sourceImageSize = self.image.size;
    self.uiElementsView.fillMode = gpuImageView.fillMode;
    [self.uiElementsView setNeedsDisplay];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
