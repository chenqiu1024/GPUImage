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
        NSMutableArray<NSString* >* paths = [NSMutableArray new];
        for (int iArg=1; iArg<3; ++iArg)
        {
            [paths addObject:[NSString stringWithUTF8String:argv[iArg]]];
        }
        g_inputMP4Paths = [NSArray arrayWithArray:paths];
    }
    return NSApplicationMain(argc, argv);
}
