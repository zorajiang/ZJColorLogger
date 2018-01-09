//
//  ZJColorLogger.m
//  ColorDebug
//
//  Created by zorajiang on 2018/1/5.
//  Copyright © 2018年 zorajiang. All rights reserved.
//
#if DEBUG
#import "ZJColorLogger.h"
#import <unistd.h>
#import <sys/uio.h>

#define XCODE_COLORS_ESCAPE_SEQ "\033["

#define XCODE_COLORS_RESET_FG   XCODE_COLORS_ESCAPE_SEQ "fg;" // Clear any foreground color
#define XCODE_COLORS_RESET_BG   XCODE_COLORS_ESCAPE_SEQ "bg;" // Clear any background color
#define XCODE_COLORS_RESET      XCODE_COLORS_ESCAPE_SEQ ";"  // Clear any foreground or background color

static BOOL hasXcodeColors;

@interface XcodeColor: NSObject
+(NSString *)xcodeColorFromUIColor:(UIColor *) color;
@end

@implementation XcodeColor
+(NSString *)xcodeColorFromUIColor:(UIColor *) color
{
    CGFloat r, g, b;
    [color getRed:&r green:&g blue:&b alpha:NULL];
    
    uint8_t fg_r = (uint8_t)(r * 255.0f);
    uint8_t fg_g = (uint8_t)(g * 255.0f);
    uint8_t fg_b = (uint8_t)(b * 255.0f);
    return [NSString stringWithFormat:@"%u,%u,%u", fg_r, fg_g, fg_b];
}
@end

@interface ZJLogColor: NSObject
{
@public
    char fgCode[24];
    size_t fgCodeLen;
    
    char bgCode[24];
    size_t bgCodeLen;
    
    char resetCode[8];
    size_t resetCodeLen;
    
    NSUInteger mask;
}

- (id)initWithForegroundColor:(UIColor *)fgColor
              backgroundColor:(UIColor *)bgColor
                         mask:(NSUInteger)flag;

@end

@implementation ZJLogColor
+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        char *xcode_colors = getenv("XcodeColors");
        if (xcode_colors && (strcmp(xcode_colors, "YES") == 0)) {
            hasXcodeColors = YES;
        }
    });
}

- (id)initWithForegroundColor:(UIColor *)fgColor
              backgroundColor:(UIColor *)bgColor
                         mask:(NSUInteger)flag
{
    self = [super init];
    if (self)
    {
        mask = flag;
        if (fgColor && hasXcodeColors)
        {
            int result = snprintf(fgCode, 24, "%sfg%s;", XCODE_COLORS_ESCAPE_SEQ, [XcodeColor xcodeColorFromUIColor:fgColor].UTF8String);
            fgCodeLen = (NSUInteger)MAX(MIN(result, (24 - 1)), 0);
        }
        else
        {
            fgCode[0] = '\0';
            fgCodeLen = 0;
        }
        
        if (bgColor && hasXcodeColors)
        {
            int result = snprintf(bgCode, 24, "%sbg%s;", XCODE_COLORS_ESCAPE_SEQ, [XcodeColor xcodeColorFromUIColor:bgColor].UTF8String);
            bgCodeLen = (NSUInteger)MAX(MIN(result, (24 - 1)), 0);
        }
        else
        {
            bgCode[0] = '\0';
            bgCodeLen = 0;
        }
        
        if (hasXcodeColors)
        {
            resetCodeLen = (NSUInteger)MAX(snprintf(resetCode, 8, XCODE_COLORS_RESET), 0);
        }
        else
        {
            resetCode[0] = '\0';
            resetCodeLen = 0;
        }
    }
    return self;
}
@end


@implementation ZJLogMessage
+ (ZJLogMessage *)logWithMessage:(NSString *)message andFlag:(ZJColorLogFlag)flag
{
    ZJLogMessage *logMessage = [[ZJLogMessage alloc] init];
    logMessage.flag = flag;
    logMessage.txtMesssage = message;
    return logMessage;
}
@end

@interface ZJColorLogger()
@property (nonatomic, strong) NSMutableArray *colorsArray;
@end

@implementation ZJColorLogger
+ (ZJColorLogger *)sharedInstance
{
    static ZJColorLogger *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ZJColorLogger alloc] init];
    });
    return sharedInstance;
}

static dispatch_queue_t _logSerialQueue;
static void *const ZJLoggerQueueIdentityKey = (void *)&ZJLoggerQueueIdentityKey;

+ (void)initialize {
    static dispatch_once_t ZJLoggerOnceToken;
    dispatch_once(&ZJLoggerOnceToken, ^{
        _logSerialQueue = dispatch_queue_create("ZJLoggerSerialQueue", NULL);
        dispatch_queue_set_specific(_logSerialQueue, ZJLoggerQueueIdentityKey, (__bridge void *)self, NULL);
    });
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _colorsArray =  [NSMutableArray new];
        [self setColorsEnabled:YES];
    }
    return  self;
}

- (void)setColorsEnabled:(BOOL)newColorsEnabled
{
    dispatch_block_t block = ^{
        @autoreleasepool {
            _colorsEnabled = newColorsEnabled;
            if ([_colorsArray count] == 0)
            {
                [self loadDefaultColorSettings];
            }
        }
    };
    
    if (dispatch_get_specific(ZJLoggerQueueIdentityKey))
    {
        block();
    }
    else
    {
        dispatch_async(_logSerialQueue, block);
    }
}

- (void)loadDefaultColorSettings
{
    [self setForegroundColor:[UIColor blueColor] backgroundColor:nil forFlag:ZJColorLogFlagError];
    [self setForegroundColor:[UIColor purpleColor] backgroundColor:nil forFlag:ZJColorLogFlagWarning];
    [self setForegroundColor:[UIColor grayColor] backgroundColor:nil forFlag:ZJColorLogFlagInfo];
    [self setForegroundColor:[UIColor blackColor] backgroundColor:nil forFlag:ZJColorLogFlagDebug];
}

- (void)setForegroundColor:(UIColor *)txtColor
           backgroundColor:(UIColor *)bgColor
                   forFlag:(ZJColorLogFlag)flag
{
    dispatch_block_t block = ^{
        ZJLogColor *newColor = [[ZJLogColor alloc] initWithForegroundColor:txtColor
                                                                    backgroundColor:bgColor
                                                                               mask:flag];
        NSUInteger i = 0;
        
        for (ZJLogColor *color in _colorsArray)
        {
            if (color->mask == flag)
            {
                break;
            }
            i++;
        }
        
        if (i < [_colorsArray count])
        {
            _colorsArray[i] = newColor;
        }
        else
        {
            [_colorsArray addObject:newColor];
        }
    };
    
    if (dispatch_get_specific(ZJLoggerQueueIdentityKey))
    {
        block();
    }
    else
    {
        dispatch_async(_logSerialQueue, block);
    }
}

- (void)logWithFlag:(ZJColorLogFlag) flag andArgs:(NSString *)format, ... NS_REQUIRES_NIL_TERMINATION;
{
    NSString *strMessage = nil;
    
    va_list argList;
    va_start(argList, format);
    strMessage = [[NSString alloc] initWithFormat:format arguments:argList];
    va_end(argList);
    
    [self logMessage:[ZJLogMessage logWithMessage:strMessage andFlag:flag]];
}

- (void)logWithFlag:(ZJColorLogFlag)flag andSimpleMessage:(NSString *)message
{
    [self logMessage:[ZJLogMessage logWithMessage:message andFlag:flag]];
}

- (void)logMessage:(ZJLogMessage *)logMessage
{
    if (dispatch_get_specific(ZJLoggerQueueIdentityKey))
    {
        [self seriaLogMessage:logMessage];
    }
    else
    {
        __typeof__(self) __weak weakself = self;
        dispatch_async(_logSerialQueue, ^{
            [weakself seriaLogMessage:logMessage];
        });
    }
}


- (void)seriaLogMessage:(ZJLogMessage *)logMessage
{
    NSString *logMsg = logMessage.txtMesssage;
    if (logMsg.length > 0)
    {
        // Search for a color profile associated with the log message
        
        ZJLogColor *logColor = nil;
        if (_colorsEnabled)
        {
            for (ZJLogColor *color in _colorsArray)
            {
                if (logMessage.flag & color->mask)
                {
                    logColor = color;
                    break;
                }
            }
        }
        
        // Convert log message to C string.
        //
        // We use the stack instead of the heap for speed if possible.
        // But we're extra cautious to avoid a stack overflow.
        
        NSUInteger msgLen = [logMsg lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        const BOOL useStack = msgLen < (1024 * 4);
        
        char msgStack[useStack ? (msgLen + 1) : 1]; // Analyzer doesn't like zero-size array, hence the 1
        char *msg = useStack ? msgStack : (char *)malloc(msgLen + 1);
        
        if (msg == NULL) {
            return;
        }
        
        BOOL logMsgEnc = [logMsg getCString:msg maxLength:(msgLen + 1) encoding:NSUTF8StringEncoding];
        if (!logMsgEnc)
        {
            if (!useStack && msg != NULL)
            {
                free(msg);
            }
            return;
        }

        struct iovec v[5];
        if (logColor)
        {
            v[0].iov_base = logColor->fgCode;
            v[0].iov_len = logColor->fgCodeLen;
                
            v[1].iov_base = logColor->bgCode;
            v[1].iov_len = logColor->bgCodeLen;
                
            v[4].iov_base = logColor->resetCode;
            v[4].iov_len = logColor->resetCodeLen;
        }
        else
        {
            v[0].iov_base = "";
            v[0].iov_len = 0;
            
            v[1].iov_base = "";
            v[1].iov_len = 0;
            
            v[4].iov_base = "";
            v[4].iov_len = 0;
        }

        v[2].iov_base = (char *)msg;
        v[2].iov_len = msgLen;
            
        v[3].iov_base = "\n";
        v[3].iov_len = (msg[msgLen] == '\n') ? 0 : 1;
            
        writev(STDERR_FILENO, v, 5);
        
        if (!useStack)
        {
            free(msg);
        }
    }
}


@end
#endif
