//
//  IFlyFaceDetectResultParser.h
//  GijkPlayer
//
//  Created by DOM QIU on 2018/6/29.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import <Foundation/Foundation.h>

#define KCIFlyFaceResultPointsKey @"POINTS_KEY"
#define KCIFlyFaceResultRectKey   @"RECT_KEY"
#define KCIFlyFaceResultRectOri   @"RECT_ORI"

#pragma mark - keys

extern NSString* const KCIFlyFaceResultBottom;
extern NSString* const KCIFlyFaceResultTop;
extern NSString* const KCIFlyFaceResultLeft;
extern NSString* const KCIFlyFaceResultRight;
extern NSString* const KCIFlyFaceResultPointX;
extern NSString* const KCIFlyFaceResultPointY;
extern NSString* const KCIFlyFaceResultRet;
extern NSString* const KCIFlyFaceResultResult;
extern NSString* const KCIFlyFaceResultPosition;
extern NSString* const KCIFlyFaceResultLandmark;
extern NSString* const KCIFlyFaceResultFace;

extern NSString* const KCIFlyFaceResultSST;
extern NSString* const KCIFlyFaceResultGID;
extern NSString* const KCIFlyFaceResultRST;
extern NSString* const KCIFlyFaceResultVerf;
extern NSString* const KCIFlyFaceResultScore;
extern NSString* const KCIFlyFaceResultAttribute;
extern NSString* const KCIFlyFaceResultPose;
extern NSString* const KCIFlyFaceResultPitch;

#pragma mark - values

extern NSString* const KCIFlyFaceResultReg;
extern NSString* const KCIFlyFaceResultVerify;
extern NSString* const KCIFlyFaceResultDetect;
extern NSString* const KCIFlyFaceResultAlign;

extern NSString* const KCIFlyFaceResultSuccess;


@interface IFlyFaceDetectResultParser : NSObject

+(NSArray*) parseFaceDetectResult:(NSString*)resultString;

@end
