//
//  FCVideoView.m
//  FaceCapture
//

#import "FCVideoView.h"
#import "FCVideoRecorder+Internal.h"

#import <CoreImage/CoreImage.h>

#define FRAMES_PER_SECOND 15

@interface FCVideoView() <AVCaptureVideoDataOutputSampleBufferDelegate, NSStreamDelegate>
{
    BOOL _faceDetectorQueueReady;
    dispatch_queue_t _faceDetectorQueue;
}
//av stuff
@property(nonatomic,strong) AVCaptureSession *captureSession;
@property(nonatomic,strong) CALayer *previewLayer;
@property(nonatomic,strong) AVCaptureDevice *cameraDevice;
@property(nonatomic,strong) CIDetector *faceDetector;


@property(nonatomic,strong) AVCaptureVideoDataOutput *dataOutput;

@property(nonatomic,strong) NSInputStream *is;

@end

@interface FCVideoViewFileTransportOperation :NSOperation

- (id)initWithFileURL:(NSURL*)fileURL;

@property(nonatomic,readonly) NSURL *fileURL;

@end

@implementation FCVideoView

+ (instancetype)videoViewWithCamera:(FCVideoCameraType)cameraType
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    __block AVCaptureDevice *device = nil;
    [devices enumerateObjectsUsingBlock:^(AVCaptureDevice *obj, NSUInteger idx, BOOL *stop) {
        if ( obj.position == cameraType ) {
            device = obj;
            *stop  = YES;
        }
    }];    
    
    if ( device == nil ) {
        return nil;
    }
 
    FCVideoView *view = [FCVideoView new];
    view.cameraDevice   = device;
    
    //create an input
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:view.cameraDevice error:&error];
    if ( !input ) {
        return nil;
    }
    //add input
    [view.captureSession addInput:input];
        
    AVCaptureConnection *conn = [view.dataOutput connectionWithMediaType:AVMediaTypeVideo];
    conn.videoMinFrameDuration = CMTimeMake(1, FRAMES_PER_SECOND);
    
    //create a custom preview layer

    [view.captureSession startRunning];
    return view;    
}

- (id)init
{
    if ( self = [super init] ) {   

        self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:@{
            CIDetectorAccuracy : CIDetectorAccuracyHigh
        }];
        _faceDetectorQueueReady = YES;
        _faceDetectorQueue      = dispatch_queue_create("FaceDetection", nil);
    }
    return self;
}

- (CALayer*)previewLayer
{
    if ( nil == _previewLayer )
    {
        self.previewLayer       = [CALayer layer];
        self.previewLayer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI/2.0f, 0, 0, 1);
        self.previewLayer.contentsGravity = kCAGravityResizeAspectFill;
        self.previewLayer.backgroundColor = [UIColor blueColor].CGColor;
        [self.layer addSublayer:self.previewLayer];
    }
    return _previewLayer;
}

- (void)layoutSubviews
{
    if ( self.superview ) {
        self.frame  = self.superview.bounds;        
        self.previewLayer.frame = self.bounds;
    }
}

- (AVCaptureSession*)captureSession
{
    if ( _captureSession == nil )
    {
        self.captureSession = [[AVCaptureSession alloc] init];
        self.captureSession.sessionPreset = AVCaptureSessionPresetMedium;

        //add video output
        self.dataOutput = [[AVCaptureVideoDataOutput alloc] init];
        dispatch_queue_t videoQueue = dispatch_queue_create("VideoQueue", nil);
        [self.dataOutput setSampleBufferDelegate:self queue:videoQueue];
        self.dataOutput.alwaysDiscardsLateVideoFrames = YES;
        self.dataOutput.videoSettings = @{
            (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCMPixelFormat_32BGRA]
        };    
        [self.captureSession addOutput:self.dataOutput];
    
    }
    return _captureSession;
}


#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    //create pixel buffer
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
//    [self writeBuffer:imageBuffer];
            
    //get baseaddress
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    //realtime reflection using vimage functions    
    unsigned char *outBuff = (unsigned char*)malloc(bytesPerRow * height);
    vImage_Buffer ibuff = { baseAddress, height, width, bytesPerRow};
    vImage_Buffer ubuff = { outBuff, height, width, bytesPerRow};
    vImageVerticalReflect_ARGB8888 (&ibuff, &ubuff, 0);
    
    //@TODO
    //need to the rotate using vimage instead of layer transform
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    //create a bitmap context from the buffer
    CGContextRef newContext = CGBitmapContextCreate(ubuff.data, ubuff.width,ubuff.height,8,ubuff.rowBytes,colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    __block CGImageRef imageRef = CGBitmapContextCreateImage(newContext);
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.previewLayer.contents = (__bridge id)imageRef;
    });
    if ( self.videoRecorder ) {
        [self.videoRecorder recordFrame:imageBuffer framePerSecond:FRAMES_PER_SECOND];
    }
    free(outBuff);
    CGContextRelease(newContext); 
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(imageRef);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);    
}


/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end


@implementation FCVideoViewFileTransportOperation

- (id)initWithFileURL:(NSURL *)fileURL
{
    if ( self = [super init] ) {
        _fileURL = fileURL;
        NSAssert(_fileURL.isFileURL, @"fileURL must be a file");        
    }
    return self;
}

- (void)main
{
    
}

@end