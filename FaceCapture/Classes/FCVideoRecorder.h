//
//  FCVideoRecorder.h
//  FaceCapture
//


#import <Foundation/Foundation.h>

@class FCVideoRecorder, FCVideoSegment;

@protocol FCVideoRecorderDelegate <NSObject>

- (void)videoRecorder:(FCVideoRecorder*)videoRecorder didRecordVideoSegment:(FCVideoSegment*)videoSegment;

@end

@interface FCVideoSegment : NSObject

@property(nonatomic,readonly) NSURL *fileURL;
@property(nonatomic,readonly) CMTime frameTime;

- (void)delete;

@end

@interface FCVideoRecorder : NSObject

@property(nonatomic,assign) id<FCVideoRecorderDelegate> delegate;

@end
