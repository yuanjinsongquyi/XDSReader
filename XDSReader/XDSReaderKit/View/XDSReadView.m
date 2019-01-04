//
//  XDSReadView.m
//  XDSReader
//
//  Created by dusheng.xu on 07/07/2017.
//  Copyright © 2017 macos. All rights reserved.
//

#import "XDSReadView.h"
#import "XDSChapterModel.h"
#import "UIView+XDSHyperLink.h"
#import "XDSPhotoBrowser.h"
@interface XDSReadView () <DTAttributedTextContentViewDelegate, MWPhotoBrowserDelegate>

{
    NSRange _selectRange;
    NSRange _calRange;
    NSArray *_pathArray;
    
    UIPanGestureRecognizer *_pan;
    //滑动手势有效区间
    CGRect _leftRect;
    CGRect _rightRect;
    
    CGRect _menuRect;
    //是否进入选择状态
    BOOL _selectState;
    BOOL _isDirectionRight; //滑动方向  (0---左侧滑动 1 ---右侧滑动)
}

@property (nonatomic,strong) XDSMagnifierView *magnifierView;

@property (strong, nonatomic) DTAttributedTextContentView *readTextView;

@property (nonatomic, strong) NSMutableAttributedString *readAttributedContent;

@property (nonatomic, copy) NSString *content;

@property (assign, nonatomic) NSInteger chapterNum;//
@property (assign, nonatomic) NSInteger pageNum;
@end
@implementation XDSReadView

//MARK: -  override super method
- (instancetype)initWithFrame:(CGRect)frame chapterNum:(NSInteger)chapterNum pageNum:(NSInteger)pageNum {
    if (self = [super initWithFrame:frame]) {
        self.chapterNum = chapterNum;
        self.pageNum = pageNum;
        XDSChapterModel *chapterModel = CURRENT_BOOK_MODEL.chapters[self.chapterNum];
        NSMutableAttributedString *pageAttributeString = chapterModel.pageAttributeStrings[self.pageNum];
        _readAttributedContent = pageAttributeString;
        self.content = pageAttributeString.string;

        [self createUI];
    }
    return self;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    
    CGRect leftDot,rightDot = CGRectZero;
    _menuRect = CGRectZero;
    
    //绘制选中区域的背景色
    [self drawSelectedPath:_pathArray leftDot:&leftDot rightDot:&rightDot];
    
    //绘制选中区域前后的大头针
    [self drawDotWithLeft:leftDot right:rightDot];
}


//MARK: - ABOUT UI UI相关
- (void)createUI{
    [self setBackgroundColor:[UIColor whiteColor]];
    [self addGestureRecognizer:({
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
        longPress;
    })];
    [self addGestureRecognizer:({
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
        pan.enabled = NO;
        _pan = pan;
        pan;
    })];
    
    
    CGRect frame = self.bounds;
    // we draw images and links via subviews provided by delegate methods
    self.readTextView = [[DTAttributedTextContentView alloc] initWithFrame:frame];
    self.readTextView.shouldDrawImages = YES;
    self.readTextView.shouldDrawLinks = YES;
    self.readTextView.delegate = self; // delegate for custom sub views
    self.readTextView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.readTextView];
    self.readTextView.attributedString = self.readAttributedContent;
}

//TODO: Magnifier View
-(void)showMagnifier{
    if (!_magnifierView) {
        self.magnifierView = [[XDSMagnifierView alloc] init];
        self.magnifierView.readView = self;
        [self addSubview:self.magnifierView];
    }
}
-(void)hiddenMagnifier{
    if (_magnifierView) {
        [self.magnifierView removeFromSuperview];
        self.magnifierView = nil;
    }
}
//MARK: - DELEGATE METHODS 代理方法
//TODO: DTAttributedTextContentViewDelegate
- (UIView *)attributedTextContentView:(DTAttributedTextContentView *)attributedTextContentView
              viewForAttributedString:(NSAttributedString *)string
                                frame:(CGRect)frame
{
    NSDictionary *attributes = [string attributesAtIndex:0 effectiveRange:NULL];
    
    NSURL *URL = [attributes objectForKey:DTLinkAttribute];
    NSString *identifier = [attributes objectForKey:DTGUIDAttribute];
    
    DTLinkButton *button = [[DTLinkButton alloc] initWithFrame:frame];
    button.URL = URL;
    button.minimumHitSize = CGSizeMake(25, 25); // adjusts it's bounds so that button is always large enough
    button.GUID = identifier;
    
    // get image with normal link text
    UIImage *normalImage = [attributedTextContentView contentImageWithBounds:frame options:DTCoreTextLayoutFrameDrawingDefault];
    [button setImage:normalImage forState:UIControlStateNormal];
    
    // get image for highlighted link text
    UIImage *highlightImage = [attributedTextContentView contentImageWithBounds:frame options:DTCoreTextLayoutFrameDrawingDrawLinksHighlighted];

    [button setImage:highlightImage forState:UIControlStateHighlighted];
    
    // use normal push action for opening URL
    [button addTarget:self action:@selector(linkPushed:) forControlEvents:UIControlEventTouchUpInside];
    
//    // demonstrate combination with long press
//    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(linkLongPressed:)];
//    [button addGestureRecognizer:longPress];
    
    return button;
}

- (UIView *)attributedTextContentView:(DTAttributedTextContentView *)attributedTextContentView
                    viewForAttachment:(DTTextAttachment *)attachment
                                frame:(CGRect)frame{
    
    if ([attachment isKindOfClass:[DTImageTextAttachment class]])
    {

        // if the attachment has a hyperlinkURL then this is currently ignored
        DTLazyImageView *imageView = [[DTLazyImageView alloc] initWithFrame:frame];
//        imageView.delegate = self;
        imageView.userInteractionEnabled = YES;
        // sets the image if there is one
        imageView.image = [(DTImageTextAttachment *)attachment image];
        // url for deferred loading
        imageView.url = attachment.contentURL;
        if (attachment.contentURL || attachment.hyperLinkURL) {
            [imageView addGestureRecognizer:({
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleImageTap:)];
                tap;
            })];
        }
        
        if (attachment.hyperLinkURL) {
            imageView.hyperLinkURL = attachment.hyperLinkURL;// if there is a hyperlink
        }

        return imageView;
    }else if ([attachment isKindOfClass:[DTObjectTextAttachment class]]) {
        // somecolorparameter has a HTML color
        NSString *colorName = [attachment.attributes objectForKey:@"somecolorparameter"];
        UIColor *someColor = DTColorCreateWithHTMLName(colorName);
        
        UIView *someView = [[UIView alloc] initWithFrame:frame];
        someView.backgroundColor = someColor;
        someView.layer.borderWidth = 1;
        someView.layer.borderColor = [UIColor blackColor].CGColor;
        
        someView.accessibilityLabel = colorName;
        someView.isAccessibilityElement = YES;
        
        return someView;
    }
    
    return nil;
}

- (BOOL)attributedTextContentView:(DTAttributedTextContentView *)attributedTextContentView
 shouldDrawBackgroundForTextBlock:(DTTextBlock *)textBlock
                            frame:(CGRect)frame
                          context:(CGContextRef)context
                   forLayoutFrame:(DTCoreTextLayoutFrame *)layoutFrame {
    UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(frame,1,1) cornerRadius:10];
    
    //    CGColorRef color = [textBlock.backgroundColor CGColor];
    CGColorRef color = [[UIColor blueColor] CGColor];
    if (color) {
        CGContextSetFillColorWithColor(context, color);
        CGContextAddPath(context, [roundedRect CGPath]);
        CGContextFillPath(context);
        
        CGContextAddPath(context, [roundedRect CGPath]);
        CGContextSetRGBStrokeColor(context, 0, 0, 0, 1);
        CGContextStrokePath(context);
        return NO;
    }
    
    return YES; // draw standard background
}

//MARK: - ABOUT REQUEST 网络请求

//MARK: - ABOUT EVENTS 事件响应
- (void)handleImageTap:(UITapGestureRecognizer *)tap {
    DTLazyImageView *imageView = (DTLazyImageView *)tap.view;
    if (imageView.url && imageView.hyperLinkURL) {
#warning show action sheet
        
    }else if (imageView.url){
        [self showPhotoBrowserWithImage:imageView.url.path];
    }
}
- (void)linkPushed:(DTLinkButton *)button{
    XDSNoteModel *noteModel = [XDSNoteModel getNoteFromURL:button.URL];
    if (noteModel) {
        [XDSReaderUtil showAlertWithTitle:@"笔记内容" message:noteModel.content];
    }else{
        NSLog(@"xxxxxxxxxxxxxxx");
        NSString *url = [button.URL.absoluteString stringByRemovingPercentEncoding];
        NSArray *pathAndId = [url componentsSeparatedByString:@"#"];
        url = pathAndId.firstObject;
        
        XDSCatalogueModel *catalogueModel;
        for (XDSChapterModel *chapterModel in CURRENT_BOOK_MODEL.chapters) {
            if ([url hasSuffix:chapterModel.chapterSrc]) {
                catalogueModel = [[XDSCatalogueModel alloc] init];
                catalogueModel.chapter = [CURRENT_BOOK_MODEL.chapters indexOfObject:chapterModel];
                if (pathAndId.count == 2) {
                    catalogueModel.catalogueId = pathAndId.lastObject;
                }
                break;
            }
        }
        
        if (catalogueModel) {
            //jump to relative chapter and page
            NSLog(@"==== chapter");
            NSInteger selectedChapterNum = catalogueModel.chapter;
            XDSChapterModel *chapterModel = CURRENT_BOOK_MODEL.chapters[selectedChapterNum];
            
            if (chapterModel.locationWithPageIdMapping == nil) {
                [CURRENT_BOOK_MODEL loadContentInChapter:chapterModel];
            }
            NSString *locationKey = [NSString stringWithFormat:@"${id=%@}", catalogueModel.catalogueId];
            NSInteger locationInChapter = [chapterModel.locationWithPageIdMapping[locationKey] integerValue];
            NSInteger page = [chapterModel getPageWithLocationInChapter:locationInChapter];

            NSLog(@"chapter = %zd, page = %zd", selectedChapterNum, page);
            
        }else {
            [[UIApplication sharedApplication] openURL:button.URL];
        }
        
        
    }
}

-(void)longPress:(UILongPressGestureRecognizer *)longPress{
    CGPoint point = [longPress locationInView:self.readTextView];
    [self hiddenMenu];
    if (longPress.state == UIGestureRecognizerStateBegan || longPress.state == UIGestureRecognizerStateChanged) {
        
        //传入手势坐标，返回选择文本的range和frame
        CGRect rect = [self parserRectWithPoint:point range:&_selectRange];
        
        //显示放大镜
        [self showMagnifier];
        
        self.magnifierView.touchPoint = point;
        if (!CGRectEqualToRect(rect, CGRectZero)) {
            _pathArray = @[NSStringFromCGRect(rect)];
            [self setNeedsDisplay];
            
        }
    }
    if (longPress.state == UIGestureRecognizerStateEnded) {
        
        //隐藏放大
        [self hiddenMagnifier];
        if (!CGRectEqualToRect(_menuRect, CGRectZero)) {
            [self showMenu];
        }
    }
}
-(void)pan:(UIPanGestureRecognizer *)pan{
    
    CGPoint point = [pan locationInView:self];
    [self hiddenMenu];
    if (pan.state == UIGestureRecognizerStateBegan || pan.state == UIGestureRecognizerStateChanged) {
        [self showMagnifier];
        self.magnifierView.touchPoint = point;
        
        if (CGRectContainsPoint(_rightRect, point)||CGRectContainsPoint(_leftRect, point)) {
            if (CGRectContainsPoint(_leftRect, point)) {
                _isDirectionRight = NO;   //从左侧滑动
            }
            else{
                _isDirectionRight=  YES;    //从右侧滑动
            }
        }
        
        //传入手势坐标，返回选择文本的range和frame数组，一行一个frame
        NSArray *path = [self parserRectsWithPoint:point range:&_selectRange paths:_pathArray isDirectionRight:_isDirectionRight];
        _pathArray = path;
        [self setNeedsDisplay];
        
        
    }else{
        [self hiddenMagnifier];
        _selectState = NO;
        if (!CGRectEqualToRect(_menuRect, CGRectZero)) {
            [self showMenu];
        }
    }
    
}

-(void)showMenu {
    if ([self becomeFirstResponder]) {
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        UIMenuItem *menuItemCopy = [[UIMenuItem alloc] initWithTitle:@"复制" action:@selector(menuCopy:)];
        UIMenuItem *menuItemNote = [[UIMenuItem alloc] initWithTitle:@"笔记" action:@selector(menuNote:)];
        UIMenuItem *menuItemShare = [[UIMenuItem alloc] initWithTitle:@"分享" action:@selector(menuShare:)];
        NSArray *menus = @[menuItemCopy,menuItemNote,menuItemShare];
        [menuController setMenuItems:menus];
        CGRect targetRect = _menuRect;
        
        [menuController setTargetRect:targetRect inView:self];
        [menuController setMenuVisible:YES animated:YES];
        
    }
}
- (BOOL)canBecomeFirstResponder {
    return YES;
}

-(void)hiddenMenu{
    [[UIMenuController sharedMenuController] setMenuVisible:NO animated:YES];
}

#pragma mark - MJPhotoBrowser库关键代码
- (void)showPhotoBrowserWithImage:(NSString *)imageurl {
    //显示大图
    NSArray *imageSrcArray = CURRENT_RECORD.chapterModel.imageSrcArray;
    // 2.显示相册
    XDSPhotoBrowser *browser = [[XDSPhotoBrowser alloc] initWithDelegate:self];
    
    // Set options
    browser.displayActionButton = YES; // Show action button to allow sharing, copying, etc (defaults to YES)
    browser.displayNavArrows = YES; // Whether to display left and right nav arrows on toolbar (defaults to NO)
    browser.displaySelectionButtons = NO; // Whether selection buttons are shown on each image (defaults to NO)
    browser.zoomPhotosToFill = YES; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
    browser.alwaysShowControls = YES; // Allows to control whether the bars and controls are always visible or whether they fade away to show the photo full (defaults to NO)
    browser.enableGrid = YES; // Whether to allow the viewing of all the photo thumbnails on a grid (defaults to YES)
    browser.startOnGrid = YES; // Whether to start on the grid of thumbnails instead of the first photo (defaults to NO)
    browser.autoPlayOnAppear = YES; // Auto-play first video
    browser.enableSwipeToDismiss = YES;
    
    browser.currentPhotoIndex = [imageSrcArray containsObject:imageurl]?[imageSrcArray indexOfObject:imageurl]:0; // 弹出相册时显示第几张图片
    [browser showNextPhotoAnimated:YES];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:browser];
    [[UIViewController xds_visiableViewController] presentViewController:nav animated:YES completion:nil];
}


- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    NSArray *imageSrcArray = CURRENT_RECORD.chapterModel.imageSrcArray;

    return imageSrcArray.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    NSArray *imageSrcArray = CURRENT_RECORD.chapterModel.imageSrcArray;

    if (index < imageSrcArray.count) {
        NSString *scr = imageSrcArray[index];
        MWPhoto *photo = [MWPhoto photoWithURL:[NSURL fileURLWithPath:scr]];
        return photo;
    }
    return nil;
}

#pragma mark Menu Function
-(void)menuCopy:(id)sender{
    [self hiddenMenu];
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    
    [pasteboard setString:[_content substringWithRange:_selectRange]];
    [XDSReaderUtil showAlertWithTitle:@"成功复制以下内容" message:pasteboard.string];
    
}
-(void)menuNote:(id)sender{
    [self hiddenMenu];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"笔记"
                                                                             message:[_content substringWithRange:_selectRange]
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"输入内容";
    }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消"
                                                     style:UIAlertActionStyleCancel
                                                   handler:nil];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"确认"
                                                      style:UIAlertActionStyleDefault
                                                    handler:^(UIAlertAction * _Nonnull action) {
                                                        XDSNoteModel *model = [[XDSNoteModel alloc] init];
                                                        model.content = [_content substringWithRange:_selectRange];
                                                        model.note = alertController.textFields.firstObject.text;
                                                        model.date = [NSDate date];
                                                        XDSChapterModel *chapterModel = CURRENT_RECORD.chapterModel;
                                                        model.locationInChapterContent = _selectRange.location + [chapterModel.pageLocations[CURRENT_RECORD.currentPage] integerValue];
                                                        [[XDSReadManager sharedManager] addNoteModel:model];
                                                        [self addLineForNote:model];
                                                        [self cancelSelected];
                                                    }];
    [alertController addAction:cancel];
    [alertController addAction:confirm];
    for (UIView* next = [self superview]; next; next = next.superview) {
        UIResponder* nextResponder = [next nextResponder];
        if ([nextResponder isKindOfClass:[UIViewController class]]) {
            [(UIViewController *)nextResponder presentViewController:alertController animated:YES completion:nil];
            break;
        }
    }
}

-(void)menuShare:(id)sender{
    [self hiddenMenu];
}
//MARK: - OTHER PRIVATE METHODS 私有方法
//TODO: 绘制选中区域左右节点
-(void)drawDotWithLeft:(CGRect)leftDocFrame right:(CGRect)rightDocFrame{
    if (CGRectEqualToRect(CGRectZero, leftDocFrame) || (CGRectEqualToRect(CGRectZero, rightDocFrame))){
        return;
    }
    
    CGFloat dotSize = 8.f;//doc size  小圆点尺寸
    CGFloat clickableSize = dotSize + 20.f;//clickable size 可点区域尺寸
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGMutablePathRef pathRef = CGPathCreateMutable();
    [SELECTED_AREA_DOC_COLOR setFill];
    
    CGPathMoveToPoint(pathRef, NULL, CGRectGetMinX(leftDocFrame)-2, CGRectGetMinY(leftDocFrame));
    CGPathAddRect(pathRef, NULL, CGRectMake(CGRectGetMinX(leftDocFrame)-2, CGRectGetMinY(leftDocFrame),2, CGRectGetHeight(leftDocFrame)));
    
    CGPathMoveToPoint(pathRef, NULL, CGRectGetMaxX(rightDocFrame), CGRectGetMinY(rightDocFrame));
    CGPathAddRect(pathRef, NULL, CGRectMake(CGRectGetMaxX(rightDocFrame), CGRectGetMinY(rightDocFrame),2, CGRectGetHeight(rightDocFrame)));
    
    CGPathMoveToPoint(pathRef, NULL, CGRectGetMinX(leftDocFrame)-1, CGRectGetMinY(leftDocFrame));
    CGPathAddArc(pathRef, NULL, CGRectGetMinX(leftDocFrame)-1, CGRectGetMinY(leftDocFrame) - dotSize/2, dotSize/2, 0, M_PI*2, NO);
    
    CGPathMoveToPoint(pathRef, NULL, CGRectGetMaxX(leftDocFrame)+1, CGRectGetMaxY(leftDocFrame) + dotSize/2);
    CGPathAddArc(pathRef, NULL, CGRectGetMaxX(rightDocFrame)+1, CGRectGetMaxY(rightDocFrame) + dotSize/2, dotSize/2, 0, M_PI*2, NO);
    
    CGContextAddPath(ctx, pathRef);
    CGContextFillPath(ctx);
    CGPathRelease(pathRef);
    
    _leftRect = CGRectMake(CGRectGetMinX(leftDocFrame)-clickableSize/2,
                           CGRectGetMinY(leftDocFrame)-clickableSize/2,
                           clickableSize,
                           clickableSize);
    _rightRect = CGRectMake(CGRectGetMaxX(rightDocFrame)-clickableSize/2,
                            CGRectGetMaxY(rightDocFrame)-clickableSize/2,
                            clickableSize,
                            clickableSize);
}

//绘制选中区域的背景色
- (void)drawSelectedPath:(NSArray *)pathArray leftDot:(CGRect *)leftDot rightDot:(CGRect *)rightDot{
    if (pathArray.count < 1) {
        _pan.enabled = NO;
        return;
    }
    _pan.enabled = YES;
    CGMutablePathRef pathRef = CGPathCreateMutable();
    [SELECTED_AREA_BACKGROUND_COLOR setFill];
    for (int i = 0; i < [pathArray count]; i++) {
        CGRect rect = CGRectFromString([pathArray objectAtIndex:i]);
        CGPathAddRect(pathRef, NULL, rect);
        if (i == 0) {
            *leftDot = rect;
            _menuRect = rect;
        }
        if (i == [pathArray count]-1) {
            *rightDot = rect;
        }
        
    }
    
    //绘制选择区域的背景色
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextAddPath(ctx, pathRef);
    CGContextFillPath(ctx);
    CGPathRelease(pathRef);
}

-(void)cancelSelected{
    if (_pathArray) {
        _pathArray = nil;
        [self hiddenMenu];
        [self setNeedsDisplay];
    }
}

//TODO:add underline for notes 为笔记添加下划虚线
- (void)addLineForNote:(XDSNoteModel *)noteModel{
    NSMutableDictionary *attibutes = [NSMutableDictionary dictionary];
    //虚线
    //[attibutes setObject:@(NSUnderlinePatternDot|NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];
    [attibutes setObject:@(NSUnderlinePatternSolid|NSUnderlineStyleSingle) forKey:NSUnderlineStyleAttributeName];
    [attibutes setObject:[UIColor redColor] forKey:NSUnderlineColorAttributeName];
    [attibutes setObject:[noteModel getNoteURL] forKey:NSLinkAttributeName];
    
    [_readAttributedContent addAttributes:attibutes range:_selectRange];
    self.readAttributedContent = _readAttributedContent;
}


//MARK: - ABOUT MEMERY 内存管理
- (void)setReadAttributedContent:(NSMutableAttributedString *)readAttributedContent {
    _readAttributedContent = readAttributedContent;
    self.readTextView.attributedString = _readAttributedContent;
    self.content = _readAttributedContent.string;
    
    [self.readTextView relayoutText];
}

- (void)dataInit{
    
}

//=============================
- (CGRect)parserRectWithPoint:(CGPoint)point range:(NSRange *)selectRange{
    
    DTCoreTextLayoutFrame *visibleframe = self.readTextView.layoutFrame;
    NSArray *linse = visibleframe.lines;
    CGRect rect = CGRectZero;
    if (nil == linse) {
        return rect;
    }
    if (linse.count) {
        for (DTCoreTextLayoutLine *layoutLine in linse) {
            CGRect layoutLineFrame = layoutLine.frame;
            if (CGRectContainsPoint(layoutLineFrame, point)) {
                //获取行位置
                NSRange stringRange = [layoutLine stringRange];
                //获取手势在该页中的位置
                NSInteger index = [layoutLine stringIndexForPosition:point];
                CGFloat xStart = [layoutLine offsetForStringIndex:index];
                CGFloat xEnd;
                //默认选中两个单位
                if (index > stringRange.location+stringRange.length-2) {
                    xEnd = xStart;
                    xStart = [layoutLine offsetForStringIndex:index-2];
                    (*selectRange).location = index - 2;
                }else{
                    xEnd = [layoutLine offsetForStringIndex:index+2];
                    (*selectRange).location = index;
                }
                (*selectRange).length = 2;
                
                CGFloat leading = layoutLine.frame.origin.x;
                rect = layoutLineFrame;
                rect.origin.x = xStart + leading;
                rect.size.width = fabs(xStart-xEnd);
                break;
            }
        }
    }
    return rect;
}

- (NSArray *)parserRectsWithPoint:(CGPoint)point
                           range:(NSRange *)selectRange
                           paths:(NSArray *)paths
                 isDirectionRight:(BOOL)isDirectionRight{
    DTCoreTextLayoutFrame *visibleframe = self.readTextView.layoutFrame;
    NSArray *linse = visibleframe.lines;
    if (nil == linse || linse.count < 1) {
        return paths;
    }
    
    NSRange positionRange = NSMakeRange(0, 0);
    BOOL containPoint = NO;
    for (DTCoreTextLayoutLine *layoutLine in linse) {
        CGRect layoutLineFrame = layoutLine.frame;
        if (CGRectContainsPoint(layoutLineFrame, point)) {
            //获取手势在该页中的位置
            NSInteger index = [layoutLine stringIndexForPosition:point];
            positionRange.location = index;
            containPoint = YES;
            break;
        }
    }

    if (!containPoint) {
        return paths;
    }
    
    //set selectedRange
    if (isDirectionRight) {
        if (positionRange.location > (*selectRange).location){
            //在选择区域之间
            (*selectRange).length = positionRange.location - (*selectRange).location;
        }else{
            //在选中区域左边
            (*selectRange).length = (*selectRange).location - positionRange.location;
            (*selectRange).location = positionRange.location;
        }
    }else{
        if(positionRange.location < (*selectRange).location) {
            //在选中区域左边
            (*selectRange).length = ((*selectRange).location - positionRange.location + (*selectRange).length);
            (*selectRange).location = positionRange.location;
        }else if(positionRange.location > (*selectRange).location + (*selectRange).length){
            //在选中区域右边
            (*selectRange).location = (*selectRange).location + (*selectRange).length;
            (*selectRange).length = positionRange.location - (*selectRange).location;
        }else{
            //在选择区域之间
            (*selectRange).length = (*selectRange).location + (*selectRange).length - positionRange.location;
            (*selectRange).location = positionRange.location;
            
        }
    }
    
    DTCoreTextLayoutLine *firstLine = [visibleframe lineContainingIndex:(*selectRange).location];
    DTCoreTextLayoutLine *lastLine = [visibleframe lineContainingIndex:((*selectRange).location + (*selectRange).length)];
    
    if (CGRectEqualToRect(firstLine.frame, lastLine.frame)) {
        CGRect frame = firstLine.frame;
        CGFloat minX = [firstLine offsetForStringIndex:(*selectRange).location];
        CGFloat maxX = [firstLine offsetForStringIndex:(*selectRange).location + (*selectRange).length];
        frame.origin.x += minX;
        frame.size.width = maxX - minX;
        return @[NSStringFromCGRect(frame)];
        
    }else{

        NSMutableArray *pathArray = [NSMutableArray arrayWithCapacity:0];
        
        NSInteger firstIndex = (*selectRange).location;
        NSInteger lastIndex = (*selectRange).location + (*selectRange).length;
        
        for (DTCoreTextLayoutLine *layoutLine in linse) {
            NSRange stringRange = layoutLine.stringRange;
            if (stringRange.location < firstIndex && layoutLine != firstLine) {
                continue;
            }else if (stringRange.location > lastIndex){
                continue;
            }
            
            CGRect lineFrame = layoutLine.frame;
            if (layoutLine == firstLine ) {
                CGFloat xStart = [layoutLine offsetForStringIndex:firstIndex];
                lineFrame.size.width = (CGRectGetWidth(lineFrame) - (xStart - CGRectGetMinX(lineFrame)));
                lineFrame.origin.x += xStart;
            }else if(layoutLine == lastLine){
                CGFloat xStart = [layoutLine offsetForStringIndex:lastIndex];
                lineFrame.size.width = (CGRectGetWidth(lineFrame) - (CGRectGetMaxX(lineFrame)- CGRectGetMinX(lineFrame) - xStart));
            }else{}
            [pathArray addObject:NSStringFromCGRect(lineFrame)];

        }
        return pathArray;
    }
}

@end
