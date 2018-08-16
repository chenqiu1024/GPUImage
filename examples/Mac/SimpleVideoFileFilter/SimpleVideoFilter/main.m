//
//  main.m
//  SimpleVideoFilter
//
//  Created by Janie Clayton-Hasz on 1/8/15.
//  Copyright (c) 2015 Red Queen Coder, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SLSSimpleVideoFileFilterWindowController.h"

int main(int argc, const char * argv[]) {
    if (argc > 1)
    {
        g_inputMP4Path = [NSString stringWithUTF8String:argv[1]];
    }
    return NSApplicationMain(argc, argv);
}
