//
//  ImagePlatform.m
//  testFCRN
//
//  Created by Doron Adler on 28/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import "ImagePlatform.h"

@import CoreImage;
@import Accelerate;
@import AVFoundation;

@implementation IMAGE_TYPE (ImagePlatform)

- (NSData*)imageJPEGRepresentationWithCompressionFactor:(CGFloat)compressionFactor {
#ifdef MACOS_TARGET
    NSData *imageData = [self TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:compressionFactor] forKey:NSImageCompressionFactor];
    imageData = [imageRep representationUsingType:NSBitmapImageFileTypeJPEG properties:imageProps];
    return imageData;
#else
    NSData *imageJPEGRepresentation = UIImageJPEGRepresentation(self, compressionFactor);
    return imageJPEGRepresentation;
#endif
}

- (CGImageRef)asCGImageRef {
#ifdef MACOS_TARGET
    CGRect proposedRect = CGRectMake(0.0f, 0.0f, self.size.width, self.size.height);
    CGImageRef imgRef = [self CGImageForProposedRect:&proposedRect context:nil hints:nil];
#else
    CGImageRef imgRef = self.CGImage;
#endif
    
    return imgRef;
}

@end

@interface ImagePlatform () {
    CGColorSpaceRef _colorSpaceRGB;
}

@property (nonatomic, strong) CIContext     *imagePlatformCoreContext;

@end

@implementation ImagePlatform

#pragma mark - init / dealloc

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupCoreContext];
    }
    return self;
}

- (void)dealloc
{
    [self teardownCoreContext];
}

- (void)setupCoreContext {
    
    if (self.imagePlatformCoreContext ==  nil) {
        NSDictionary *options = @{kCIContextWorkingColorSpace   : [NSNull null],
                                  kCIContextUseSoftwareRenderer : @(NO)};
        self.imagePlatformCoreContext = [CIContext contextWithOptions:options];
    }
    
    if (_colorSpaceRGB == NULL) {
        _colorSpaceRGB = CGColorSpaceCreateDeviceRGB();
    }
}

- (void)teardownCoreContext {
    self.imagePlatformCoreContext = nil;
    
    if (_colorSpaceRGB) {
        CGColorSpaceRelease(_colorSpaceRGB);
        _colorSpaceRGB = NULL;
    }
}

- (CGColorSpaceRef) colorSpaceRGB {
    return _colorSpaceRGB;
}

#pragma mark - Pixel buffer reference to image

- (CIImage *)ciImageFromPixelBuffer:(CVPixelBufferRef _Nonnull)cvPixelBufferRef
                   imageOrientation:(UIImageOrientation)imageOrientation {
#ifdef MACOS_TARGET
    CIImage *ciImageBeforeOrientation = nil;
    ciImageBeforeOrientation = [CIImage imageWithCVImageBuffer:cvPixelBufferRef];
    CGImagePropertyOrientation orientation = [self CGImagePropertyOrientationForUIImageOrientation:imageOrientation];
    CIImage *ciImage = [ciImageBeforeOrientation imageByApplyingOrientation:orientation];
    return ciImage;
#else
    return ([CIImage imageWithCVImageBuffer:cvPixelBufferRef]);
#endif
}

- (IMAGE_TYPE*)imageFromCVPixelBufferRef:(CVPixelBufferRef)cvPixelBufferRef
                        imageOrientation:(UIImageOrientation)imageOrientation
{
    IMAGE_TYPE* imageFromCVPixelBufferRef = nil;
    
    CIImage * ciImage = [self ciImageFromPixelBuffer:cvPixelBufferRef imageOrientation:imageOrientation];
    CGRect imageRect = CGRectMake(0, 0,
                                  CVPixelBufferGetWidth(cvPixelBufferRef),
                                  CVPixelBufferGetHeight(cvPixelBufferRef));
    
    CGImageRef imageRef = [self.imagePlatformCoreContext
                           createCGImage:ciImage
                           fromRect:imageRect];
    
    if (imageRef) {
#ifdef MACOS_TARGET
        size_t imageWidth  = CGImageGetWidth(imageRef);
        size_t imageHeight = CGImageGetHeight(imageRef);
        NSSize imageSize = NSMakeSize((CGFloat)imageWidth, (CGFloat)imageHeight);
        
        
        imageFromCVPixelBufferRef = [[IMAGE_TYPE alloc] initWithCGImage:imageRef size:imageSize] ;
#else
        imageFromCVPixelBufferRef = [IMAGE_TYPE imageWithCGImage:imageRef scale:1.0 orientation:imageOrientation];
#endif
        
        CGImageRelease(imageRef);
    }
    
    return imageFromCVPixelBufferRef;
    
}

#pragma mark - Utility - CGImagePropertyOrientation <-> UIImageOrientation convertion

- (CGImagePropertyOrientation) CGImagePropertyOrientationForUIImageOrientation:(UIImageOrientation)uiOrientation {
    switch (uiOrientation) {
    default:
    case UIImageOrientationUp: return kCGImagePropertyOrientationUp;
    case UIImageOrientationDown: return kCGImagePropertyOrientationDown;
    case UIImageOrientationLeft: return kCGImagePropertyOrientationLeft;
    case UIImageOrientationRight: return kCGImagePropertyOrientationRight;
    case UIImageOrientationUpMirrored: return kCGImagePropertyOrientationUpMirrored;
    case UIImageOrientationDownMirrored: return kCGImagePropertyOrientationDownMirrored;
    case UIImageOrientationLeftMirrored: return kCGImagePropertyOrientationLeftMirrored;
    case UIImageOrientationRightMirrored: return kCGImagePropertyOrientationRightMirrored;
    }
}

-(UIImageOrientation) UIImageOrientationForCGImagePropertyOrientation:(CGImagePropertyOrientation)cgOrientation {
    switch (cgOrientation) {
    default:
    case kCGImagePropertyOrientationUp: return UIImageOrientationUp;
    case kCGImagePropertyOrientationDown: return UIImageOrientationDown;
    case kCGImagePropertyOrientationLeft: return UIImageOrientationLeft;
    case kCGImagePropertyOrientationRight: return UIImageOrientationRight;
    case kCGImagePropertyOrientationUpMirrored: return UIImageOrientationUpMirrored;
    case kCGImagePropertyOrientationDownMirrored: return UIImageOrientationDownMirrored;
    case kCGImagePropertyOrientationLeftMirrored: return UIImageOrientationLeftMirrored;
    case kCGImagePropertyOrientationRightMirrored: return UIImageOrientationRightMirrored;
    }
}


#pragma mark - Utility - Pixel buffer

- (void)teardownPixelBuffer:(CVPixelBufferRef*)pPixelBufferRef {
    if (*pPixelBufferRef != NULL) {
        //        GTLog(@"teardownPixelBuffer: \"%@\"", (*pPixelBufferRef));
        CVPixelBufferRelease(*pPixelBufferRef);
        *pPixelBufferRef = NULL;
    }
}

- (BOOL)setupPixelBuffer:(CVPixelBufferRef*)pPixelBufferRef
         pixelFormatType:(OSType)pixelFormatType
                withRect:(CGRect)rect {
    
    if ((rect.size.width <= 0) || (rect.size.height <= 0)) {
        return NO;
    }
    
    if (*pPixelBufferRef != NULL) {
        [self teardownPixelBuffer:pPixelBufferRef];
    }
    
#ifdef MACOS_TARGET
    NSDictionary *pixelBufferAttributes = @{ (NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
                                             (NSString*)kCVPixelBufferOpenGLCompatibilityKey: @YES};
    
#else
    NSDictionary *pixelBufferAttributes = @{ (NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
                                             (NSString*)kCVPixelBufferOpenGLESCompatibilityKey: @YES};
    
#endif
    
    CVReturn cvRet =  CVPixelBufferCreate(kCFAllocatorDefault,
                                          rect.size.width,
                                          rect.size.height,
                                          pixelFormatType,
                                          (__bridge CFDictionaryRef)pixelBufferAttributes,
                                          pPixelBufferRef);
    
    if (cvRet != kCVReturnSuccess)
    {
        NSLog(@"CVPixelBufferCreate failed to create a pixel buffer (\"%d\")", cvRet);
        return NO;
    }
    
    NSLog(@"Done: setupPixelBuffer: \"%@\" withRect: \"{%f, %f, %f, %f}\"", (*pPixelBufferRef), rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    
    return YES;
}

#pragma mark - Depth buffer proccesing

- (CVPixelBufferRef)createPixelBufferFromGrayData:(char *)grayBuff
                                            sizeX:(int)sizeX
                                            sizeY:(int)sizeY {
    CVPixelBufferRef grayImageBuffer = NULL;
    CGRect pixelBufferRect = CGRectMake(0.0f, 0.0f, (CGFloat)sizeX, (CGFloat)sizeY);
    [self setupPixelBuffer:&grayImageBuffer
           pixelFormatType:kCVPixelFormatType_32BGRA
                  withRect:pixelBufferRect];
    
    CVPixelBufferLockBaseAddress(grayImageBuffer, 0);
    uint32 *pRGBA = (uint32 *)CVPixelBufferGetBaseAddress(grayImageBuffer);
    
    const vImage_Buffer grayBuffV = {grayBuff, sizeY, sizeX, sizeX};
    const vImage_Buffer rgbaBuffV = {pRGBA, sizeY, sizeX, sizeX * 4};
    
    vImageConvert_Planar8ToBGRX8888(&grayBuffV, &grayBuffV, &grayBuffV, 0xFF, &rgbaBuffV, (vImage_Flags)0);
    
    CVPixelBufferUnlockBaseAddress(grayImageBuffer, 0);
    return grayImageBuffer;
}

- (IMAGE_TYPE*)createBGRADepthImageFromResultData:(uint8_t *)pData
                                 pixelSizeInBytes:(uint8_t)pixelSizeInBytes
                                            sizeX:(int)sizeX
                                            sizeY:(int)sizeY {
    
    NSAssert((pixelSizeInBytes == 8), @"Expected double sized elements");
    
    char *grayBuff = malloc(sizeY*sizeX*sizeof(char));
    
    double maxVD = 0.;
    double minVD = 0.;
    vDSP_maxvD((const double *)pData, 1, &maxVD, sizeY*sizeX);
    vDSP_minvD((const double *)pData, 1, &minVD, sizeY*sizeX);
    const  double scalar = 255./maxVD;
    double *doubleBuff1 = malloc(sizeY*sizeX*sizeof(double));
    vDSP_vsmulD((const double *)pData, 1, &scalar, doubleBuff1, 1, sizeY*sizeX);
    const double offset = -(scalar * (minVD / 2.));
    double *doubleBuff2 = malloc(sizeY*sizeX*sizeof(double));
    vDSP_vsaddD(doubleBuff1, 1, &offset, doubleBuff2, 1, sizeY*sizeX);
    free(doubleBuff1);
    vDSP_vfix8D(doubleBuff2, 1, grayBuff, 1,  sizeY*sizeX);
    free(doubleBuff2);
        
    CVPixelBufferRef grayImageBuffer = [self createPixelBufferFromGrayData:grayBuff sizeX:sizeX sizeY:sizeY];
    
    free(grayBuff);
    
    IMAGE_TYPE *depthImage32 = [self imageFromCVPixelBufferRef:grayImageBuffer imageOrientation:UIImageOrientationUp];
    
    [self teardownPixelBuffer:&grayImageBuffer];
    
    return depthImage32;
}

- (nullable AVDepthData *)depthDataFromImageData:(nonnull NSData *)imageData {
    AVDepthData *depthData = nil;
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)imageData, NULL);
    if (imageSource) {
        NSDictionary *auxDataDictionary = (__bridge NSDictionary *)CGImageSourceCopyAuxiliaryDataInfoAtIndex(imageSource, 0, kCGImageAuxiliaryDataTypeDisparity);
        if (auxDataDictionary) {
            depthData = [AVDepthData depthDataFromDictionaryRepresentation:auxDataDictionary error:NULL];
        }
        
        CFRelease(imageSource);
    }

    return depthData;
}

//- (IMAGE_TYPE*)addDepthMap:(IMAGE_TYPE*)depthMapImage toExistingImage:(IMAGE_TYPE*)existingImage {
//    IMAGE_TYPE *combinedImage = NULL;
//    
//    NSData *depthMapImageData = [depthMapImage imageJPEGRepresentationWithCompressionFactor:1.0f];
//    //AVDepthData *depthData = [self depthDataFromImageData:depthMapImageData];
//    NSDictionary *auxDict = @{(NSString*)kCGImageAuxiliaryDataInfoData:depthMapImageData,                           (NSString*)kCGImagePropertyAuxiliaryDataType:(NSString*)kCGImageAuxiliaryDataTypeDisparity,
//                              (NSString*)kCGImageAuxiliaryDataInfoMetadata:@{},
//                              (NSString*)kCGImageAuxiliaryDataInfoDataDescription:@{},
//                              (NSString*)kCGImagePropertyExifAuxDictionary:@{(NSString*)kCGImagePropertyOrientation:@(kCGImagePropertyOrientationUp)},
//                              (NSString*)kCGImagePropertyOrientation:@(kCGImagePropertyOrientationUp)
//    };
//    
//    
//    NSMutableData *imageData = [NSMutableData data];
//    CGImageDestinationRef imageDestination =  CGImageDestinationCreateWithData((CFMutableDataRef)imageData, kUTTypeJPEG, 1, NULL);
//    CGImageRef existingImageRef = [existingImage asCGImageRef];
//    CGImageDestinationAddImage(imageDestination, existingImageRef, NULL);
//    CGImageDestinationAddAuxiliaryDataInfo(imageDestination, kCGImageAuxiliaryDataTypeDisparity, (CFDictionaryRef)auxDict);
//
//    if (CGImageDestinationFinalize(imageDestination)) {
//        combinedImage = [[IMAGE_TYPE alloc] initWithData:imageData];
//    }
//    
//    return combinedImage;
//}

#pragma mark - Utility - Crop

- (CGRect)cropRectFromImageSize:(CGSize)imageSize
         withSizeForAspectRatio:(CGSize)sizeForaspectRatio {

    CGRect cropRect = CGRectZero;
    CGFloat inWidth = imageSize.width;
    CGFloat inHeight = imageSize.height;
    
    CGFloat aspectWidth = sizeForaspectRatio.width;
    CGFloat aspectHeight = sizeForaspectRatio.height;
    
    CGFloat rx = inWidth/aspectWidth;           //E.G. 320/312 = 1.0256410256   |   704/312 = 2.2564102564
    CGFloat ry = inHeight/aspectHeight;         //E.G. 240/312 = 0.7692307692   |   576/312 = 1.8461538462
    CGFloat dx = 0.0f;
    CGFloat dy = 0.0f;
    
    if(ry<rx) { //E.G. (320 - 240*312/312)/2 = 40   |   (704 - 576*312/312)/2 = 64
        dx = (inWidth - inHeight*aspectWidth/aspectHeight) / 2.0f;
        CGFloat newWidth  = (inWidth - (dx * 2.0f));
        dy = 0.0f;
        cropRect = CGRectMake(dx, dy, newWidth, inHeight);
    } else {
        dx = 0.0f;
        dy = (inHeight - inWidth*aspectHeight/aspectWidth) / 2.0f;
        CGFloat newHeight  = (inHeight - (dy * 2.0f));
        cropRect = CGRectMake(dx, dy, inWidth, newHeight);
    }
    
    return cropRect;
}

- (IMAGE_TYPE*)cropImage:(IMAGE_TYPE*)image withCropRect:(CGRect)cropRect {
    IMAGE_TYPE *croppedImage = NULL;
    
    CGImageRef inputImageRef = [image asCGImageRef];
    CIImage *ciInputImage = [CIImage imageWithCGImage:inputImageRef];
    CGImageRef imageRef = [self.imagePlatformCoreContext
                          createCGImage:ciInputImage
                          fromRect:cropRect];
       
       if (imageRef) {
   #ifdef MACOS_TARGET
           size_t imageWidth  = CGImageGetWidth(imageRef);
           size_t imageHeight = CGImageGetHeight(imageRef);
           NSSize imageSize = NSMakeSize((CGFloat)imageWidth, (CGFloat)imageHeight);
           
           
           croppedImage = [[IMAGE_TYPE alloc] initWithCGImage:imageRef size:imageSize] ;
   #else
           croppedImage = [IMAGE_TYPE imageWithCGImage:imageRef scale:1.0 orientation:imageOrientation];
   #endif
           
           CGImageRelease(imageRef);
       }
    
    return croppedImage;
}

@end
