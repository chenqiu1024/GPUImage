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
#import "PhotoLibraryHelper.h"
#import <GPUImage.h>
#import <AssetsLibrary/ALAssetsLibrary.h>

#define DictateLabelBottomMargin 6.0f

//#define USE_FACE_DETECT

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
    UIColor* WXGreenColor;
}
#ifdef USE_FACE_DETECT
@property (nonatomic, strong) UIElementsView* uiElementsView;
#endif
@property (nonatomic, strong) GPUImagePicture* picture;

@property (nonatomic, weak) IBOutlet UIView* overlayView;
@property (nonatomic, weak) IBOutlet UINavigationItem* navItem;
@property (nonatomic, weak) IBOutlet UINavigationBar* navBar;

@property (nonatomic, weak) IBOutlet UIToolbar* toolbar;
@property (nonatomic, weak) IBOutlet FilterCollectionView* filterCollectionView;

@property (nonatomic, weak) IBOutlet UILabel* dictateLabel;
@property (nonatomic, weak) IBOutlet UIBarButtonItem* dictateButtonItem;

@property (nonatomic, assign) CGSize snapshotScreenSize;

@property (nonatomic, strong) GPUImageFilter* filter;
@property (nonatomic, weak) IBOutlet GPUImageView* filterView;

@property (nonatomic, strong) IFlySpeechRecognizer* speechRecognizer;
@property (nonatomic, copy) NSString* speechRecognizerResultString;

-(IBAction)onDictateButtonPressed:(id)sender;

-(IBAction)onTypeButtonPressed:(id)sender;

-(IBAction)onClickOverlay:(id)sender;

-(void) initSpeechRecognizer;
-(BOOL) startSpeechRecognizer;
-(void) stopSpeechRecognizer;
-(void) releaseSpeechRecognizer;

-(void) updateDictateLabelText;

@end

@implementation SnapshotEditorViewController
#ifdef USE_FACE_DETECT
@synthesize uiElementsView;
#endif
-(void) setControlsHidden:(BOOL)hidden {
    self.navBar.hidden = hidden;
    self.toolbar.hidden = hidden;
    self.filterCollectionView.hidden = hidden;
    [self setNeedsStatusBarAppearanceUpdate];
}

-(void) hideControls {
    [self setControlsHidden:YES];
}

-(IBAction)onClickOverlay:(id)sender {
    if (self.navBar.isHidden)
    {
        [self setControlsHidden:NO];
    }
    else
    {
        [self setControlsHidden:YES];
    }
}
/*
-(void) onDoubleTapped:(UITapGestureRecognizer*)recognizer {
    self.filterView.snapshotCompletion = ^(UIImage* image) {
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
///////////
                 NSArray *activityItems = @[data0, data1];
                 UIActivityViewController *activityVC = [[UIActivityViewController alloc]initWithActivityItems:activityItems applicationActivities:nil];
                 [self presentViewController:activityVC animated:TRUE completion:nil];
            
            CGContextRelease(imageContext);
            CGColorSpaceRelease(genericRGBColorspace);
        });
    };
    [self.picture processImage];
}
//*/
#pragma mark - View lifecycle

-(void) applicationDidBecomeActive:(id)sender {
    if (self.dictateButtonItem.tag == 1)
    {
        [self initSpeechRecognizer];
        [self startSpeechRecognizer];
    }
}

-(void) applicationWillResignActive:(id)sender {
    if (self.dictateButtonItem.tag == 1)
    {
        [self stopSpeechRecognizer];
        [self releaseSpeechRecognizer];
    }
}

-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL) prefersStatusBarHidden {
    return NO;///!!!self.navBar.hidden;
}

-(UIStatusBarStyle) preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

-(void) dismissSelf:(PHAsset*)phAsset {
    [self stopSpeechRecognizer];
    [self releaseSpeechRecognizer];
    [self dismissViewControllerAnimated:YES completion:nil];
    if (self.completionHandler)
    {
        self.completionHandler(phAsset);
    }
}

-(void) dismissSelf {
    [self dismissSelf:nil];
}

-(void) takeSnapshot {
    [self stopSpeechRecognizer];
    [self releaseSpeechRecognizer];
    
    __weak typeof(self) wSelf = self;
    self.filterView.snapshotCompletion = ^(UIImage* image) {
        if (!image)
            return;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(self) pSelf = wSelf;
            [pSelf hideControls];
            pSelf.view.userInteractionEnabled = NO;
            
            AudioServicesPlaySystemSound(1108);
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                CGFloat contentScale = pSelf.filterView.layer.contentsScale;
                //            CGSize layerSize = CGSizeMake(contentScale * pSelf.overlayView.bounds.size.width,
                //                                          contentScale * pSelf.overlayView.bounds.size.height);
                CGSize snapshotSize = CGSizeMake(contentScale * pSelf.snapshotScreenSize.width,
                                              contentScale * pSelf.snapshotScreenSize.height);
                CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
                CGContextRef imageContext = CGBitmapContextCreate(NULL, (int)snapshotSize.width, (int)snapshotSize.height, 8, (int)snapshotSize.width * 4, genericRGBColorspace,  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);

                CGContextSaveGState(imageContext);
                CGContextScaleCTM(imageContext, 1.0, -1.0);
                if (pSelf.snapshotScreenSize.width < pSelf.overlayView.bounds.size.width)
                {
                    CGContextTranslateCTM(imageContext, -(pSelf.snapshotScreenSize.width + pSelf.overlayView.bounds.size.width) * contentScale / 2, 0.f);
                }
                else
                {
                    CGContextTranslateCTM(imageContext, 0.f, -(pSelf.snapshotScreenSize.height + pSelf.overlayView.bounds.size.height) * contentScale / 2);
                }
                CGContextDrawImage(imageContext, CGRectMake(0, 0, pSelf.overlayView.bounds.size.width * contentScale, pSelf.overlayView.bounds.size.height * contentScale), image.CGImage);
                
                CGContextRestoreGState(imageContext);
                CGContextScaleCTM(imageContext, contentScale, -contentScale);
                if (pSelf.snapshotScreenSize.width < pSelf.overlayView.bounds.size.width)
                {
                    CGContextTranslateCTM(imageContext, -(pSelf.snapshotScreenSize.width + pSelf.overlayView.bounds.size.width) / 2, 0.f);
                }
                else
                {
                    CGContextTranslateCTM(imageContext, 0.f, -(pSelf.snapshotScreenSize.height + pSelf.overlayView.bounds.size.height) / 2);
                }
                [pSelf.overlayView.layer renderInContext:imageContext];
                
                UIImage* snapshot = [UIImage imageWithCGImage:CGBitmapContextCreateImage(imageContext) scale:1.0f orientation:UIImageOrientationUp];
                snapshot = [snapshot imageScaledToFitMaxSize:CGSizeMake(MaxWidthOfImageToShare, MaxHeightOfImageToShare) orientation:UIImageOrientationUp];
                NSData* data = UIImageJPEGRepresentation(snapshot, 1.0f);
                NSString* fileName = [NSString stringWithFormat:@"snapshot_%f.jpg", [[NSDate date] timeIntervalSince1970]];
                NSString* path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:fileName];
                [data writeToFile:path atomically:YES];
                
                CGContextRelease(imageContext);
                CGColorSpaceRelease(genericRGBColorspace);
                
                [PhotoLibraryHelper saveImageWithUrl:[NSURL fileURLWithPath:path] collectionTitle:@"CartoonShow" completionHandler:^(BOOL success, NSError* error, NSString* assetId) {
                    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
                    PHAsset* asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil].firstObject;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [pSelf dismissSelf:asset];
                    });
                }];
            });
        });
    };
    [self.picture processImage];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"sPLVC Next VC begin to load");
    //UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRewind target:self action:@selector(dismissSelf)];
    UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"] style:UIBarButtonItemStylePlain target:self action:@selector(dismissSelf)];
    self.navItem.leftBarButtonItem = dismissButtonItem;
    UIBarButtonItem* snapshotButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"snapshot"] style:UIBarButtonItemStylePlain target:self action:@selector(takeSnapshot)];
    self.navItem.rightBarButtonItem = snapshotButtonItem;
    self.navItem.title = NSLocalizedString(@"ImageEdit", @"Image Edit");
    
    //[self.navBar makeTranslucent];
    //[self.navBar setBackgroundAndShadowColor:[UIColor blackColor]];
    //[self.navBar setBackgroundColor:[UIColor blackColor]];
    //[self.navBar setBarTintColor:[UIColor blackColor]];
    //self.navBar.opaque = YES;
    //[self.navBar setTintColor:[UIColor blackColor]];
    [self setNeedsStatusBarAppearanceUpdate];
    
    ///[self.toolbar makeTranslucent];
    //[self.toolbar setBackgroundAndShadowColor:[UIColor blackColor]];
    WXGreenColor = self.dictateButtonItem.tintColor;
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    //    self.navigationController.navigationBarHidden = YES;
    
    //_filterView = [[GPUImageView alloc] initWithFrame:self.overlayView.bounds];
    //_filterView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    //_filterView.transform = CGAffineTransformMakeScale(1.f, -1.f);
    //[self.overlayView addSubview:_filterView];
    _filterView.fillMode = kGPUImageFillModePreserveAspectRatio;
    
    [self.view bringSubviewToFront:self.overlayView];
    //_filterView.userInteractionEnabled = YES;
    //[self.overlayView sendSubviewToBack:_filterView];
    
    self.view.backgroundColor = [UIColor clearColor];
#ifdef USE_FACE_DETECT
    self.uiElementsView = [[UIElementsView alloc] initWithFrame:self.view.bounds];
    self.uiElementsView.backgroundColor = [UIColor clearColor];
    [self.view insertSubview:self.uiElementsView belowSubview:self.overlayView];
/*
    UITapGestureRecognizer* tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTapped:)];
    tapRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:tapRecognizer];
//*/
#endif
    _filterView.backgroundColor = [UIColor clearColor];
    self.picture = [[GPUImagePicture alloc] initWithImage:self.image];
    [self.picture addTarget:_filterView];
    [self.picture processImage];
    self.filter = nil;
    
    __weak typeof(self) wSelf = self;
    self.filterCollectionView.filterSelectedHandler = ^(GPUImageFilter* filter) {
        __strong typeof(self) pSelf = wSelf;
        if (!pSelf.filter)
        {
            [pSelf.picture removeTarget:pSelf.filterView];
        }
        else
        {
            [pSelf.filter removeTarget:pSelf.filterView];
            [pSelf.picture removeTarget:pSelf.filter];
        }
        
        pSelf.picture = [[GPUImagePicture alloc] initWithImage:pSelf.image];
        if (filter)
        {
            [pSelf.picture addTarget:filter];
            [filter addTarget:pSelf.filterView];
        }
        else
        {
            [pSelf.picture addTarget:pSelf.filterView];
        }
        pSelf.filter = filter;
        [pSelf.picture processImage];
    };
#ifdef USE_FACE_DETECT
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        IFlyFaceDetector* faceDetector = [IFlyFaceDetector sharedInstance];
        [faceDetector setParameter:@"1" forKey:@"align"];
        [faceDetector setParameter:@"1" forKey:@"detect"];
        NSString* detectResultString = [faceDetector detectARGB:self.image];
        NSArray* faceDetectResult = [IFlyFaceDetectResultParser parseFaceDetectResult:detectResultString];
        NSLog(@"FaceDetect in (%f, %f) result = '%@', array=%@", self.image.size.width, self.image.size.height, detectResultString, faceDetectResult);
        faceDetectResult = transformFaceDetectResults(faceDetectResult, self.image.size, self.uiElementsView.frame.size, self.filterView.fillMode);
        self.uiElementsView.personFaces = faceDetectResult;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.uiElementsView setNeedsDisplay];
        });
    });
#endif
    self.speechRecognizerResultString = @"";
    [self initSpeechRecognizer];
    [self startSpeechRecognizer];
    
    self.dictateLabel.translatesAutoresizingMaskIntoConstraints = YES;
    
    NSLog(@"sPLVC Next VC finished load");
}

-(void) viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    CGSize imageSize = self.image.size;
    if (kGPUImageFillModeStretch == _filterView.fillMode || kGPUImageFillModePreserveAspectRatioAndFill == _filterView.fillMode)
    {
        _snapshotScreenSize = _filterView.bounds.size;
    }
    else if (kGPUImageFillModePreserveAspectRatio == _filterView.fillMode)
    {
        if (imageSize.height * _filterView.bounds.size.width / imageSize.width <= _filterView.bounds.size.height)
        {
            _snapshotScreenSize = CGSizeMake(_filterView.bounds.size.width, imageSize.height * _filterView.bounds.size.width / imageSize.width);
        }
        else
        {
            _snapshotScreenSize = CGSizeMake(imageSize.width * _filterView.bounds.size.height / imageSize.height, _filterView.bounds.size.height);
        }
    }
    [self updateDictateLabelText];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark    IFLY
-(void) updateDictateLabelText {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.dictateLabel.text = self.speechRecognizerResultString;
        //self.dictateLabel.text = @"Dictate Text Label Test";
        [self.dictateLabel sizeToFit];
        self.dictateLabel.frame = CGRectMake(0, (self.overlayView.bounds.size.height + _snapshotScreenSize.height) / 2 - self.dictateLabel.frame.size.height - DictateLabelBottomMargin, self.overlayView.bounds.size.width, self.dictateLabel.frame.size.height);
    });
}

-(IBAction)onDictateButtonPressed:(id)sender {
    if (self.dictateButtonItem.tag == 1)
    {
        [self stopSpeechRecognizer];
        [self releaseSpeechRecognizer];
        
        self.dictateButtonItem.tintColor = [UIColor lightTextColor];
        self.dictateButtonItem.tag = 0;
    }
    else
    {
        [self initSpeechRecognizer];
        [self startSpeechRecognizer];
        
        self.dictateButtonItem.tintColor = WXGreenColor;
        self.dictateButtonItem.tag = 1;
    }
}

-(void)onTypeButtonPressed:(id)sender {
    self.dictateButtonItem.tag = 1;
    [self onDictateButtonPressed:self.dictateButtonItem];
    //*
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"EditText", @"Edit Text") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
        textField.placeholder = NSLocalizedString(@"EnterText", @"Enter text:");
        textField.text = self.speechRecognizerResultString;
        textField.secureTextEntry = NO;
        textField.frame = CGRectMake(0, 0, 600, 400);
    }];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
        self.speechRecognizerResultString = alert.textFields[0].text;
        [self updateDictateLabelText];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
    /*/
     TextEditViewController* vc = [[TextEditViewController alloc] initWithText:self.speechRecognizerResultString];
     vc.completionHandler = ^(NSString* text) {
     self.speechRecognizerResultString = text;
     self.dictateLabel.text = text;
     };
     [self setPresentationStyle:vc];
     [self presentViewController:vc animated:YES completion:nil];
     //*/
}

-(void) initSpeechRecognizer
{
    //recognition singleton without view
    _speechRecognizer = [IFlySpeechRecognizer sharedInstance];
    
    [_speechRecognizer setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
    
    //set recognition domain
    [_speechRecognizer setParameter:@"iat" forKey:[IFlySpeechConstant IFLY_DOMAIN]];
    
    _speechRecognizer.delegate = self;
    
    if (_speechRecognizer != nil) {
        //set timeout of recording
        [_speechRecognizer setParameter:@"30000" forKey:[IFlySpeechConstant SPEECH_TIMEOUT]];
        //set VAD timeout of end of speech(EOS)
        [_speechRecognizer setParameter:@"3000" forKey:[IFlySpeechConstant VAD_EOS]];
        //set VAD timeout of beginning of speech(BOS)
        [_speechRecognizer setParameter:@"3000" forKey:[IFlySpeechConstant VAD_BOS]];
        //set network timeout
        [_speechRecognizer setParameter:@"20000" forKey:[IFlySpeechConstant NET_TIMEOUT]];
        
        //set sample rate, 16K as a recommended option
        [_speechRecognizer setParameter:@"16000" forKey:[IFlySpeechConstant SAMPLE_RATE]];
        
        //set language
        [_speechRecognizer setParameter:@"zh_cn" forKey:[IFlySpeechConstant LANGUAGE]];
        //set accent
        [_speechRecognizer setParameter:@"mandarin" forKey:[IFlySpeechConstant ACCENT]];
        
        //set whether or not to show punctuation in recognition results
        [_speechRecognizer setParameter:@"1" forKey:[IFlySpeechConstant ASR_PTT]];
        
    }
}

-(void) releaseSpeechRecognizer {
    [_speechRecognizer cancel];
    [_speechRecognizer setDelegate:nil];
    [_speechRecognizer setParameter:@"" forKey:[IFlySpeechConstant PARAMS]];
    _speechRecognizer = nil;
}

-(BOOL) startSpeechRecognizer {
    if(_speechRecognizer == nil)
    {
        [self initSpeechRecognizer];
    }
    
    [_speechRecognizer cancel];
    
    //Set microphone as audio source
    [_speechRecognizer setParameter:IFLY_AUDIO_SOURCE_MIC forKey:@"audio_source"];
    
    //Set result type
    [_speechRecognizer setParameter:@"json" forKey:[IFlySpeechConstant RESULT_TYPE]];
    
    //Set the audio name of saved recording file while is generated in the local storage path of SDK,by default in library/cache.
    [_speechRecognizer setParameter:@"asr.pcm" forKey:[IFlySpeechConstant ASR_AUDIO_PATH]];
    
    [_speechRecognizer setDelegate:self];
    
    BOOL ret = [_speechRecognizer startListening];
    return ret;
}

-(void) stopSpeechRecognizer {
    [_speechRecognizer stopListening];
}

/**
 recognition session completion, which will be invoked no matter whether it exits error.
 error.errorCode =
 0     success
 other fail
 **/
- (void) onCompleted:(IFlySpeechError *) error
{
    NSString* text = [NSString stringWithFormat:@"Error：%d %@", error.errorCode,error.errorDesc];
    NSLog(@"#IFLY# onCompleted :%@",text);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self startSpeechRecognizer];
    });
}

/**
 result callback of recognition without view
 results：recognition results
 isLast：whether or not this is the last result
 **/
- (void) onResults:(NSArray *) results isLast:(BOOL)isLast
{
    NSMutableString* resultString = [[NSMutableString alloc] init];
    NSDictionary* dic = results[0];
    
    for(NSString* key in dic)
    {
        [resultString appendFormat:@"%@",key];
    }
    
    NSString* resultFromJson = [ISRDataHelper stringFromJson:resultString];
    
    self.speechRecognizerResultString = [NSString stringWithFormat:@"%@%@", self.speechRecognizerResultString, resultFromJson];
    //    NSLog(@"#IFLY# resultFromJson=%@",resultFromJson);
    NSLog(@"#IFLY# onResults isLast=%d,_textView.text=%@",isLast, self.speechRecognizerResultString);
    [self updateDictateLabelText];
}

-(void) onError:(IFlySpeechError*)errorCode {
    NSLog(@"#IFLY# onError %@", errorCode.errorDesc);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self startSpeechRecognizer];
    });
    
}

-(void) onVolumeChanged:(int)volume {
    //NSLog(@"#IFLY# in %@ $ %s %d", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __FUNCTION__, __LINE__);
}

-(void) onBeginOfSpeech {
    NSLog(@"#IFLY# in %@ $ %s %d", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __FUNCTION__, __LINE__);
}

-(void) onEndOfSpeech {
    NSLog(@"#IFLY# in %@ $ %s %d", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __FUNCTION__, __LINE__);
}

-(void) onCancel {
    NSLog(@"#IFLY# in %@ $ %s %d", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __FUNCTION__, __LINE__);
}

@end
