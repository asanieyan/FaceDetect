//
//  FCViewController.m
//  FaceCapture
//
//  Created by Arash  Sanieyan on 2013-09-26.
//  Copyright (c) 2013 GeekLab. All rights reserved.
//

#import "FCViewController.h"

@interface FCViewController () <FCVideoRecorderDelegate>
{
    AFHTTPRequestOperationManager *_manager;
}

@end

@implementation FCViewController
{
   
    
}
- (id)init
{
    if ( self = [super init] ) {
        _manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:[NSURL URLWithString:@"http://10.0.1.5:8080"]];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    FCVideoView *videoView  = [FCVideoView videoViewWithCamera:FCVideoFrontCamera];    
    videoView.videoRecorder = [[FCVideoRecorder alloc] init];
    videoView.videoRecorder.delegate = self;
    
    [self.view addSubview:videoView];
}

- (void)videoRecorder:(FCVideoRecorder *)videoRecorder didRecordVideoSegment:(FCVideoSegment *)videoSegment
{
    //we should use socket connect but for now http is okay
    [_manager POST:@"/video" parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
            NSError *error;
            [formData appendPartWithFileURL:videoSegment.fileURL name:@"video" error:&error];
    } success:^(AFHTTPRequestOperation *operation, id responseObject) {
        [videoSegment delete];
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"%@", error);
        [videoSegment delete];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
