//
//  XDSBookModel.h
//  XDSReader
//
//  Created by dusheng.xu on 2017/6/15.
//  Copyright © 2017年 macos. All rights reserved.
//

#import <Foundation/Foundation.h>
@interface LPPBookInfoModel : NSObject <NSCoding>
//    <title>:题名
//    <creator>：责任者
//    <subject>：主题词或关键词
//    <description>：内容描述
//    <contributor>：贡献者或其它次要责任者
//    <date>：日期
//    <type>：类型
//    <format>：格式
//    <identifier>：标识符
//    <source>：来源
//    <language>：语种
//    <relation>：相关信息
//    <coverage>：履盖范围
//    <rights>：权限描述
//    <x-metadata>，即扩展元素。如果有些信息在上述元素中无法描述，则在此元素中进行扩展。

@property (nonatomic,copy) NSString *rootDocumentUrl;//解压包所在路径
@property (nonatomic,copy) NSString *OEBPSUrl;//OPF与NCX文件所在的文件夹路径

@property (nonatomic,copy) NSString *cover;//封面
@property (nonatomic,copy) NSString *title;
@property (nonatomic,copy) NSString *creator;
@property (nonatomic,copy) NSString *subject;
@property (nonatomic,copy) NSString *descrip;
@property (nonatomic,copy) NSString *date;
@property (nonatomic,copy) NSString *type;
@property (nonatomic,copy) NSString *format;
@property (nonatomic,copy) NSString *identifier;
@property (nonatomic,copy) NSString *source;
@property (nonatomic,copy) NSString *relation;
@property (nonatomic,copy) NSString *coverage;
@property (nonatomic,copy) NSString *rights;
@end

@interface XDSBookModel : NSObject <NSCoding>

@property (nonatomic,strong) NSURL *resource;//资源路径
@property (nonatomic, strong) LPPBookInfoModel *bookBasicInfo;//书籍基本信息
@property (nonatomic,copy) NSString *content;//电子书文本内容
@property (nonatomic,assign) LPPEBookType bookType;//电子书类型（txt, epub）
@property (nonatomic,readonly) NSArray <XDSChapterModel*> *chapters;//章节
@property (nonatomic,readonly) NSArray <XDSChapterModel*> *chapterContainNotes;//包含笔记的章节
@property (nonatomic,readonly) NSArray <XDSChapterModel*> *chapterContainMarks;//包含书签的章节

@property (nonatomic,strong) XDSRecordModel *record;//阅读进度



- (instancetype)initWithContent:(NSString *)content;
- (instancetype)initWithePub:(NSString *)ePubPath;
+ (void)updateLocalModel:(XDSBookModel *)bookModel url:(NSURL *)url;
+ (id)getLocalModelWithURL:(NSURL *)url;

- (void)loadContentInChapter:(XDSChapterModel *)chapterModel;
- (void)loadContentForAllChapters;

- (void)deleteNote:(XDSNoteModel *)noteModel;
- (void)addNote:(XDSNoteModel *)noteModel;

- (void)deleteMark:(XDSMarkModel *)markModel;
- (void)addMark:(XDSMarkModel *)markModel;

@end
