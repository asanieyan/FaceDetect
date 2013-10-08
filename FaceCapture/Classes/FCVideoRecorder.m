//
//  FCVideoRecorder.m
//  FaceCapture
//


#import "FCVideoRecorder.h"
#import "FCVideoRecorder+Internal.h"

@implementation FCVideoRecorder
{
    NSTimeInterval _secondsPerVideoSegment;
}

- (id)init
{
    if ( self = [super init] ) {    
        _fileCounter  = 0;
        _frameCounter = 0;
        _secondsPerVideoSegment = 10;
    }    
    return self;
}

- (AVAssetWriter*)assetWriter
{
    if ( nil == _assetWriter )
    {
        _fileCounter++;
        [[NSDate date] timeIntervalSince1970];
        NSString *filePath = [NSString stringWithFormat:@"Documents/stream.%d.mp4", _fileCounter];
        NSURL *url         = [NSURL fileURLWithPath:[NSHomeDirectory() stringByAppendingPathComponent:filePath]];
    
        //delete file if exits
        NSError *error = nil;
        [[NSFileManager defaultManager] removeItemAtURL:url error:&error];
    
        self.assetWriter = [[AVAssetWriter alloc]
                                initWithURL:url
                                fileType:AVFileTypeMPEG4
                                error:&error];
        
        [self.assetWriter addInput:self.assetWriterInput];
        [self.assetWriter startWriting];
        [self.assetWriter startSessionAtSourceTime:CMTimeMake(0, 1)];
    }
    return _assetWriter;
}

- (AVAssetWriterInput*)assetWriterInput
{
    if ( nil == _assetWriterInput )
    {    
        NSDictionary *outputSettings =
            [NSDictionary dictionaryWithObjectsAndKeys:

                    [NSNumber numberWithInt:640], AVVideoWidthKey,
                    [NSNumber numberWithInt:480], AVVideoHeightKey,
                    AVVideoCodecH264, AVVideoCodecKey,

                    nil];
            
            self.assetWriterInput = [AVAssetWriterInput
                                           assetWriterInputWithMediaType:AVMediaTypeVideo
                                                          outputSettings:outputSettings];
        
        self.pBufferAdapter = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.assetWriterInput sourcePixelBufferAttributes:@{
                (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCMPixelFormat_32BGRA]
        }];
                
        self.assetWriterInput.expectsMediaDataInRealTime = YES;
    }
    return _assetWriterInput;
}

- (void)recordFrame:(CVPixelBufferRef)frame framePerSecond:(NSUInteger)framePerSecond
{
    _frameCounter++;
    CMTime frameTime = CMTimeMake(_frameCounter, framePerSecond);
    if ( self.assetWriter.status == AVAssetWriterStatusWriting &&
            self.assetWriterInput.readyForMoreMediaData        
    )
    {
        [self.pBufferAdapter appendPixelBuffer:frame withPresentationTime:frameTime];
    }
    //record every 3 seconds
    if ( _frameCounter ==  framePerSecond * _secondsPerVideoSegment )
    {
        __block FCVideoSegment *segment = [FCVideoSegment new];
        segment.fileURL     = self.assetWriter.outputURL;
        segment.frameTime   = CMTimeMake(_frameCounter, framePerSecond);
        _frameCounter = 0;       
        [self.assetWriter finishWritingWithCompletionHandler:^{
            if ( [self.delegate respondsToSelector:@selector(videoRecorder:didRecordVideoSegment:)]) {
                [self.delegate videoRecorder:self didRecordVideoSegment:segment];
            } else {
                [segment delete];
            }
        }];
        self.assetWriter = nil;
    }
}

- (void)finishRecording
{
    _frameCounter = 0;
    [self.assetWriter finishWritingWithCompletionHandler:^{
        
    }];
    self.assetWriter = nil;
}

@end


@implementation FCVideoSegment

- (void)delete
{
    NSError *error = nil;
    [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:&error];
}

@end