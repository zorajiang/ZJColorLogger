//
//  ZJColorLogger.h
//  ColorDebug
//
//  Created by zorajiang on 2018/1/5.
//  Copyright © 2018年 zorajiang. All rights reserved.
//  

#import <UIKit/UIKit.h>
// 日志类型
typedef NS_OPTIONS(NSUInteger, ZJColorLogFlag)
{
    ZJColorLogFlagError      = (1 << 0), //blue
    ZJColorLogFlagWarning    = (1 << 1), //purple
    ZJColorLogFlagInfo       = (1 << 2), //gray
    ZJColorLogFlagDebug      = (1 << 3), //black

    ZJColorLogFlagRed       = (1 << 4), //red
};

#if DEBUG
#define XcodeRedColorLogExample(fmt, ...) NSLog((@"\033[fg255,0,0;" fmt @"\033[;"), ##__VA_ARGS__)

#define ZJColorLog(flag, fmt, ...) ([[ZJColorLogger sharedInstance] logWithFlag:flag andArgs:fmt, ##__VA_ARGS__,nil])
#define ZJColorLogRed(fmt, ...)  ZJColorLog(ZJColorLogFlagRed, fmt, ##__VA_ARGS__)

@interface ZJLogMessage : NSObject
@property (nonatomic, assign) ZJColorLogFlag flag;
@property (nonatomic, strong) NSString *txtMesssage;

+ (ZJLogMessage *)logWithMessage:(NSString *)message andFlag:(ZJColorLogFlag)flag;
@end

@interface ZJColorLogger : NSObject
@property (nonatomic, assign) BOOL colorsEnabled;

+ (ZJColorLogger *)sharedInstance;
- (void)setForegroundColor:(UIColor *)txtColor
           backgroundColor:(UIColor *)bgColor
                   forFlag:(ZJColorLogFlag)flag;

- (void)logWithFlag:(ZJColorLogFlag) flag andArgs:(NSString *)format, ... NS_REQUIRES_NIL_TERMINATION;
- (void)logWithFlag:(ZJColorLogFlag)flag andSimpleMessage:(NSString *)message;
- (void)logMessage:(ZJLogMessage *)logMessage;
@end
#else
#define ZJColorLog(flag, fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#endif
