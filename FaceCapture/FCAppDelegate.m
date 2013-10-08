//
//  FCAppDelegate.m
//  FaceCapture
//

#import "FCAppDelegate.h"

@interface FCAppDelegate() <AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation FCAppDelegate
{
    AVCaptureSession *_session;
    AVCaptureStillImageOutput *_stillOutput;
    CIDetector *_detector;
    AVCaptureVideoPreviewLayer *_previewLayer;
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [FCViewController new];
    [self.window addSubview:self.window.rootViewController.view];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    return YES;
    
    _detector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:@{
        CIDetectorAccuracy:CIDetectorAccuracyLow
    }];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    __block AVCaptureDevice *device = nil;
    [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] enumerateObjectsUsingBlock:^(AVCaptureDevice *obj, NSUInteger idx, BOOL *stop) {
        if ( obj.position == AVCaptureDevicePositionFront ) {
            *stop = true;
            device = obj;
        }
    }];    
    NSAssert(device, @"No camera available");
    _session   = [[AVCaptureSession alloc] init];
    _session.sessionPreset = AVCaptureSessionPreset640x480;
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device
        error:&error];
    
    NSAssert(input, @"%@", error);
    [_session addInput:input];
    
    
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    dispatch_queue_t videoQueue = dispatch_queue_create("io.geeklab.videoQueue", nil);
    [output setSampleBufferDelegate:self queue:videoQueue];
    
    output.videoSettings =
                [NSDictionary dictionaryWithObject:
                    [NSNumber numberWithInt:kCMPixelFormat_32BGRA]
                    forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    [output setAlwaysDiscardsLateVideoFrames:YES];
    
    
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    connection.enabled = YES;
//    connection.videoOrientation = AVCaptureVideoOrientationPortrait;
//    connection.videoMinFrameDuration = CMTimeMake(1,15);

    [_session addOutput:output];
    
    _stillOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = @{ AVVideoCodecKey : AVVideoCodecJPEG};
    [_stillOutput setOutputSettings:outputSettings];
    [_session addOutput:_stillOutput];
    
    _previewLayer= [AVCaptureVideoPreviewLayer layerWithSession:_session];
    _previewLayer.frame = self.window.bounds;
    [self.window.layer addSublayer:_previewLayer];
    [_session startRunning];    
    self.window.backgroundColor = [UIColor whiteColor];
    
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


- (void)captureOutput:(AVCaptureVideoDataOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection

{
    // get the image
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
    if (attachments) {
        CFRelease(attachments);
    }
    
    // make sure your device orientation is not locked.
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
 
    NSDictionary *imageOptions = nil;
    
    imageOptions = [NSDictionary dictionaryWithObject:[self exifOrientation:curDeviceOrientation]
                                               forKey:CIDetectorImageOrientation];
 
    NSArray *features = [_detector featuresInImage:ciImage
                                                   options:imageOptions];
    
    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
	CGRect cleanAperture = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);

	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self drawFaces:features 
            forVideoBox:cleanAperture 
            orientation:curDeviceOrientation];
	});
}

- (void)drawFaces:(NSArray *)features 
      forVideoBox:(CGRect)clearAperture 
      orientation:(UIDeviceOrientation)orientation
{
	NSArray *sublayers = [NSArray arrayWithArray:[_previewLayer sublayers]];
	NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
	NSInteger featuresCount = [features count], currentFeature = 0;

	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];

	// hide all the face layers
	for ( CALayer *layer in sublayers ) {
		if ( [[layer name] isEqualToString:@"FaceLayer"] )
			[layer setHidden:YES];
	}	

	if ( featuresCount == 0 ) {
		[CATransaction commit];
		return; // early bail.
	}
    
	CGSize parentFrameSize = [_previewLayer frame].size;
	NSString *gravity = [_previewLayer videoGravity];
	BOOL isMirrored = [_previewLayer isMirrored];
	CGRect previewBox = [self videoPreviewBoxForGravity:gravity
                                                        frameSize:parentFrameSize 
                                                     apertureSize:clearAperture.size];

	for ( CIFaceFeature *ff in features ) {
		// find the correct position for the square layer within the previewLayer
		// the feature box originates in the bottom left of the video frame.
		// (Bottom right if mirroring is turned on)
		CGRect faceRect = [ff bounds];
        
		// flip preview width and height
		CGFloat temp = faceRect.size.width;
		faceRect.size.width = faceRect.size.height;
		faceRect.size.height = temp;
		temp = faceRect.origin.x;
		faceRect.origin.x = faceRect.origin.y;
		faceRect.origin.y = temp;
		// scale coordinates so they fit in the preview box, which may be scaled
		CGFloat widthScaleBy = previewBox.size.width / clearAperture.size.height;
		CGFloat heightScaleBy = previewBox.size.height / clearAperture.size.width;
		faceRect.size.width *= widthScaleBy;
		faceRect.size.height *= heightScaleBy;
		faceRect.origin.x *= widthScaleBy;
		faceRect.origin.y *= heightScaleBy;
        
		if ( isMirrored )
			faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
		else
			faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);

		CALayer *featureLayer = nil;

		// re-use an existing layer if possible
		while ( !featureLayer && (currentSublayer < sublayersCount) ) {
			CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
			if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
				featureLayer = currentLayer;
				[currentLayer setHidden:NO];
			}
		}

		// create a new one if necessary
		if ( !featureLayer ) {
			featureLayer = [[CALayer alloc]init];
//			featureLayer.contents = (id)self.borderImage.CGImage;
			[featureLayer setName:@"FaceLayer"];
            featureLayer.borderColor = [UIColor blueColor].CGColor;
            featureLayer.borderWidth = 5;
			[_previewLayer addSublayer:featureLayer];
			featureLayer = nil;
		}
		[featureLayer setFrame:faceRect];
//
//		switch (orientation) {
//			case UIDeviceOrientationPortrait:
//				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
//				break;
//			case UIDeviceOrientationPortraitUpsideDown:
//				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
//				break;
//			case UIDeviceOrientationLandscapeLeft:
//				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
//				break;
//			case UIDeviceOrientationLandscapeRight:
//				[featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
//				break;
//			case UIDeviceOrientationFaceUp:
//			case UIDeviceOrientationFaceDown:
//			default:
//				break; // leave the layer in its last known orientation
//		}
		currentFeature++;
	}

	[CATransaction commit];
}

- (CGRect)videoPreviewBoxForGravity:(NSString *)gravity
                          frameSize:(CGSize)frameSize 
                       apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }

	CGRect videoBox;
	videoBox.size = size;
	if (size.width < frameSize.width)
		videoBox.origin.x = (frameSize.width - size.width) / 2;
	else
		videoBox.origin.x = (size.width - frameSize.width) / 2;

	if ( size.height < frameSize.height )
		videoBox.origin.y = (frameSize.height - size.height) / 2;
	else
		videoBox.origin.y = (size.height - frameSize.height) / 2;
    
	return videoBox;
}

- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
 
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
 
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
 
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
 
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
      bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
 
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
 
    // Create an image object from the Quartz image
    UIImage *image = [UIImage imageWithCGImage:quartzImage];
 
    // Release the Quartz image
    CGImageRelease(quartzImage);
 
    return (image);
}

- (NSNumber *) exifOrientation: (UIDeviceOrientation) orientation
{
	int exifOrientation;
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants. 
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
	enum {
		PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
		PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.  
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.  
		PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.  
		PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.  
		PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.  
		PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.  
		PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.  
	};

	switch (orientation) {
		case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
			exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
			break;
		case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;            
			break;
		case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
			exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
			break;
		case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
		default:
			exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
			break;
	}
    return [NSNumber numberWithInt:exifOrientation];
}
    
    
- (void)captureImage
{
    AVCaptureConnection *connection = [_stillOutput connectionWithMediaType:AVMediaTypeVideo];
    [_stillOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            NSLog(@"%@", @"Captured");
    }];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
//    NSLog(@"%@", @"Dropped");
//    NSLog(@"%@", NSStringFromSelector(_cmd));
}

@end
