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

CGSize scaleFactor(CGSize sourceSize, CGSize destSize, GPUImageFillModeType fillMode) {
    CGSize s;
    switch (fillMode)
    {
        case kGPUImageFillModeStretch:
            s.width = destSize.width / sourceSize.width;
            s.height = destSize.height / sourceSize.height;
            break;
        case kGPUImageFillModePreserveAspectRatio:
            if (sourceSize.height * destSize.width / sourceSize.width <= destSize.height)
            {
                s.width = s.height = destSize.width / sourceSize.width;
            }
            else
            {
                s.width = s.height = destSize.height / sourceSize.height;
            }
            break;
        case kGPUImageFillModePreserveAspectRatioAndFill:
            if (sourceSize.height * destSize.width / sourceSize.width > destSize.height)
            {
                s.width = s.height = destSize.width / sourceSize.width;
            }
            else
            {
                s.width = s.height = destSize.height / sourceSize.height;
            }
            break;
        default:
            s.width = 1.f;
            s.height = 1.f;
            break;
    }
    return s;
}

CGPoint transformPointByFillMode(CGPoint pointInSource, CGSize sourceSize, CGSize destSize, GPUImageFillModeType fillMode) {
    CGSize s = scaleFactor(sourceSize, destSize, fillMode);
    return CGPointMake(destSize.width / 2 + (pointInSource.x - sourceSize.width / 2) * s.width,
                       destSize.height / 2 + (pointInSource.y - sourceSize.height / 2) * s.height);
}

CGRect transformRectByFillMode(CGRect rectInSource, CGSize sourceSize, CGSize destSize, GPUImageFillModeType fillMode) {
    CGPoint p0 = rectInSource.origin;
    CGPoint p1 = CGPointMake(rectInSource.origin.x + rectInSource.size.width, rectInSource.origin.y + rectInSource.size.height);
    p0 = transformPointByFillMode(p0, sourceSize, destSize, fillMode);
    p1 = transformPointByFillMode(p1, sourceSize, destSize, fillMode);
    return CGRectMake(p0.x, p0.y, p1.x - p0.x, p1.y - p0.y);
}

NSArray* transformFaceDetectResults(NSArray* personFaces, CGSize sourceSize, CGSize destSize, GPUImageFillModeType fillMode) {
    NSMutableArray* ret = [[NSMutableArray alloc] init];
    for (NSDictionary* dicPerson in personFaces)
    {
        NSMutableDictionary* retDictPerson = [[NSMutableDictionary alloc] init];
        [ret addObject:retDictPerson];
        
        if ([dicPerson objectForKey:KCIFlyFaceResultPointsKey])
        {
            NSMutableArray* retPoints = [[NSMutableArray alloc] init];
            [retDictPerson setObject:retPoints forKey:KCIFlyFaceResultPointsKey];
            
            for (NSString* strPoints in [dicPerson objectForKey:KCIFlyFaceResultPointsKey])
            {
                CGPoint p = CGPointFromString(strPoints) ;
                p = transformPointByFillMode(p, sourceSize, destSize, fillMode);
                [retPoints addObject:NSStringFromCGPoint(p)];
            }
        }
        
        BOOL isOriRect = NO;
        if ([dicPerson objectForKey:KCIFlyFaceResultRectOri])
        {
            isOriRect = [[dicPerson objectForKey:KCIFlyFaceResultRectOri] boolValue];
            [retDictPerson setObject:@(isOriRect) forKey:KCIFlyFaceResultRectOri];
        }
        
        if ([dicPerson objectForKey:KCIFlyFaceResultRectKey])
        {
            CGRect rect = CGRectFromString([dicPerson objectForKey:KCIFlyFaceResultRectKey]);
            rect = transformRectByFillMode(rect, sourceSize, destSize, fillMode);
            [retDictPerson setObject:NSStringFromCGRect(rect) forKey:KCIFlyFaceResultRectKey];
        }
    }
    return ret;
}

@interface UIElementsView : UIView
{
    CGContextRef context;
}

@property (nonatomic, strong) NSArray* personFaces;
//@property (nonatomic, assign) CGSize sourceImageSize;
//@property (nonatomic, assign) GPUImageFillModeType fillMode;

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
    CGRect rect = CGRectMake(self.bounds.size.width / 2, self.bounds.size.height / 2, self.bounds.size.width / 2, self.bounds.size.height / 2);
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
                //p = transformPointByFillMode(p, self.sourceImageSize, self.bounds.size, self.fillMode);
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
            //rect = transformRectByFillMode(rect, self.sourceImageSize, self.bounds.size, self.fillMode);
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
@property (nonatomic, strong) GPUImagePicture* picture;

@property (nonatomic, strong) IBOutlet UINavigationBar* navBar;
@property (nonatomic, strong) IBOutlet UINavigationItem* navItem;

@end

@implementation SnapshotEditorViewController

@synthesize uiElementsView;

-(void) onDoubleTapped:(UITapGestureRecognizer*)recognizer {
    GPUImageView* gpuImageView = (GPUImageView*)self.view;
    gpuImageView.snapshotCompletion = ^(UIImage* image) {
        if (image)
        {
            CGFloat contentScale = self.view.layer.contentsScale;
            CGSize layerSize = CGSizeMake(contentScale * self.view.bounds.size.width,
                                          contentScale * self.view.bounds.size.height);
            CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
            CGContextRef imageContext = CGBitmapContextCreate(NULL, (int)layerSize.width, (int)layerSize.height, 8, (int)layerSize.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

            CGContextDrawImage(imageContext, CGRectMake(0, 0, layerSize.width, layerSize.height), image.CGImage);
            
            CGContextScaleCTM(imageContext, contentScale, contentScale);
            [self.uiElementsView.layer renderInContext:imageContext];
            
            UIImage* snapshot = [UIImage imageWithCGImage:CGBitmapContextCreateImage(imageContext) scale:1.0f orientation:UIImageOrientationDownMirrored];
            NSData* data = UIImageJPEGRepresentation(snapshot, 1.f);
            NSString* fileName = [NSString stringWithFormat:@"snapshot_%f.jpg", [[NSDate date] timeIntervalSince1970]];
            NSString* path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:fileName];
            [data writeToFile:path atomically:YES];
            
            CGContextRelease(imageContext);
            CGColorSpaceRelease(genericRGBColorspace);
        }
    };
    [self.picture processImage];
}

-(void) dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(dismissSelf)];
    self.navItem.leftBarButtonItem = dismissButtonItem;
    self.navItem.title = @"Picture Edit";
    //*
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
    [self setNeedsStatusBarAppearanceUpdate];
    //https://www.jianshu.com/p/fa27ab9fb172
     //*/
    
    // Do any additional setup after loading the view.
    if (!self.image)
        return;
    
    IFlyFaceDetector* faceDetector = [IFlyFaceDetector sharedInstance];
    [faceDetector setParameter:@"1" forKey:@"align"];
    [faceDetector setParameter:@"1" forKey:@"detect"];
    NSString* detectResultString = [faceDetector detectARGB:self.image];
    NSArray* faceDetectResult = [IFlyFaceDetectResultParser parseFaceDetectResult:detectResultString];
    NSLog(@"FaceDetect in (%f, %f) result = '%@', array=%@", self.image.size.width, self.image.size.height, detectResultString, faceDetectResult);
    
    GPUImageView* gpuImageView = (GPUImageView*)self.view;
    gpuImageView.backgroundColor = [UIColor clearColor];
    self.picture = [[GPUImagePicture alloc] initWithImage:self.image];
    [self.picture addTarget:gpuImageView];
    [self.picture processImage];
    
    self.uiElementsView = [[UIElementsView alloc] initWithFrame:self.view.bounds];
    self.uiElementsView.backgroundColor = [UIColor clearColor];
    //self.uiElementsView.layer.backgroundColor = [UIColor clearColor].CGColor;
    [self.view insertSubview:self.uiElementsView belowSubview:self.navBar];
    /*
    self.uiElementsView.sourceImageSize = self.image.size;
    /*
    CGSize scale = scaleFactor(self.image.size, self.uiElementsView.frame.size, gpuImageView.fillMode);
    CGAffineTransform t0 = CGAffineTransformMakeTranslation(-self.image.size.width / 2, -self.image.size.height / 2);
    CGAffineTransform s1 = CGAffineTransformMakeScale(scale.width, scale.height);
    CGAffineTransform t2 = CGAffineTransformMakeTranslation(self.uiElementsView.frame.size.width / 2, self.uiElementsView.frame.size.height / 2);
    self.uiElementsView.transform = CGAffineTransformConcat(CGAffineTransformConcat(t2, s1), t0);
    //*/
    //self.uiElementsView.sourceImageSize = self.uiElementsView.frame.size;
    //self.uiElementsView.fillMode = gpuImageView.fillMode;
    faceDetectResult = transformFaceDetectResults(faceDetectResult, self.image.size, self.uiElementsView.frame.size, gpuImageView.fillMode);
    self.uiElementsView.personFaces = faceDetectResult;
    [self.uiElementsView setNeedsDisplay];
    
    UITapGestureRecognizer* tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTapped:)];
    tapRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapRecognizer];
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
