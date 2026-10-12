#import "SGSGlassView.h"
#import "SGSBlurView.h"
#import "SGSSpecularView.h"
#import <objc/message.h>
#import <objc/runtime.h>

// Same filter type LiquidAss uses for the Home Screen / App Library search pill,
// which is exactly the look of the iOS 26 search bar (fully round, strong refraction).
static NSString *const kSGSFilterType = @"dylv.liquidglass.searchpill";

static void SGSSend0(id obj, SEL sel) {
    if ([obj respondsToSelector:sel]) ((void (*)(id, SEL))objc_msgSend)(obj, sel);
}

@implementation SGSGlassView {
    SGSBlurView *_blur;
    UIView *_live;          // LGLiveBackdropView (looked up at runtime, never linked)
    UIView *_tint;
    SGSSpecularView *_specular;
    UIView *_content;
    CGFloat _appliedRadius;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self) return nil;

    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = NO;                       // shadow lives on this layer
    _appliedRadius = -1;

    // iOS 26 style floating shadow
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOpacity = 0.14;
    self.layer.shadowRadius = 14.0;
    self.layer.shadowOffset = CGSizeMake(0, 5);

    Class liveClass = NSClassFromString(@"LGLiveBackdropView");
    BOOL hasLiquidAss = (liveClass != Nil);

    // 1. blur. Light under the refraction layer, heavier frosted look when we're on our own.
    _blur = [[SGSBlurView alloc] initWithFrame:self.bounds blurRadius:hasLiquidAss ? 3.0 : 18.0];
    _blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_blur];

    // 2. refraction
    if (hasLiquidAss) {
        id live = ((id (*)(id, SEL, CGRect, NSString *, NSString *))objc_msgSend)(
            [liveClass alloc], @selector(initWithFrame:groupName:filterType:),
            self.bounds, nil, kSGSFilterType);
        if ([live isKindOfClass:UIView.class]) {
            _live = live;
            _live.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            _live.userInteractionEnabled = NO;
            [self addSubview:_live];

            // LiquidAss' own host code re-applies filters a few times after creation
            // to win the registration race with backboardd - do the same.
            __weak typeof(self) weakSelf = self;
            for (NSNumber *delay in @[@1.5, @3.0, @5.0, @8.0, @12.0]) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ [weakSelf refreshGlass]; });
            }
        }
    }

    // 3. tint (values from LGButtonView)
    _tint = [[UIView alloc] initWithFrame:self.bounds];
    _tint.userInteractionEnabled = NO;
    _tint.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tint.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithWhite:1.0 alpha:0.06]
            : [UIColor colorWithWhite:1.0 alpha:0.12];
    }];
    [self addSubview:_tint];

    // 4. rim light, fallback only
    if (!_live) {
        _specular = [[SGSSpecularView alloc] initWithFrame:self.bounds cornerRadius:frame.size.height * 0.5];
        _specular.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_specular];
    }

    _content = [[UIView alloc] initWithFrame:self.bounds];
    _content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_content];

    return self;
}

- (UIView *)contentView { return _content; }
- (BOOL)usesLiquidAss { return _live != nil; }

- (void)refreshGlass {
    [_blur applyFilters];
    SGSSend0(_live, @selector(applyFilters));
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self refreshGlass];
}

- (void)layoutSubviews {
    [super layoutSubviews];

    CGFloat radius = MIN(CGRectGetWidth(self.bounds), CGRectGetHeight(self.bounds)) * 0.5;
    if (radius <= 0) return;

    self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:radius].CGPath;

    if (fabs(radius - _appliedRadius) > 0.01) {
        _appliedRadius = radius;

        _blur.cornerRadius = radius;
        _blur.layer.cornerCurve = kCACornerCurveCircular;

        _tint.layer.cornerRadius = radius;
        _tint.layer.cornerCurve = kCACornerCurveCircular;
        if (_live) {
            // exactly what LiquidAss does when it injects glass into a material view
            _live.layer.cornerCurve = kCACornerCurveCircular;
            _live.layer.masksToBounds = YES;
            _live.layer.cornerRadius = radius;
            SGSSend0(_live, @selector(updateSpecular));
            SGSSend0(_live, @selector(applyFilters));
        }
        _specular.cornerRadius = radius;
    }
}

@end
