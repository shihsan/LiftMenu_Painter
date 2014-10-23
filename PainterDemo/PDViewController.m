//
//  PDViewController.m
//  PainterDemo
//
//  Created by LittleDoorBoard on 13/10/7.
//  Copyright (c) 2013年 tw.edu.nccu. All rights reserved.
//

#import "PDViewController.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>

#define VERTICAL 0
#define HORIZEN 1

int port = 8000;

@interface PDViewController ()
{
    CGPoint lastPoint;
    CGFloat red;
    CGFloat green;
    CGFloat blue;
    CGFloat brush;
    CGFloat opacity;
    BOOL mouseSwiped;
    /* variables for socket */
    char buf[256];
    int sockfd;
    int z;
    socklen_t adr_clnt_len;
    struct sockaddr_in adr_inet;
    struct sockaddr_in adr_clnt;
    /* finger position */
    float x;
    float y;
    float mouse;
    NSInteger tap;
    NSInteger status;
    NSInteger orient;
    int step;
    int isSetting;
    float firstX;
    float firstY;
    float leftmost;
    float rightmost;
    
    /* variable received via socket */
    float fx; // corrected finger's x
    float fy; // corrected finger's y
    float fz; // corrected finger's z
    float px; // uncorrected palm's x
    float py; // uncorrected palm's y
    float pz; // uncorrected palm's z
    float lx_; // finger's x where the key tap is registered deteced by leap
    float ly_; // finger's y where the key tap is registered deteced by leap
    float ox; // uncorrected finger's x
    float oy; // uncorrected finger's y
    float v; // finger[0]'s velocity
    //NSInteger tap; // if tap triggered - 1 for YES, 0 for NO
    float pin; //for pinch
    
    float pre_px;   //previous palm's x
    float pre_py;   //previous palm's y
    float pre_pz;   //previous palm's z
}
@end

@implementation PDViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    red = 0.0/255.0;
    green = 0.0/255.0;
    blue = 0.0/255.0;
    brush = 10.0;
    opacity = 1.0;
    
    [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
    [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
    
    /*-------------Socket Server-------------*/
    //    int sockfd;
    int len;
    //    int z;
    //    char buf[256];
    //    struct sockaddr_in adr_inet;
    //    struct sockaddr_in adr_clnt;
    //    socklen_t adr_clnt_len = sizeof(adr_clnt);
    adr_clnt_len = sizeof(adr_clnt);
    
    printf("等待 Client 端傳送資料...\n");
    
    bzero(&adr_inet, sizeof(adr_inet));
    adr_inet.sin_family = AF_INET;
    adr_inet.sin_addr.s_addr = inet_addr("127.0.0.1"); //192.168.0.114
    adr_inet.sin_port = htons(port);
    
    len = sizeof(adr_clnt);
    
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    
    if (sockfd == -1) {
        perror("socket error");
        exit(1);
    }
    z = bind(sockfd,(struct sockaddr *)&adr_inet, sizeof(adr_inet));
    
    if (z == -1) {
        perror("bind error");
        exit(1);
    }
    /*-------------Socket Server-------------*/
    
    [NSThread detachNewThreadSelector:@selector(connectLeap) toTarget:self withObject:nil];
    
    status = '0';
    step = 1;
    isSetting = 1;
    
    //Scroll view
//    _scrollview.delegate = self;
//    _scrollview.minimumZoomScale = 1.0;
//    _scrollview.maximumZoomScale = 2.0;
//    self.scrollview.contentSize = self.mainImage.image.size ;
//    self.mainImage.frame = CGRectMake(0, 0, self.mainImage.image.size.width, self.mainImage.image.size.height);
//    
//    [_scrollview setScrollEnabled:YES];
//    [_scrollview setShowsHorizontalScrollIndicator:YES];
//    [_scrollview setShowsVerticalScrollIndicator:YES];
}

- (void)connectLeap
{
    while(1) {
        
        z = (int)recvfrom(sockfd, buf, sizeof(buf), 0, (struct sockaddr*)&adr_clnt, &adr_clnt_len);
        //傳送資料的socketid,暫存器指標buf,sizeof(buf),一般設為0,接收端網路位址,sizeof(接收端網路位址);
        if (z < 0) {
            perror("recvfrom error");
            exit(1);
        }
        buf[z] = 0;
        //printf("%s", buf);
        
        NSString *string = [NSString stringWithUTF8String:buf];
        NSScanner *scanner = [NSScanner scannerWithString:string];
        
        /*
        [scanner scanInteger:&status];
        [scanner scanString:@", " intoString:nil];
        [scanner scanFloat:&(x)];
        [scanner scanString:@", " intoString:nil];
        [scanner scanFloat:&(y)];
        [scanner scanString:@", " intoString:nil];
        [scanner scanInt:&(tap)];
        */
        
        
        [scanner scanInteger:&status];
        [scanner scanString:@", " intoString:nil];
        [scanner scanFloat:&fz];
        [scanner scanString:@", " intoString:nil];
        [scanner scanFloat:&fx];
        [scanner scanString:@", " intoString:nil];
        [scanner scanFloat:&fy];
        [scanner scanString:@", " intoString:nil];
        [scanner scanFloat:&pz];
        [scanner scanString:@", " intoString:nil];
        [scanner scanFloat:&px];
        [scanner scanString:@", " intoString:nil];
        [scanner scanFloat:&py];
        [scanner scanString:@", " intoString:nil];
        [scanner scanInt:&(tap)];
        [scanner scanString:@", " intoString:nil];
        [scanner scanFloat:&pin];
        
        pin = 0;
        x = fx;
        y = fy;
        
        NSLog(@"sta:%d,isSet:%d,tap:%d", status,isSetting,tap);
        
        //NSLog(@"%s", buf);
        
        if (isSetting && tap == 1) {
            if (step == 1) {
                [self performSelectorOnMainThread:@selector(setLeftmost) withObject:nil waitUntilDone:YES];
            }
            else if (step == 2) {
                [self performSelectorOnMainThread:@selector(setRightmost) withObject:nil waitUntilDone:YES];
            }
        } else {
            
            mouse = orient ? x : y;
            if (leftmost<mouse && mouse<rightmost) {
                mouse = (320 * (mouse-leftmost))/(rightmost - leftmost);
                [self performSelectorOnMainThread:@selector(moveMouse) withObject:nil waitUntilDone:NO];
            }
        
            [self performSelectorOnMainThread:@selector(manageMenu) withObject:nil waitUntilDone:NO];
            
        }
        
        
        /*
        if(pin > 0.8 && pin <= 1){
            [self performSelectorOnMainThread:@selector(moveImg) withObject:nil waitUntilDone:YES];
        }
        
        if(pre_px != px)
            pre_px = px;
        if(pre_py != py)
            pre_py = py;
        if(pre_pz != pz)
            pre_pz = pz;
         */

    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    close(sockfd);
    exit(0);
}

- (void)setLeftmost
{
    firstX = x;
    firstY = y;
    step = 2;
    _stepLabel.text = @"step 2";
    _instrLabel.text = @"Tap to set RIGHTMOST point";
}

- (void)setRightmost
{
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         [_settingView removeFromSuperview];
                         [_stepLabel removeFromSuperview];
                         [_instrLabel removeFromSuperview];
                     }
                     completion:^(BOOL finished) {
                         if ((x-firstX) > (y-firstY)) {
                             leftmost = firstX;
                             rightmost = x;
                             orient = HORIZEN;
                         } else {
                             leftmost = firstY;
                             rightmost = y;
                             orient = VERTICAL;
                         }
                         step = 0;
                         isSetting = 0;
                     }];
}

- (void)resetColorMenu
{
    [_color_1 setFrame:CGRectMake(8, 0, 44, 44)];
    [_color_2 setFrame:CGRectMake(60, 0, 44, 44)];
    [_color_3 setFrame:CGRectMake(112, 0, 44, 44)];
    [_color_4 setFrame:CGRectMake(164, 0, 44, 44)];
    [_color_5 setFrame:CGRectMake(216, 0, 44, 44)];
    [_color_6 setFrame:CGRectMake(268, 0, 44, 44)];
}

- (void)resetBrushMenu
{
    [_brush_1 setFrame:CGRectMake(8, 0, 44, 44)];
    [_brush_2 setFrame:CGRectMake(60, 0, 44, 44)];
    [_brush_3 setFrame:CGRectMake(112, 0, 44, 44)];
    [_brush_4 setFrame:CGRectMake(164, 0, 44, 44)];
    [_brush_5 setFrame:CGRectMake(216, 0, 44, 44)];
    [_brush_6 setFrame:CGRectMake(268, 0, 44, 44)];
}

- (void)moveMouse
{
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [_colorMouse setFrame:CGRectMake(mouse, 18, 8, 8)];
                         [_brushMouse setFrame:CGRectMake(mouse, 18, 8, 8)];
                     }
                     completion:^(BOOL finished) {
                         switch (status) {
                             case 1:
                                 [self setColor];
                                 break;
                             case 2:
                                 [self setBrush];
                                 break;
//                             case 3:
//                                 if(pin > 0.8 && pin <= 1){
//                                     [self moveImg];
//                                 }
//                                 break;
                             default:
                                 break;
                         }
                     }];
}

- (void)setColor
{
    if (tap == 1) {
    // yellow
    if (8<=mouse && mouse<=52) {
        red = 255.0/255.0;
        green = 255.0/255.0;
        blue = 0.0/255.0;
        [UIView animateWithDuration:0.2
                              delay:0.2
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_color_2 setFrame:CGRectMake(60, -44, 44, 44)];
                             [_color_3 setFrame:CGRectMake(112, -44, 44, 44)];
                             [_color_4 setFrame:CGRectMake(164, -44, 44, 44)];
                             [_color_5 setFrame:CGRectMake(216, -44, 44, 44)];
                             [_color_6 setFrame:CGRectMake(268, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    // green
    else if (60<=mouse && mouse<=104) {
        red = 0.0/255.0;
        green = 255.0/255.0;
        blue = 0.0/255.0;
        [UIView animateWithDuration:0.2
                              delay:0.2
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_color_1 setFrame:CGRectMake(8, -44, 44, 44)];
                             [_color_3 setFrame:CGRectMake(112, -44, 44, 44)];
                             [_color_4 setFrame:CGRectMake(164, -44, 44, 44)];
                             [_color_5 setFrame:CGRectMake(216, -44, 44, 44)];
                             [_color_6 setFrame:CGRectMake(268, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    // blue
    else if (112<=mouse && mouse<=156) {
        red = 0.0/255.0;
        green = 0.0/255.0;
        blue = 255.0/255.0;
        [UIView animateWithDuration:0.2
                              delay:0.2
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_color_1 setFrame:CGRectMake(8, -44, 44, 44)];
                             [_color_2 setFrame:CGRectMake(60, -44, 44, 44)];
                             [_color_4 setFrame:CGRectMake(164, -44, 44, 44)];
                             [_color_5 setFrame:CGRectMake(216, -44, 44, 44)];
                             [_color_6 setFrame:CGRectMake(268, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    // red
    else if (164<=mouse && mouse<=208) {
        red = 255.0/255.0;
        green = 0.0/255.0;
        blue = 0.0/255.0;
        [UIView animateWithDuration:0.2
                              delay:0.2
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_color_1 setFrame:CGRectMake(8, -44, 44, 44)];
                             [_color_2 setFrame:CGRectMake(60, -44, 44, 44)];
                             [_color_3 setFrame:CGRectMake(112, -44, 44, 44)];
                             [_color_5 setFrame:CGRectMake(216, -44, 44, 44)];
                             [_color_6 setFrame:CGRectMake(268, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    // black
    else if (216<=mouse && mouse<=260) {
        red = 0.0/255.0;
        green = 0.0/255.0;
        blue = 0.0/255.0;
        [UIView animateWithDuration:0.2
                              delay:0.2
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_color_1 setFrame:CGRectMake(8, -44, 44, 44)];
                             [_color_2 setFrame:CGRectMake(60, -44, 44, 44)];
                             [_color_3 setFrame:CGRectMake(112, -44, 44, 44)];
                             [_color_4 setFrame:CGRectMake(164, -44, 44, 44)];
                             [_color_6 setFrame:CGRectMake(268, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];

    }
    // white
    else if (268<=mouse && mouse<=312) {
        red = 255.0/255.0;
        green = 255.0/255.0;
        blue = 255.0/255.0;
        [UIView animateWithDuration:0.2
                              delay:0.2
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_color_1 setFrame:CGRectMake(8, -44, 44, 44)];
                             [_color_2 setFrame:CGRectMake(60, -44, 44, 44)];
                             [_color_3 setFrame:CGRectMake(112, -44, 44, 44)];
                             [_color_4 setFrame:CGRectMake(164, -44, 44, 44)];
                             [_color_5 setFrame:CGRectMake(216, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    }
}

- (void)setBrush
{
    NSInteger tag = 0;
    if (tap == 1) {
    if (8<=mouse && mouse<=52) {
        tag = 1;
        [UIView animateWithDuration:0.2
                              delay:0.2
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_brush_2 setFrame:CGRectMake(60, -44, 44, 44)];
                             [_brush_3 setFrame:CGRectMake(112, -44, 44, 44)];
                             [_brush_4 setFrame:CGRectMake(164, -44, 44, 44)];
                             [_brush_5 setFrame:CGRectMake(216, -44, 44, 44)];
                             [_brush_6 setFrame:CGRectMake(268, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    else if (60<=mouse && mouse<=104) {
        tag = 2;
        [UIView animateWithDuration:0.2
                              delay:0.2
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_brush_1 setFrame:CGRectMake(8, -44, 44, 44)];
                             [_brush_3 setFrame:CGRectMake(112, -44, 44, 44)];
                             [_brush_4 setFrame:CGRectMake(164, -44, 44, 44)];
                             [_brush_5 setFrame:CGRectMake(216, -44, 44, 44)];
                             [_brush_6 setFrame:CGRectMake(268, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    else if (112<=mouse && mouse<=156) {
        tag = 3;
        [UIView animateWithDuration:0.2
                              delay:0.2
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_brush_1 setFrame:CGRectMake(8, -44, 44, 44)];
                             [_brush_2 setFrame:CGRectMake(60, -44, 44, 44)];
                             [_brush_4 setFrame:CGRectMake(164, -44, 44, 44)];
                             [_brush_5 setFrame:CGRectMake(216, -44, 44, 44)];
                             [_brush_6 setFrame:CGRectMake(268, -44, 44, 44)];                         }
                         completion:^(BOOL finished) {
                             [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    else if (164<=mouse && mouse<=208) {
        tag = 4;
        [UIView animateWithDuration:0.2
                              delay:0.1
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_brush_1 setFrame:CGRectMake(8, -44, 44, 44)];
                             [_brush_2 setFrame:CGRectMake(60, -44, 44, 44)];
                             [_brush_3 setFrame:CGRectMake(112, -44, 44, 44)];
                             [_brush_5 setFrame:CGRectMake(216, -44, 44, 44)];
                             [_brush_6 setFrame:CGRectMake(268, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    else if (216<=mouse && mouse<=260) {
        tag = 5;
        [UIView animateWithDuration:0.2
                              delay:0.1
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_brush_1 setFrame:CGRectMake(8, -44, 44, 44)];
                             [_brush_2 setFrame:CGRectMake(60, -44, 44, 44)];
                             [_brush_3 setFrame:CGRectMake(112, -44, 44, 44)];
                             [_brush_4 setFrame:CGRectMake(164, -44, 44, 44)];
                             [_brush_6 setFrame:CGRectMake(268, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    else if (268<=mouse && mouse<=312) {
        tag = 6;
        [UIView animateWithDuration:0.2
                              delay:0.1
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
                             [_brush_1 setFrame:CGRectMake(8, -44, 44, 44)];
                             [_brush_2 setFrame:CGRectMake(60, -44, 44, 44)];
                             [_brush_3 setFrame:CGRectMake(112, -44, 44, 44)];
                             [_brush_4 setFrame:CGRectMake(164, -44, 44, 44)];
                             [_brush_5 setFrame:CGRectMake(216, -44, 44, 44)];
                         }
                         completion:^(BOOL finished) {
                             [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
                         }];
    }
    brush = tag * 7;
    }
}

- (void)manageMenu
{
    [UIView animateWithDuration:0.2
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         if (!status || status == 3) {
                             [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
                             [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
                             [self resetBrushMenu];
                             [self resetColorMenu];
                         }
                         else if (status == 1) {
                             [_colorView setFrame:CGRectMake(0, 0, 320, 54)];//appear
                             [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
                             [self resetBrushMenu];
                         }
                         else if (status == 2) {
                             [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
                             [_brushView setFrame:CGRectMake(0, 0, 320, 54)];//appear
                             [self resetColorMenu];
                         }
                     }
                     completion:nil];
}

//- (void)dismissMenu
//{
//    [UIView animateWithDuration:0.2
//                          delay:0
//                        options:UIViewAnimationOptionCurveEaseInOut
//                     animations:^{
//                         [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
//                         [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
//                     }
//                     completion:nil];
//}
//
//- (void)chooseColor
//{
//    [UIView animateWithDuration:0.2
//                          delay:0
//                        options:UIViewAnimationOptionCurveEaseInOut
//                     animations:^{
//                         [_colorView setFrame:CGRectMake(0, 0, 320, 54)];
//                         [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
//                     }
//                     completion:nil];
//}
//
//- (void)chooseBrush
//{
//    [UIView animateWithDuration:0.2
//                          delay:0
//                        options:UIViewAnimationOptionCurveEaseInOut
//                     animations:^{
//                         [_brushView setFrame:CGRectMake(0, 0, 320, 54)];
//                         [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
//                     }
//                     completion:nil];
//}

#pragma mark - paint
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{    
    mouseSwiped = NO;
    UITouch *touch = [touches anyObject];
    lastPoint = [touch locationInView:self.view];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{    
    mouseSwiped = YES;
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.view];
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    [self.tempDrawImage.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    CGContextMoveToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
    CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), currentPoint.x, currentPoint.y);
    CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
    CGContextSetLineWidth(UIGraphicsGetCurrentContext(), brush);
    CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), red, green, blue, 1.0);
    CGContextSetBlendMode(UIGraphicsGetCurrentContext(),kCGBlendModeNormal);
    
    CGContextStrokePath(UIGraphicsGetCurrentContext());
    self.tempDrawImage.image = UIGraphicsGetImageFromCurrentImageContext();
    [self.tempDrawImage setAlpha:opacity];
    UIGraphicsEndImageContext();
    
    lastPoint = currentPoint;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{    
    if(!mouseSwiped) {
        UIGraphicsBeginImageContext(self.view.frame.size);
        [self.tempDrawImage.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
        CGContextSetLineCap(UIGraphicsGetCurrentContext(), kCGLineCapRound);
        CGContextSetLineWidth(UIGraphicsGetCurrentContext(), brush);
        CGContextSetRGBStrokeColor(UIGraphicsGetCurrentContext(), red, green, blue, opacity);
        CGContextMoveToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
        CGContextAddLineToPoint(UIGraphicsGetCurrentContext(), lastPoint.x, lastPoint.y);
        CGContextStrokePath(UIGraphicsGetCurrentContext());
        CGContextFlush(UIGraphicsGetCurrentContext());
        self.tempDrawImage.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    
    UIGraphicsBeginImageContext(self.mainImage.frame.size);
    [self.mainImage.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) blendMode:kCGBlendModeNormal alpha:1.0];
    [self.tempDrawImage.image drawInRect:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) blendMode:kCGBlendModeNormal alpha:opacity];
    self.mainImage.image = UIGraphicsGetImageFromCurrentImageContext();
    self.tempDrawImage.image = nil;
    UIGraphicsEndImageContext();
}

//- (IBAction)colorChoosed:(id)sender
//{
//    switch ([sender tag]) {
//        case 1: // yellow
//            red = 255.0/255.0;
//            green = 255.0/255.0;
//            blue = 0.0/255.0;
//            break;
//        case 2: // green
//            red = 0.0/255.0;
//            green = 255.0/255.0;
//            blue = 0.0/255.0;
//            break;
//        case 3: // blue
//            red = 0.0/255.0;
//            green = 0.0/255.0;
//            blue = 255.0/255.0;
//            break;
//        case 4: // red
//            red = 255.0/255.0;
//            green = 0.0/255.0;
//            blue = 0.0/255.0;
//            break;
//        case 5: // black
//            red = 0.0/255.0;
//            green = 0.0/255.0;
//            blue = 0.0/255.0;
//            break;
//        case 6: // white
//            red = 255.0/255.0;
//            green = 255.0/255.0;
//            blue = 255.0/255.0;
//        default:
//            break;
//    }
//}
//
//- (IBAction)brushChoosed:(id)sender
//{
//    brush = [sender tag] * 7;
//}
//
//- (IBAction)dismissView:(id)sender
//{
//    switch ([sender tag]) {
//        case 0: // color view
//        {[UIView animateWithDuration:0.2
//                                  delay:0
//                                options:UIViewAnimationOptionCurveEaseInOut
//                             animations:^{
//                                 [_colorView setFrame:CGRectMake(0, -54, 320, 54)];
//                             }
//                          completion:nil];}
//            break;
//        case 1: // brush view
//        {[UIView animateWithDuration:0.2
//                                  delay:0
//                                options:UIViewAnimationOptionCurveEaseInOut
//                             animations:^{
//                                 [_brushView setFrame:CGRectMake(0, -54, 320, 54)];
//                             }
//                          completion:nil];}
//            break;
//        default:
//            break;
//    }
//}


#pragma mark - pinch
/*-(void) moveImg
{
    [UIView animateWithDuration:0.5f
                     animations:^{
                         //Move the image view according to px , py
                         NSLog(@"pinch!!");
                         self.mainImage.frame =
                         CGRectMake(self.mainImage.frame.origin.x+px-pre_px,
                                    self.mainImage.frame.origin.y+py-pre_py,
                                    self.mainImage.frame.size.width,
                                    self.mainImage.frame.size.height);
                     }];
    
//    //for ZOOMING
//    if(pz-pre_pz > 1)
//        [UIView animateWithDuration:0.5f
//                         animations:^{
//                             _scrollview.zoomScale += 0.01f;
//                         }];
//    else if(pz-pre_pz < -1)
//        [UIView animateWithDuration:0.5f
//                         animations:^{
//                             _scrollview.zoomScale -= 0.01f;
//                         }];
    

}
 */

//- (UIView *)viewForZoomingInScrollView:(UIScrollView *)_scrollView {
//    return self.mainImage;
//}
@end
