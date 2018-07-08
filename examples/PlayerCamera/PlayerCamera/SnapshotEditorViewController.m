//
//  SnapshotEditorViewController.m
//  GijkPlayer
//
//  Created by DOM QIU on 2018/7/2.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "SnapshotEditorViewController.h"
#import "FilterCollectionView.h"
#import "iflyMSC/IFlyFaceDetector.h"
#import "iflyMSC/IFlyFaceSDK.h"
#import "ISRDataHelper.h"
#import "IFlyFaceDetectResultParser.h"
#import "WXApiRequestHandler.h"
#import "WeiXinConstant.h"
#import "UIImage+Share.h"
#import "UINavigationBar+Translucent.h"
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
{
    
}

@property (nonatomic, strong) UIElementsView* uiElementsView;
@property (nonatomic, strong) GPUImagePicture* picture;
@property (nonatomic, strong) GPUImageFilter* filter;

@property (nonatomic, strong) IBOutlet FilterCollectionView* filterCollectionView;
@property (nonatomic, strong) IBOutlet UIButton* filterButton;

@property (nonatomic, strong) IBOutlet UINavigationBar* navBar;
@property (nonatomic, strong) IBOutlet UINavigationItem* navItem;

-(IBAction)onFilterButtonPressed:(id)sender;

@end

@implementation SnapshotEditorViewController

@synthesize uiElementsView;

-(void) onDoubleTapped:(UITapGestureRecognizer*)recognizer {
    GPUImageView* gpuImageView = (GPUImageView*)self.view;
    gpuImageView.snapshotCompletion = ^(UIImage* image) {
        if (!image)
            return;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            CGFloat contentScale = self.view.layer.contentsScale;
            CGSize layerSize = CGSizeMake(contentScale * self.view.bounds.size.width,
                                          contentScale * self.view.bounds.size.height);
            CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
            CGContextRef imageContext = CGBitmapContextCreate(NULL, (int)layerSize.width, (int)layerSize.height, 8, (int)layerSize.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

            CGContextDrawImage(imageContext, CGRectMake(0, 0, layerSize.width, layerSize.height), image.CGImage);
            
            CGContextScaleCTM(imageContext, contentScale, contentScale);
            [self.uiElementsView.layer renderInContext:imageContext];
            
            UIImage* snapshot = [UIImage imageWithCGImage:CGBitmapContextCreateImage(imageContext) scale:1.0f orientation:UIImageOrientationDownMirrored];
            snapshot = [snapshot imageScaledToFitMaxSize:CGSizeMake(MaxWidthOfImageToShare, MaxHeightOfImageToShare) orientation:UIImageOrientationDownMirrored];
            NSData* data = UIImageJPEGRepresentation(snapshot, 1.0f);
            NSString* fileName = [NSString stringWithFormat:@"snapshot_%f.jpg", [[NSDate date] timeIntervalSince1970]];
            NSString* path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:fileName];
            [data writeToFile:path atomically:YES];
            
            UIImage* thumbImage = [snapshot imageScaledToFitMaxSize:CGSizeMake(snapshot.size.width/2, snapshot.size.height/2) orientation:UIImageOrientationUp];
            ///dispatch_async(dispatch_get_main_queue(), ^{
                BOOL succ = [WXApiRequestHandler sendImageData:data
                                                       TagName:kImageTagName
                                                    MessageExt:kMessageExt
                                                        Action:kMessageAction
                                                    ThumbImage:thumbImage
                                                       InScene:WXSceneTimeline];//WXSceneSession
                NSLog(@"#WX# Send message succ = %d", succ);
                /*
                 NSArray *activityItems = @[data0, data1];
                 UIActivityViewController *activityVC = [[UIActivityViewController alloc]initWithActivityItems:activityItems applicationActivities:nil];
                 [self presentViewController:activityVC animated:TRUE completion:nil];
                 //*/
            ///});
            
            CGContextRelease(imageContext);
            CGColorSpaceRelease(genericRGBColorspace);
        });
    };
    [self.picture processImage];
}

-(void) dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    NSLog(@"sPLVC Next VC begin to load");
    [super viewDidLoad];
    
    UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(dismissSelf)];
    self.navItem.leftBarButtonItem = dismissButtonItem;
    self.navItem.title = @"Picture Edit";
    //*
    [self.navBar makeTranslucent];
    [self setNeedsStatusBarAppearanceUpdate];
    //https://www.jianshu.com/p/fa27ab9fb172
     //*/
    
    _filter = nil;
    
    self.filterCollectionView.hidden = YES;

    // Do any additional setup after loading the view.
    if (!self.image)
        return;
    
    self.view.backgroundColor = [UIColor clearColor];
    
    self.uiElementsView = [[UIElementsView alloc] initWithFrame:self.view.bounds];
    self.uiElementsView.backgroundColor = [UIColor clearColor];
    [self.view insertSubview:self.uiElementsView belowSubview:self.navBar];
    
    UITapGestureRecognizer* tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTapped:)];
    tapRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapRecognizer];
    
    GPUImageView* gpuImageView = (GPUImageView*)self.view;
    gpuImageView.backgroundColor = [UIColor clearColor];
    self.picture = [[GPUImagePicture alloc] initWithImage:self.image];
    [self.picture addTarget:gpuImageView];
    [self.picture processImage];
    
    __weak typeof(self) wSelf = self;
    self.filterCollectionView.filterSelectedHandler = ^(GPUImageFilter* filter) {
        __strong typeof(self) pSelf = wSelf;
        if (!pSelf.filter)
        {
            [pSelf.picture removeTarget:gpuImageView];
        }
        else
        {
            [pSelf.filter removeTarget:gpuImageView];
            [pSelf.picture removeTarget:pSelf.filter];
        }
        
        pSelf.picture = [[GPUImagePicture alloc] initWithImage:pSelf.image];
        if (filter)
        {
            [pSelf.picture addTarget:filter];
            [filter addTarget:gpuImageView];
        }
        else
        {
            [pSelf.picture addTarget:gpuImageView];
        }
        pSelf.filter = filter;
        [pSelf.picture processImage];
        
        //    self.filterButton.hidden = NO;
        //    self.filterCollectionView.hidden = YES;
    };
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        IFlyFaceDetector* faceDetector = [IFlyFaceDetector sharedInstance];
        [faceDetector setParameter:@"1" forKey:@"align"];
        [faceDetector setParameter:@"1" forKey:@"detect"];
        NSString* detectResultString = [faceDetector detectARGB:self.image];
        NSArray* faceDetectResult = [IFlyFaceDetectResultParser parseFaceDetectResult:detectResultString];
        NSLog(@"FaceDetect in (%f, %f) result = '%@', array=%@", self.image.size.width, self.image.size.height, detectResultString, faceDetectResult);
        faceDetectResult = transformFaceDetectResults(faceDetectResult, self.image.size, self.uiElementsView.frame.size, gpuImageView.fillMode);
        self.uiElementsView.personFaces = faceDetectResult;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.uiElementsView setNeedsDisplay];
        });
        
    });
    NSLog(@"sPLVC Next VC finished load");
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

#pragma mark    Filters

-(IBAction)onFilterButtonPressed:(id)sender {
    if (self.filterCollectionView.hidden)
    {
        self.filterCollectionView.hidden = NO;
        self.filterButton.tintColor = [UIColor blueColor];
    }
    else
    {
        self.filterCollectionView.hidden = YES;
        self.filterButton.tintColor = [UIColor whiteColor];
    }
}

@end
