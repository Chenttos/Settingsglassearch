#import <UIKit/UIKit.h>

@class SGSSearchBarView;

@protocol SGSSearchBarViewDelegate <NSObject>
- (void)sgsSearchBarDidBeginEditing:(SGSSearchBarView *)bar;
- (void)sgsSearchBar:(SGSSearchBarView *)bar textDidChange:(NSString *)text;
- (void)sgsSearchBarDidTapClose:(SGSSearchBarView *)bar;
@end

/// Full-size, touch-transparent overlay that hosts the floating iOS 26 style search pill
/// (and the round "X" button that appears next to it while searching).
@interface SGSSearchBarView : UIView

@property (nonatomic, weak) id<SGSSearchBarViewDelegate> delegate;
@property (nonatomic, readonly) UITextField *textField;

/// YES while a search is in progress: the pill shrinks and the X button appears.
@property (nonatomic, readonly) BOOL searching;
- (void)setSearching:(BOOL)searching animated:(BOOL)animated;

/// Fade / slide the whole bar in or out (used when pushing and popping pages).
- (void)setBarVisible:(BOOL)visible animated:(BOOL)animated;

/// Clear the field and leave the searching state.
- (void)resetAnimated:(BOOL)animated;

@end
