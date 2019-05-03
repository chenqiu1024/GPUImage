//
//  GPUImageOverlapping2InputFilter.h
//  GPUImage
//
//  Created by DOM QIU on 2019/5/3.
//  Copyright © 2019 Brad Larson. All rights reserved.
//

#import "GPUImageTwoInputFilter.h"

NS_ASSUME_NONNULL_BEGIN

@interface GPUImageOverlapping2InputFilter : GPUImageTwoInputFilter

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates;

@end

NS_ASSUME_NONNULL_END
