//
//  XDSMarkModel.h
//  XDSReader
//
//  Created by dusheng.xu on 2017/6/15.
//  Copyright © 2017年 macos. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface XDSMarkModel : NSObject<NSCoding>

@property (nonatomic,strong) NSDate *date;//添加书签的日期
@property (nonatomic,copy) NSString *content;//划线的内容
@property (nonatomic,assign) NSInteger chapter;//笔记所在的章节
@property (nonatomic,assign) NSInteger locationInChapterContent;//笔记在章节中所在的位置
@property (nonatomic,readonly) NSInteger page;//根据locationInChapterContent获取笔记在章节中所在的页码

@end
