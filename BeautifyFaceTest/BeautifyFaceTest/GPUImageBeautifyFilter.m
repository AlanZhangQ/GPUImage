//
//  GPUImageBeautifyFilter.m
//  BeautifyFaceTest
//
//  Created by Mac on 16/8/9.
//  Copyright © 2016年 . All rights reserved.
//

#import "GPUImageBeautifyFilter.h"
/***************************************************/
// Internal CombinationFilter(It should not be used outside)
@interface GPUImageCombinationFilter : GPUImageThreeInputFilter//继承于三输入的滤镜
{
    GLint smoothDegreeUniform;//全局磨皮参数(平滑程度)
}

@property (nonatomic, assign) CGFloat intensity;

@end


/***********************************************/
//自定义的Shader着色器代码
//Shader出现在OpenGL ES 2.0中，允许创建自己的Shader。必须同时创建两个Shader，分别是Vertex shader(顶点着色器)和Fragment shader(片段着色器).http://www.jianshu.com/p/8687a040eb48

//Varyings：用来在Vertex shader和Fragment shader之间传递信息的，比如在Vertex shader中写入varying值，然后就可以在Fragment shader中读取和处理
//Uniforms：在渲染循环里作为不变的输入值
//vec2：两个浮点数，适合在Fragment shader中保存X和Y坐标的情况
//vec4：四个浮点数，在图像处理中持续追踪每个像素的R,G,V,A这四个值。
//highp:属性负责变量精度，这个被加入可以提高效率
//smpler2D:接收一个图片的引用，当做2D的纹理。


//根据这个字符串创建Shader
NSString *const kGPUImageBeautifyFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;//纹理坐标1
 varying highp vec2 textureCoordinate2;//纹理坐标2
 varying highp vec2 textureCoordinate3;//纹理坐标3
 
 uniform sampler2D inputImageTexture;//输入图像纹理1
 uniform sampler2D inputImageTexture2;//输入图像纹理2
 uniform sampler2D inputImageTexture3;//输入图像纹理3
 
 uniform mediump float smoothDegree;//平滑度
 
 void main()
 {
     highp vec4 bilateral = texture2D(inputImageTexture, textureCoordinate);//双边模糊的2D纹理
     highp vec4 canny = texture2D(inputImageTexture2, textureCoordinate2);//边缘检测的2D纹理
     highp vec4 origin = texture2D(inputImageTexture3,textureCoordinate3);//原始图像的2D纹理
     highp vec4 smooth;
     lowp float r = origin.r;
     lowp float g = origin.g;
     lowp float b = origin.b;
     //判断是不是边缘,是不是皮肤.通过肤色检测和边缘检测，只对皮肤和非边缘部分进行处理。
     if (canny.r < 0.2 && r > 0.3725 && g > 0.1568 && b > 0.0784 && r > b && (max(max(r, g), b) - min(min(r, g), b)) > 0.0588 && abs(r-g) > 0.0588) {
         smooth = (1.0 - smoothDegree) * (origin - bilateral) + bilateral;
     }
     else {
         smooth = origin;
     }
     smooth.r = log(1.0 + 0.2 * smooth.r)/log(1.2);
     smooth.g = log(1.0 + 0.2 * smooth.g)/log(1.2);
     smooth.b = log(1.0 + 0.2 * smooth.b)/log(1.2);
     gl_FragColor = smooth;
 }
 );
/******************************************/


@implementation GPUImageCombinationFilter //组合滤镜
//Combination  Filter是我们自己定义的三输入的滤波器。三个输入分别是原图像A(x, y),双边滤波后的图像B(x, y），边缘图像C(x, y)。其中A,B,C可以看成是图像矩阵，(x,y)可以看成其中某一像素的坐标。

- (id)init {
    //Combination Filter根据kGPUImageBeautifyFragmentShaderString创建自定义的Shader.
    //在自定义的Shader中对三个输入进行处理(双边模糊的2D纹理,边缘检测的2D纹理,原始图像的2D纹理),见上面Shader代码
    if (self = [super initWithFragmentShaderFromString:kGPUImageBeautifyFragmentShaderString]) {
        smoothDegreeUniform = [filterProgram uniformIndex:@"smoothDegree"];
    }
    self.intensity = 0.5;
    return self;
}

- (void)setIntensity:(CGFloat)intensity {
    _intensity = intensity;
    [self setFloat:intensity forUniform:smoothDegreeUniform program:filterProgram];
}

@end


@implementation GPUImageBeautifyFilter//美颜滤镜
-(instancetype)init {
    if (!(self = [super init])) {
        return nil;
    }
    //1.双边模糊
    bilateralFilter = [[GPUImageBilateralFilter alloc] init];
    bilateralFilter.distanceNormalizationFactor = 4.0;
    [self addFilter:bilateralFilter];
    //2.边缘探测
    cannyEdgeFilter = [[GPUImageCannyEdgeDetectionFilter alloc] init];
    [self addFilter:cannyEdgeFilter];
    //3.合并
    combinationFilter = [[GPUImageCombinationFilter alloc] init];
    [self addFilter:combinationFilter];
    //4.调整HSB
    hsbFilter = [[GPUImageHSBFilter alloc] init];
    [hsbFilter adjustBrightness:1.1];//亮度
    [hsbFilter adjustSaturation:1.1];//饱和度
    
    //双边模糊完成后,输出到组合滤镜
    [bilateralFilter addTarget:combinationFilter];
    //边缘探测完成后,输出到组合滤镜
    [cannyEdgeFilter addTarget:combinationFilter];
    //组合滤镜处理完成后,输出到hsb滤镜
    [combinationFilter addTarget:hsbFilter];
    
    //初始滤镜组
    self.initialFilters = [NSArray arrayWithObjects:bilateralFilter,cannyEdgeFilter,combinationFilter, nil];
    //最终处理的滤镜
    self.terminalFilter = hsbFilter;
    return self;
}
#pragma mark GPUImageInput protocol

-(void)newFrameReadyAtTime:(CMTime)frameTime atIndex:(NSInteger)textureIndex {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters) {
        if (currentFilter != self.inputFilterToIgnoreForUpdates) {
            if (currentFilter == combinationFilter) {
                textureIndex = 2;
            }
            [currentFilter newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }
    }
}
-(void)setInputFramebuffer:(GPUImageFramebuffer *)newInputFramebuffer atIndex:(NSInteger)textureIndex {
    for (GPUImageOutput<GPUImageInput> *currentFilter in self.initialFilters) {
        if (currentFilter != self.inputFilterToIgnoreForUpdates) {
            if (currentFilter == combinationFilter) {
                textureIndex = 2;
            }
            [currentFilter setInputFramebuffer:newInputFramebuffer atIndex:textureIndex];
        }

    }
}
@end

/*
 1、GPUImageVideoCamera捕获摄像头图像
 调用newFrameReadyAtTime: atIndex:通知GPUImageBeautifyFilter；
 
 2、GPUImageBeautifyFilter调用newFrameReadyAtTime: atIndex:
 通知GPUImageBilateralFliter输入纹理已经准备好；
 
 3、GPUImageBilateralFliter 绘制图像后在informTargetsAboutNewFrameAtTime()，
 调用setInputFramebufferForTarget: atIndex:
 把绘制的图像设置为GPUImageCombinationFilter输入纹理，
 并通知GPUImageCombinationFilter纹理已经绘制完毕；
 
 4、GPUImageBeautifyFilter调用newFrameReadyAtTime: atIndex:
 通知 GPUImageCannyEdgeDetectionFilter输入纹理已经准备好；
 
 5、同3，GPUImageCannyEdgeDetectionFilter 绘制图像后，
 把图像设置为GPUImageCombinationFilter输入纹理；
 
 6、GPUImageBeautifyFilter调用newFrameReadyAtTime: atIndex:
 通知 GPUImageCombinationFilter输入纹理已经准备好；
 
 7、GPUImageCombinationFilter判断是否有三个纹理，三个纹理都已经准备好后
 调用GPUImageThreeInputFilter的绘制函数renderToTextureWithVertices: textureCoordinates:，
 图像绘制完后，把图像设置为GPUImageHSBFilter的输入纹理,
 通知GPUImageHSBFilter纹理已经绘制完毕；
 
 8、GPUImageHSBFilter调用renderToTextureWithVertices: textureCoordinates:绘制图像，
 完成后把图像设置为GPUImageView的输入纹理，并通知GPUImageView输入纹理已经绘制完毕；
 
 9、GPUImageView把输入纹理绘制到自己的帧缓存，然后通过
 [self.context presentRenderbuffer:GL_RENDERBUFFER];显示到UIView上。
 */
