#import "SGSSearchBarView.h"
#import "Glass/SGSGlassView.h"
#import <objc/message.h>

static const CGFloat kBarHeight   = 50.0;
static const CGFloat kSideMargin  = 16.0;
static const CGFloat kGap         = 8.0;
static const CGFloat kKeyboardGap = 8.0;

static NSString *SGSUIKitString(NSString *key) {
    NSBundle *bundle = [NSBundle bundleForClass:UISearchBar.class];
    return [bundle localizedStringForKey:key value:key table:nil];
}

#pragma mark - round close button

@interface SGSCloseButton : UIControl
@property (nonatomic, readonly) SGSGlassView *glass;
@end

@implementation SGSCloseButton
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _glass = [[SGSGlassView alloc] initWithFrame:self.bounds];
    _glass.userInteractionEnabled = NO;
    _glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_glass];

    UIImageSymbolConfiguration *cfg =
        [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightSemibold];
    UIImageView *x = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"xmark" withConfiguration:cfg]];
    x.tintColor = [UIColor labelColor];
    x.contentMode = UIViewContentModeCenter;
    x.frame = self.bounds;
    x.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [_glass.contentView addSubview:x];
    self.accessibilityLabel = SGSUIKitString(@"Cancel");
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0
                        options:UIViewAnimationOptionAllowUserInteraction | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.transform = highlighted ? CGAffineTransformMakeScale(0.92, 0.92) : CGAffineTransformIdentity;
    } completion:nil];
}
@end

#pragma mark - search bar

@interface SGSSearchBarView () <UITextFieldDelegate>
@end

@implementation SGSSearchBarView {
    SGSGlassView *_pill;
    UIImageView *_icon;
    UITextField *_field;
    UIButton *_mic;
    SGSCloseButton *_close;

    BOOL _searching;
    BOOL _barVisible;
    CGFloat _keyboardOverlap;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _barVisible = YES;

    _pill = [[SGSGlassView alloc] initWithFrame:CGRectMake(0, 0, 300, kBarHeight)];
    [self addSubview:_pill];

    UIImageSymbolConfiguration *iconCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
    _icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:iconCfg]];
    _icon.tintColor = [UIColor secondaryLabelColor];
    _icon.contentMode = UIViewContentModeCenter;
    [_pill.contentView addSubview:_icon];

    _field = [[UITextField alloc] init];
    _field.font = [UIFont systemFontOfSize:17];
    _field.textColor = [UIColor labelColor];
    _field.tintColor = [UIColor systemBlueColor];
    _field.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:SGSUIKitString(@"Search")
            attributes:@{NSForegroundColorAttributeName: [UIColor secondaryLabelColor]}];
    _field.returnKeyType = UIReturnKeySearch;
    _field.autocorrectionType = UITextAutocorrectionTypeNo;
    _field.spellCheckingType = UITextSpellCheckingTypeNo;
    _field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _field.clearButtonMode = UITextFieldViewModeWhileEditing;
    _field.delegate = self;
    [_field addTarget:self action:@selector(fieldChanged) forControlEvents:UIControlEventEditingChanged];
    [_pill.contentView addSubview:_field];

    _mic = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *micCfg =
        [UIImageSymbolConfiguration configurationWithPointSize:17 weight:UIImageSymbolWeightMedium];
    [_mic setImage:[UIImage systemImageNamed:@"mic.fill" withConfiguration:micCfg] forState:UIControlStateNormal];
    _mic.tintColor = [UIColor secondaryLabelColor];
    [_mic addTarget:self action:@selector(micTapped) forControlEvents:UIControlEventTouchUpInside];
    _mic.accessibilityLabel = @"Dictation";
    [_pill.contentView addSubview:_mic];

    _close = [[SGSCloseButton alloc] initWithFrame:CGRectMake(0, 0, kBarHeight, kBarHeight)];
    [_close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    _close.alpha = 0;
    _close.userInteractionEnabled = NO;
    [self addSubview:_close];

    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc addObserver:self selector:@selector(keyboardWillChange:)
               name:UIKeyboardWillChangeFrameNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillHide:)
               name:UIKeyboardWillHideNotification object:nil];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (UITextField *)textField { return _field; }
- (BOOL)searching { return _searching; }

#pragma mark layout

// Only the pill and the X button take touches; everything else falls through to Settings.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!_barVisible || self.hidden || self.alpha < 0.01) return nil;
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

- (CGFloat)restingBottomInset {
    CGFloat safe = self.safeAreaInsets.bottom;
    return safe > 0 ? MAX(safe - 14.0, 10.0) : 12.0;    // sits just above the home indicator
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat W = CGRectGetWidth(self.bounds);
    CGFloat H = CGRectGetHeight(self.bounds);

    CGFloat bottom = _keyboardOverlap > 0 ? _keyboardOverlap + kKeyboardGap : [self restingBottomInset];
    CGFloat y = H - bottom - kBarHeight;

    CGFloat pillW = W - 2 * kSideMargin - (_searching ? (kBarHeight + kGap) : 0);
    _pill.frame = CGRectMake(kSideMargin, y, MAX(pillW, kBarHeight), kBarHeight);
    _close.frame = CGRectMake(W - kSideMargin - kBarHeight, y, kBarHeight, kBarHeight);

    // pill content
    CGFloat w = CGRectGetWidth(_pill.bounds);
    CGFloat h = CGRectGetHeight(_pill.bounds);
    _icon.frame = CGRectMake(14, 0, 24, h);
    _mic.frame = CGRectMake(w - 14 - 28, 0, 28, h);
    CGFloat fx = CGRectGetMaxX(_icon.frame) + 4;
    _field.frame = CGRectMake(fx, 0, MAX(CGRectGetMinX(_mic.frame) - 4 - fx, 40), h);
}

- (void)relayoutWithDuration:(NSTimeInterval)duration options:(UIViewAnimationOptions)options {
    [self setNeedsLayout];
    if (duration <= 0 || !self.window) { [self layoutIfNeeded]; return; }
    [UIView animateWithDuration:duration delay:0
                        options:options | UIViewAnimationOptionBeginFromCurrentState
                     animations:^{ [self layoutIfNeeded]; } completion:nil];
}

#pragma mark state

- (void)setSearching:(BOOL)searching animated:(BOOL)animated {
    if (_searching == searching) return;
    _searching = searching;
    _close.userInteractionEnabled = searching;

    void (^apply)(void) = ^{
        self->_close.alpha = searching ? 1 : 0;
        self->_close.transform = searching ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.6, 0.6);
        [self layoutIfNeeded];
    };
    [self setNeedsLayout];
    if (animated && self.window) {
        [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.2
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:apply completion:nil];
    } else {
        apply();
    }
}

- (void)setBarVisible:(BOOL)visible animated:(BOOL)animated {
    _barVisible = visible;
    void (^apply)(void) = ^{
        self.alpha = visible ? 1 : 0;
        self.transform = visible ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(0, 14);
    };
    if (animated && self.window) {
        [UIView animateWithDuration:0.25 delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction
                         animations:apply completion:nil];
    } else {
        apply();
    }
    if (!visible) [_field resignFirstResponder];
}

- (void)resetAnimated:(BOOL)animated {
    _field.text = @"";
    [_field resignFirstResponder];
    [self setSearching:NO animated:animated];
}

#pragma mark keyboard

- (void)keyboardWillChange:(NSNotification *)note {
    if (!_field.isFirstResponder) return;
    CGRect end = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect local = [self convertRect:end fromView:nil];
    CGFloat overlap = MAX(0, CGRectGetHeight(self.bounds) - CGRectGetMinY(local));
    [self applyKeyboardOverlap:overlap note:note];
}

- (void)keyboardWillHide:(NSNotification *)note {
    [self applyKeyboardOverlap:0 note:note];
}

- (void)applyKeyboardOverlap:(CGFloat)overlap note:(NSNotification *)note {
    if (fabs(_keyboardOverlap - overlap) < 0.5) return;
    _keyboardOverlap = overlap;
    NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    NSInteger curve = [note.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [self relayoutWithDuration:duration options:(UIViewAnimationOptions)(curve << 16)];
}

#pragma mark actions

- (void)fieldChanged {
    [self.delegate sgsSearchBar:self textDidChange:_field.text ?: @""];
}

- (void)closeTapped {
    [self.delegate sgsSearchBarDidTapClose:self];
}

- (void)micTapped {
    [_field becomeFirstResponder];
    // UIKit's own dictation controller (private, so strictly guarded)
    Class cls = NSClassFromString(@"UIDictationController");
    SEL shared = NSSelectorFromString(@"sharedInstance");
    SEL start = NSSelectorFromString(@"startDictation");
    if ([cls respondsToSelector:shared]) {
        id ctrl = ((id (*)(Class, SEL))objc_msgSend)(cls, shared);
        if ([ctrl respondsToSelector:start]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                ((void (*)(id, SEL))objc_msgSend)(ctrl, start);
            });
        }
    }
}

#pragma mark UITextFieldDelegate

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self.delegate sgsSearchBarDidBeginEditing:self];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];     // keep results, just lower the keyboard
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    dispatch_async(dispatch_get_main_queue(), ^{ [self fieldChanged]; });
    return YES;
}

@end
