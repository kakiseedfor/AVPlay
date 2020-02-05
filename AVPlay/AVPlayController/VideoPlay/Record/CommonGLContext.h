//
//  CommonGLContext.h
//  AVPlay
//
//  Created by kakiYen on 2019/11/13.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CommonGLContext : NSObject

+ (GLuint)textureCacheCVOpenGLES:(CVOpenGLESTextureRef _Nonnull *_Nonnull)textureRef
                 textureCacheRef:(CVOpenGLESTextureCacheRef _Nonnull * _Nonnull)textureCacheRef
                  imageBufferRef:(CVImageBufferRef _Nullable * _Nullable)imageBufferRef
                  internalFormat:(GLint)internalFormat
                           width:(GLsizei)width
                          height:(GLsizei)height
                          format:(GLenum)format
                      planeIndex:(size_t)planeIndex;

- (EAGLContext *)createEAGLContext;

+ (instancetype)shareInstance;

@end

NS_ASSUME_NONNULL_END
