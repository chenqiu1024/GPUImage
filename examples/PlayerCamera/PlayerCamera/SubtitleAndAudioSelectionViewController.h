//
//  SubtitleAndAudioSelectionViewController.h
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/8.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SubtitleAndAudioSelectionViewController : UITableViewController

-(void) setDataSource:(NSDictionary*)mediaMeta;

- (instancetype)initWithStyle:(UITableViewStyle)style dataSource:(NSDictionary*)mediaMeta selectedAudioStream:(NSInteger)selectedAudioStream selectedSubtitleStream:(NSInteger)selectedSubtitleStream selectedHandler:(void(^)(NSInteger))selectedHandler completion:(void(^)())completion;

@end

