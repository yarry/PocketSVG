//
//  PocketSVGTests_Mac.m
//  PocketSVGTests-Mac
//
//  Created by Yaroslav Ponomarenko on 09/03/2018.
//  Copyright © 2018 Fjölnir Ásgeirsson. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <PocketSVG/PocketSVG.h>

static const int pixelTolerance = 12;
static const int channelTolerance = 8;
static const size_t bytesPerPixel = 4;
static const size_t borderPadding = 1;

@interface ImageRenderTests : XCTestCase

@end

@implementation ImageRenderTests

- (void)testBezierCurve {
    XCTAssert([self matchRenderingOf:@"BezierCurve"]);
}

- (void)testIceland {
    XCTAssert([self matchRenderingOf:@"iceland"]);
}

- (void)testArcFill {
    XCTAssert([self matchRenderingOf:@"ArcFill"]);
}

- (void)testArcSweep {
    XCTAssert([self matchRenderingOf:@"ArcSweep"]);
}

- (BOOL)matchRenderingOf:(NSString *)svgName {

    NSURL *referenceImageURL = [[NSBundle bundleForClass:[self class]] URLForResource:svgName withExtension:@"png"];
    NSURL *svgURL = [[NSBundle bundleForClass:[self class]] URLForResource:svgName withExtension:@"svg"];

    CGDataProviderRef dataProvider = CGDataProviderCreateWithURL((__bridge CFURLRef) referenceImageURL);
    CGImageRef referenceImage = CGImageCreateWithPNGDataProvider(dataProvider, NULL, NO, kCGRenderingIntentDefault);
    CGDataProviderRelease(dataProvider);

    size_t imageWidth = CGImageGetWidth(referenceImage);
    size_t imageHeight = CGImageGetHeight(referenceImage);

    size_t width = CGImageGetWidth(referenceImage) + borderPadding * 2;
    size_t height = CGImageGetHeight(referenceImage) + borderPadding * 2;

    SVGLayer *svgLayer = [[SVGLayer alloc] initWithContentsOfURL:svgURL];
    CGRect renderRect = CGRectMake(borderPadding, borderPadding, imageWidth, imageHeight);
    CGRect contextRect = CGRectMake(0, 0, width, height);
    svgLayer.frame = renderRect;
    CALayer *renderLayer = [[CALayer alloc] init];
    renderLayer.frame = contextRect;
    [renderLayer addSublayer:svgLayer];
    [renderLayer layoutIfNeeded];

    size_t bytesPerRow = bytesPerPixel * width;

    uint8_t *bitmapBuffer = malloc(bytesPerRow * height);
    CGContextRef bitmapContext = CGBitmapContextCreate(
            bitmapBuffer,
            width, height, 8, bytesPerRow,
            CGColorSpaceCreateDeviceRGB(),
            kCGImageAlphaPremultipliedFirst);

    CGContextSetRGBFillColor(bitmapContext, 1.0f, 1.0f, 1.0f, 1.0f);
    CGContextFillRect(bitmapContext, contextRect);

    [renderLayer renderInContext:bitmapContext];

    [self debugSaveContext:bitmapContext named:@"rendered.png"];

    CGContextRelease(bitmapContext);

    uint8_t *referenceBuffer = malloc(bytesPerRow * height);
    CGContextRef referenceContext = CGBitmapContextCreate(
            referenceBuffer,
            width, height, 8, bytesPerRow,
            CGColorSpaceCreateDeviceRGB(),
            kCGImageAlphaPremultipliedFirst);


    CGContextSetRGBFillColor(referenceContext, 1.0f, 1.0f, 1.0f, 1.0f);
    CGContextFillRect(referenceContext, contextRect);

    // flip image vertically
    CGContextTranslateCTM(referenceContext, 0, height);
    CGContextScaleCTM(referenceContext, 1.0, -1.0);

    CGContextDrawImage(referenceContext, renderRect, referenceImage);

    [self debugSaveContext:referenceContext named:@"reference.png"];

    CGContextRelease(referenceContext);
    CGImageRelease(referenceImage);

    int diffentPixelsCount = 0;
    int shiftedPixelsCount = 0;

    for (int y = borderPadding; y < imageHeight; ++y) {
        for (int x = borderPadding; x < imageWidth; ++x) {

            BOOL pixelDiffrent = [self comparePixels:bytesPerRow bitmapBuffer:bitmapBuffer referenceBuffer:referenceBuffer y:y x:x];

            if (pixelDiffrent) {
                BOOL pixelShifted = NO;
                pixelShifted |= ![self comparePixels:bytesPerRow bitmapBuffer:bitmapBuffer referenceBuffer:referenceBuffer y:y + 1 x:x - 1];
                pixelShifted |= ![self comparePixels:bytesPerRow bitmapBuffer:bitmapBuffer referenceBuffer:referenceBuffer y:y + 1 x:x + 0];
                pixelShifted |= ![self comparePixels:bytesPerRow bitmapBuffer:bitmapBuffer referenceBuffer:referenceBuffer y:y + 1 x:x + 1];

                pixelShifted |= ![self comparePixels:bytesPerRow bitmapBuffer:bitmapBuffer referenceBuffer:referenceBuffer y:y + 0 x:x - 1];
                pixelShifted |= ![self comparePixels:bytesPerRow bitmapBuffer:bitmapBuffer referenceBuffer:referenceBuffer y:y + 0 x:x + 1];

                pixelShifted |= ![self comparePixels:bytesPerRow bitmapBuffer:bitmapBuffer referenceBuffer:referenceBuffer y:y - 1 x:x - 1];
                pixelShifted |= ![self comparePixels:bytesPerRow bitmapBuffer:bitmapBuffer referenceBuffer:referenceBuffer y:y - 1 x:x + 0];
                pixelShifted |= ![self comparePixels:bytesPerRow bitmapBuffer:bitmapBuffer referenceBuffer:referenceBuffer y:y - 1 x:x + 1];

                shiftedPixelsCount += pixelShifted;
                if (!pixelShifted) {
                    diffentPixelsCount++;
                }
            }
        }
    }
    NSLog(@"%@ diffrent: %d shifted: %d",svgName,diffentPixelsCount, shiftedPixelsCount);
    return diffentPixelsCount < 4;
}

- (BOOL)comparePixels:(size_t)bytesPerRow
         bitmapBuffer:(const uint8_t *)bitmapBuffer
      referenceBuffer:(const uint8_t *)referenceBuffer
                    y:(int)y x:(int)x {

    const uint8_t *rendered = bitmapBuffer + (bytesPerRow * y + bytesPerPixel * x);
    const uint8_t *reference = referenceBuffer + (bytesPerRow * y + bytesPerPixel * x);

    int pixelDiff = 0;
    for (int c = 0; c < bytesPerPixel; ++c) {
        int channelDiff = abs((int) rendered[c] - (int) reference[c]);
        pixelDiff += channelDiff;
        if (channelDiff > channelTolerance) {
            return YES;
        }
    }
    if (pixelDiff > pixelTolerance) {
        return YES;
    }
    return NO;
}

- (void)debugSaveContext:(CGContextRef)context named:(NSString *)name {
    CGImageRef renderedImage = CGBitmapContextCreateImage(context);
    NSURL *outURL = [NSURL fileURLWithPath:name];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef) outURL, kUTTypePNG, 1, nil);
    CGImageDestinationAddImage(destination, renderedImage, nil);
    CGImageDestinationFinalize(destination);
    CGImageRelease(renderedImage);
}

@end
