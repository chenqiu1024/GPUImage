//
//  IFlyMSC.h
//  msc
//
//  Created by 张剑 on 15/1/14.
//  Copyright (c) 2015年 iflytek. All rights reserved.
//

#ifndef MSC_IFlyMSC_h
#define MSC_IFlyMSC_h

//#import "IFlyAudioSession.h"
#import "IFlyContact.h"
#import "IFlyDataUploader.h"
#import "IFlyDebugLog.h"
#import "IFlyISVDelegate.h"
#import "IFlyISVRecognizer.h"
#import "IFlyRecognizerView.h"
#import "IFlyRecognizerViewDelegate.h"
#import "IFlyResourceUtil.h"
#import "IFlySetting.h"
#import "IFlySpeechConstant.h"
#import "IFlySpeechError.h"
#import "IFlySpeechEvaluator.h"
#import "IFlySpeechEvaluatorDelegate.h"
#import "IFlySpeechEvent.h"
#import "IFlySpeechRecognizer.h"
#import "IFlySpeechRecognizerDelegate.h"
#import "IFlySpeechSynthesizer.h"
#import "IFlySpeechSynthesizerDelegate.h"
#import "IFlySpeechUtility.h"
#import "IFlyUserWords.h"
#import "IFlyPcmRecorder.h"
#import "IFlyVoiceWakeuper.h"
#import "IFlyVoiceWakeuperDelegate.h"

#define APPID_VALUE           @"5b2a5200"
#define URL_VALUE             @""                 // url
#define TIMEOUT_VALUE         @"20000"            // timeout, Unit:ms
#define BEST_URL_VALUE        @"1"                // best_search_url

#define SEARCH_AREA_VALUE     @"Hefei,Anhui"
#define ASR_PTT_VALUE         @"1"
#define VAD_BOS_VALUE         @"5000"
#define VAD_EOS_VALUE         @"1800"
#define PLAIN_RESULT_VALUE    @"1"
#define ASR_SCH_VALUE         @"1"

#endif
