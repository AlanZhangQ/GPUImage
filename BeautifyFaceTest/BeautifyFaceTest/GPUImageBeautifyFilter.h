//
//  GPUImageBeautifyFilter.h
//  BeautifyFaceTest
//
//  Created by Mac on 16/8/9.
//  Copyright © 2016年 . All rights reserved.
//

#import <GPUImage/GPUImage.h>
@class GPUImageCombinationFilter;
@interface GPUImageBeautifyFilter : GPUImageFilterGroup //继承于图像滤镜组

{
    GPUImageBilateralFilter *bilateralFilter; //双边模糊(磨皮)滤镜--继承于高斯模糊滤镜GPUImageGaussianBlurFilter
    GPUImageCannyEdgeDetectionFilter *cannyEdgeFilter;//Canny边缘检测算法滤镜--继承于图像滤镜组GPUImageFilterGroup
    GPUImageHSBFilter *hsbFilter;//HSB颜色滤镜--继承于颜色矩阵滤镜GPUImageColorMatrixFilter
    GPUImageCombinationFilter *combinationFilter;//滤镜的组合---继承于三输入滤镜GPUImageThreeInputFilter
}

@end
