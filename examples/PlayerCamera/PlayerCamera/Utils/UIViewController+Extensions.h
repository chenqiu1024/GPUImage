//
//  UIViewController+Extensions.h
//  Madv360_v1
//
//  Created by FutureBoy on 11/23/15.
//  Copyright © 2015 Cyllenge. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (Extensions)

@property(nonatomic,copy)NSString * isScreencap;

/**Presnet as Popup Model View*/
+ (void)setPresentationStyleForSelfController:(UIViewController *)selfController presentingController:(UIViewController *)presentingController;

- (void)setPresentationStyle:(UIViewController *)presentingController;

- (UIViewController*) presentingViewControllerWithDegree:(int)degree;

- (void) saveTabBarHidden;
- (void) restoreTabBarHidden;

- (void) saveNaviBarAppearance;
- (void) restoreNaviBarAppearance;

- (void) saveNaviBarHidden;
- (void) restoreNaviBarHidden;

- (void) showActivityIndicatorViewInView:(UIView *)view;
- (void) showActivityIndicatorViewInView:(UIView *)view withText:(NSString*)text;

- (void) dismissActivityIndicatorView;

- (void) showToast:(NSString*)msg handler:(void (^ __nullable)(UIAlertAction *action))handler;
- (void) showToast:(NSString*)msg;

@end
