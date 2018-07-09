//
//  TextEditViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/9.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "TextEditViewController.h"

@interface TextEditViewController ()
{
    NSString* _text;
}

@property (nonatomic, strong) UITextField* textField;

@end

@implementation TextEditViewController

-(instancetype) initWithText:(NSString*)text {
    if (self = [super init])
    {
        _text = text;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.5];
    self.view.opaque = NO;
    
    _textField = [[UITextField alloc] initWithFrame:CGRectMake(self.view.bounds.size.width/4, self.view.bounds.size.height/8, self.view.bounds.size.width/2, self.view.bounds.size.height * 0.75)];
    [self.view addSubview:_textField];
    _textField.backgroundColor = [UIColor whiteColor];
    _textField.text = _text;
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
