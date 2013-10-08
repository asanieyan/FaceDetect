//
//  FCVideoView.h
//  FaceCapture
//

#import <UIKit/UIKit.h>

@class FCVideoView;

typedef enum FCVideoCameraType {
  
  FCVideoFrontCamera = AVCaptureDevicePositionFront,
  FCVideoBackCamera  = AVCaptureDevicePositionBack
  
} FCVideoCameraType;

@interface FCVideoView : UIView

//instantiate with a camera
+ (instancetype)videoViewWithCamera:(FCVideoCameraType)cameraType;

//default to front camera
@property(nonatomic,assign) FCVideoCameraType cameraType;

//video recorder
@property(nonatomic,strong) FCVideoRecorder *videoRecorder;

@end
