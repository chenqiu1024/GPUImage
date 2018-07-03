//
//  IFlyFaceDetectResultParser.m
//  GijkPlayer
//
//  Created by DOM QIU on 2018/6/29.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "IFlyFaceDetectResultParser.h"
#import "iflyMSC/IFlyFaceSDK.h"

#pragma mark - keys

NSString* const KCIFlyFaceResultBottom   = @"bottom";
NSString* const KCIFlyFaceResultTop      = @"top";
NSString* const KCIFlyFaceResultLeft     = @"left";
NSString* const KCIFlyFaceResultRight    = @"right";
NSString* const KCIFlyFaceResultPointX   = @"x";
NSString* const KCIFlyFaceResultPointY   = @"y";
NSString* const KCIFlyFaceResultRet      = @"ret";
NSString* const KCIFlyFaceResultResult   = @"result";
NSString* const KCIFlyFaceResultPosition = @"position";
NSString* const KCIFlyFaceResultLandmark = @"landmark";
NSString* const KCIFlyFaceResultFace     = @"face";

NSString* const KCIFlyFaceResultSST      = @"sst";
NSString* const KCIFlyFaceResultGID      = @"gid";
NSString* const KCIFlyFaceResultRST      = @"rst";
NSString* const KCIFlyFaceResultVerf     = @"verf";
NSString* const KCIFlyFaceResultScore    = @"score";

NSString* const KCIFlyFaceResultAttribute = @"attribute";
NSString* const KCIFlyFaceResultPose     = @"pose";
NSString* const KCIFlyFaceResultPitch    = @"pitch";

#pragma mark - values

NSString* const KCIFlyFaceResultReg      = @"reg";
NSString* const KCIFlyFaceResultVerify   = @"verify";
NSString* const KCIFlyFaceResultDetect   = @"detect";
NSString* const KCIFlyFaceResultAlign    = @"align";

NSString* const KCIFlyFaceResultSuccess  = @"success";

@implementation IFlyFaceDetectResultParser

+(NSString*)parseDetect:(NSDictionary*)positionDict {
    
    if (!positionDict)
        return nil;
    
//    // scale coordinates so they fit in the preview box, which may be scaled
//    CGFloat widthScaleBy = self.previewLayer.frame.size.width / faceImg.height;
//    CGFloat heightScaleBy = self.previewLayer.frame.size.height / faceImg.width;
    
    CGFloat bottom = [[positionDict objectForKey:KCIFlyFaceResultBottom] floatValue];
    CGFloat top = [[positionDict objectForKey:KCIFlyFaceResultTop] floatValue];
    CGFloat left = [[positionDict objectForKey:KCIFlyFaceResultLeft] floatValue];
    CGFloat right = [[positionDict objectForKey:KCIFlyFaceResultRight] floatValue];
    CGRect rectFace = CGRectMake(left, top, right - left, bottom - top);
//    rectFace=rScale(rectFace, widthScaleBy, heightScaleBy);
    return NSStringFromCGRect(rectFace);
    
}

+(NSMutableArray*)parseAlign:(NSDictionary*)landmarkDict {
    if (!landmarkDict)
        return nil;
    
//    // scale coordinates so they fit in the preview box, which may be scaled
//    CGFloat widthScaleBy = self.previewLayer.frame.size.width / faceImg.height;
//    CGFloat heightScaleBy = self.previewLayer.frame.size.height / faceImg.width;
    
    NSMutableArray* arrStrPoints = [NSMutableArray array] ;
    NSEnumerator* keys = [landmarkDict keyEnumerator];
    for(id key in keys)
    {
        id attr = [landmarkDict objectForKey:key];
        if (attr && [attr isKindOfClass:[NSDictionary class]])
        {
            id attr = [landmarkDict objectForKey:key];
            CGFloat x = [[attr objectForKey:KCIFlyFaceResultPointX] floatValue];
            CGFloat y = [[attr objectForKey:KCIFlyFaceResultPointY] floatValue];
            
            CGPoint p = CGPointMake(y,x);
            
//            if(!isFrontCamera){
//                p=pSwap(p);
//                p=pRotate90(p, faceImg.height, faceImg.width);
//            }
//
//            p=pScale(p, widthScaleBy, heightScaleBy);
            
            [arrStrPoints addObject:NSStringFromCGPoint(p)];
        }
    }
    return arrStrPoints;
    
}

+(NSArray*) parseFaceDetectResult:(NSString*)resultString {
    if (!resultString)
        return nil;
    
    @try
    {
        NSError* error;
        NSData* resultData = [resultString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* faceDict = [NSJSONSerialization JSONObjectWithData:resultData options:NSJSONReadingMutableContainers error:&error];
        resultData = nil;
        if (!faceDict)
            return nil;
        
        NSString* faceRet = [faceDict objectForKey:KCIFlyFaceResultRet];
        NSArray* faceArray = [faceDict objectForKey:KCIFlyFaceResultFace];
        faceDict = nil;
        
        int ret=0;
        if (faceRet)
        {
            ret = [faceRet intValue];
        }
        //没有检测到人脸或发生错误
        if (ret || !faceArray || [faceArray count]<1)
        {
            return nil;
        }
        
        //检测到人脸
        NSMutableArray* arrPersons = [NSMutableArray array] ;
        for (id faceInArr in faceArray)
        {
            if (faceInArr && [faceInArr isKindOfClass:[NSDictionary class]])
            {
                NSDictionary* positionDict = [faceInArr objectForKey:KCIFlyFaceResultPosition];
                NSString* rectString = [self parseDetect:positionDict];
                positionDict = nil;
                
                NSDictionary* landmarkDict = [faceInArr objectForKey:KCIFlyFaceResultLandmark];
                NSMutableArray* strPoints = [self parseAlign:landmarkDict];
                landmarkDict = nil;
                
                
                NSMutableDictionary* dictPerson = [NSMutableDictionary dictionary] ;
                if (rectString)
                {
                    [dictPerson setObject:rectString forKey:KCIFlyFaceResultRectKey];
                }
                if(strPoints){
                    [dictPerson setObject:strPoints forKey:KCIFlyFaceResultPointsKey];
                }
                
                strPoints = nil;
                
                [dictPerson setObject:@"0" forKey:KCIFlyFaceResultRectOri];
                [arrPersons addObject:dictPerson] ;
                dictPerson = nil;
            }
        }
        faceArray = nil;
        
        return arrPersons;
    }
    @catch (NSException *exception)
    {
        NSLog(@"prase exception:%@",exception.name);
        return nil;
    }
    @finally {
    }
}

@end
