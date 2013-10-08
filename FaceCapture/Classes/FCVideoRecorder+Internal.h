//
//  FCVideoRecorder+Internal.h
//  FaceCapture
//

#import "FCVideoRecorder.h"

@interface FCVideoSegment()

@property(nonatomic,strong) NSURL *fileURL;
@property(nonatomic,assign) CMTime frameTime;

@end

@interface FCVideoRecorder ()

- (void)recordFrame:(CVPixelBufferRef)frame framePerSecond:(NSUInteger)framePerSecond;
- (void)finishRecording;

@property(nonatomic,assign) NSUInteger fileCounter;
@property(nonatomic,assign) NSUInteger frameCounter;
@property(nonatomic,strong) AVAssetWriterInput *assetWriterInput;
@property(nonatomic,strong) AVAssetWriter *assetWriter;
@property(nonatomic,strong) AVAssetWriterInputPixelBufferAdaptor *pBufferAdapter;

@end
