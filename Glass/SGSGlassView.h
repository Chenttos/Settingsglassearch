#import <UIKit/UIKit.h>

/// Pill / circle of "Liquid Glass".
///
/// Layer stack (same recipe as LiquidAss' LGButtonView / LGFramework README):
///   1. SGSBlurView        - CABackdropLayer + gaussianBlur (derived from LGAdjustableBlurView)
///   2. LGLiveBackdropView - live refraction, taken from LiquidAss at runtime when it is installed
///   3. tint
///   4. SGSSpecularView    - rim light (only when LiquidAss is missing; LGLiveBackdropView draws its own)
///
/// Fully rounded: corner radius is always height / 2.
@interface SGSGlassView : UIView

/// Put your labels / icons in here. It sits above all glass layers.
@property (nonatomic, readonly) UIView *contentView;

/// YES when LiquidAss' real refraction layer is being used.
@property (nonatomic, readonly) BOOL usesLiquidAss;

/// Re-attach the refraction filters (cheap, idempotent).
- (void)refreshGlass;

@end
