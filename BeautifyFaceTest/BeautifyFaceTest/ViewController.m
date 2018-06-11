//
//  ViewController.m
//  BeautifyFaceTest
//
//  Created by Mac on 16/8/9.
//  Copyright © 2016年 . All rights reserved.
//

#import "ViewController.h"
#import <GPUImage/GPUImage.h>
#import "GPUImageBeautifyFilter.h"
#import <Masonry/Masonry.h>

@interface ViewController ()
@property (strong, nonatomic) GPUImageVideoCamera *videoCamera;//视频相机对象
@property (strong, nonatomic) GPUImageView *filterView;//实时预览的view,GPUImageView是响应链的终点，一般用于显示GPUImage的图像。
@property (weak, nonatomic) UIButton *beautifyButton;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    //相机
    self.videoCamera = [[GPUImageVideoCamera alloc] initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionFront];
    self.videoCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    self.videoCamera.horizontallyMirrorRearFacingCamera = YES;
    
    //预览层
    self.filterView = [[GPUImageView alloc] initWithFrame:self.view.frame];
    self.filterView.center = self.view.center;
    [self.view addSubview:self.filterView];
    //添加滤镜到相机
    [self.videoCamera addTarget:self.filterView];
    [self.videoCamera startCameraCapture];
    //设置按钮
    UIButton *beautifyBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    self.beautifyButton = beautifyBtn;
    [self.view addSubview:beautifyBtn];
    self.beautifyButton.backgroundColor = [UIColor whiteColor];
    [self.beautifyButton setTitle:@"开启" forState:UIControlStateNormal];
    [self.beautifyButton setTitle:@"关闭" forState:UIControlStateSelected];
    [self.beautifyButton setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [self.beautifyButton addTarget:self action:@selector(beautify) forControlEvents:UIControlEventTouchUpInside];
    beautifyBtn.frame = CGRectMake(100, 20, 100, 40);
}
- (void)beautify {
    if (self.beautifyButton.selected) {//如果已经开启了美颜,则
        self.beautifyButton.selected = NO;
        [self.videoCamera removeAllTargets];//移除原有的
        [self.videoCamera addTarget:self.filterView];//添加普通预览层
    } else {//如果没有开启美颜
        self.beautifyButton.selected = YES;
        [self.videoCamera removeAllTargets];//移除原有的
        GPUImageBeautifyFilter *beautifyFilter = [[GPUImageBeautifyFilter alloc] init];
        [self.videoCamera addTarget:beautifyFilter];//添加美颜滤镜层
        [beautifyFilter addTarget:self.filterView];//美颜后再输出到预览层
    }
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
