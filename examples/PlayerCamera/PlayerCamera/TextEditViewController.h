//
//  TextEditViewController.h
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/9.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TextEditViewController : UIViewController

@property (nonatomic, copy) void(^completionHandler)(NSString*);

-(instancetype) initWithText:(NSString*)text;

@end
