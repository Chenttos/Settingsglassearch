// SettingsGlassSearch
// Floating iOS 26 style Liquid Glass search bar for the Settings app (iOS 15 - 18).
//
// How it works:
//   * The stock search bar under the "Settings" title is lifted out of the navigation item
//     (the UISearchController is kept alive) so the top of the page is clean.
//   * A glass pill (SGSSearchBarView) floats at the bottom of the screen, above the keyboard
//     while typing, with a round X button next to it - like iOS 26.
//   * Typing in the pill is forwarded into the stock UISearchController, so Settings' own
//     search (index, results, row selection) keeps working untouched.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "SGSSearchBarView.h"

#define SGSLog(fmt, ...) NSLog(@"[SettingsGlassSearch] " fmt, ##__VA_ARGS__)

@interface PSUIPrefsListController : UIViewController
@end

static const void *kSGSCoordinatorKey = &kSGSCoordinatorKey;

#pragma mark - coordinator

@interface SGSCoordinator : NSObject <SGSSearchBarViewDelegate>
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, strong) UISearchController *searchController;   // the stock one, kept alive here
@property (nonatomic, strong) SGSSearchBarView *bar;
@property (nonatomic, assign) BOOL searchActive;
@property (nonatomic, assign) BOOL stripping;
@property (nonatomic, assign) BOOL insetsApplied;
- (instancetype)initWithController:(UIViewController *)controller;
- (void)controllerWillAppear;
- (void)controllerWillDisappear;
- (void)stripStockSearchBar;
@end

@implementation SGSCoordinator

- (instancetype)initWithController:(UIViewController *)controller {
    self = [super init];
    if (!self) return nil;
    _controller = controller;
    _bar = [[SGSSearchBarView alloc] initWithFrame:CGRectZero];
    _bar.delegate = self;
    return self;
}

#pragma mark finding / hiding the stock search UI

- (UISearchController *)findStockSearchController {
    UIViewController *vc = self.controller;
    UISearchController *sc = vc.navigationItem.searchController;
    for (NSString *key in @[@"searchController", @"_searchController"]) {
        if (sc) break;
        @try {
            id candidate = [vc valueForKey:key];
            if ([candidate isKindOfClass:UISearchController.class]) sc = candidate;
        } @catch (__unused NSException *e) {}
    }
    return sc;
}

/// Take the stock search bar out of the nav bar, but keep the controller.
- (void)stripStockSearchBar {
    if (self.searchActive || self.stripping) return;
    UIViewController *vc = self.controller;
    if (!vc) return;

    self.stripping = YES;                    // setting the item re-lays-out the nav bar; never recurse
    @try {
        UISearchController *sc = [self findStockSearchController];
        if (sc) self.searchController = sc;
        if (vc.navigationItem.searchController) vc.navigationItem.searchController = nil;
    } @catch (NSException *e) {
        SGSLog(@"strip failed: %@", e);
    }
    self.stripping = NO;
}

#pragma mark install into the nav controller

- (void)installIfNeeded {
    UIViewController *vc = self.controller;
    UIView *host = vc.navigationController.view ?: vc.view.window;
    if (!host) return;

    if (self.bar.superview != host) {
        self.bar.frame = host.bounds;
        [host addSubview:self.bar];
        SGSLog(@"pill installed in %@ (host %@, LiquidAss glass: %d)", vc, NSStringFromClass(host.class),
               NSClassFromString(@"LGLiveBackdropView") != Nil);
    }
    if (!CGRectEqualToRect(self.bar.frame, host.bounds)) self.bar.frame = host.bounds;
    [host bringSubviewToFront:self.bar];

    // keep the last rows of the list reachable above the pill
    if (!self.insetsApplied) {
        self.insetsApplied = YES;
        UIEdgeInsets extra = vc.additionalSafeAreaInsets;
        extra.bottom += 70.0;
        vc.additionalSafeAreaInsets = extra;
    }
}

- (void)controllerWillAppear {
    [self installIfNeeded];

    // Returning from a result page: if Settings dropped the search on its own, reset the pill.
    if (self.searchActive && !self.searchController.isActive) {
        [self finishSearchAnimated:NO];
    } else if (!self.searchActive) {
        [self stripStockSearchBar];
    }
    [self.bar setBarVisible:YES animated:YES];
}

- (void)controllerWillDisappear {
    // Only hide while another page is covering us (push). Modal sheets keep it.
    if (self.controller.presentedViewController) return;
    [self.bar setBarVisible:NO animated:YES];
}

#pragma mark search flow

- (void)sgsSearchBarDidBeginEditing:(SGSSearchBarView *)bar {
    [bar setSearching:YES animated:YES];
    if (self.searchActive) return;

    UIViewController *vc = self.controller;
    UISearchController *sc = self.searchController ?: [self findStockSearchController];
    if (!vc || !sc) {
        SGSLog(@"no UISearchController found on %@ - pill will only be cosmetic", vc);
        return;
    }
    self.searchController = sc;
    self.searchActive = YES;

    if ([sc respondsToSelector:@selector(setAutomaticallyShowsCancelButton:)]) {
        sc.automaticallyShowsCancelButton = NO;     // the glass X replaces "Cancel"
    }
    vc.definesPresentationContext = YES;
    vc.navigationItem.searchController = sc;        // UISearchController needs to be in the hierarchy
    sc.searchBar.alpha = 0.0;                       // ...but we don't want to see its field
    sc.searchBar.userInteractionEnabled = NO;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.searchActive) return;
        sc.active = YES;
        // UIKit may move focus to its own text field; take it back so the keyboard stays on our pill
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (self.searchActive && !self.bar.textField.isFirstResponder) {
                [self.bar.textField becomeFirstResponder];
            }
        });
    });
}

- (void)sgsSearchBar:(SGSSearchBarView *)bar textDidChange:(NSString *)text {
    UISearchController *sc = self.searchController;
    if (!sc || !self.searchActive) return;
    UISearchBar *searchBar = sc.searchBar;

    UISearchTextField *tf = searchBar.searchTextField;      // iOS 13+
    if (tf) {
        // This is the exact path a real keystroke takes, so Settings reacts the stock way.
        tf.text = text;
        [tf sendActionsForControlEvents:UIControlEventEditingChanged];
        return;
    }
    searchBar.text = text;
    id<UISearchBarDelegate> delegate = searchBar.delegate;
    if ([delegate respondsToSelector:@selector(searchBar:textDidChange:)]) {
        [delegate searchBar:searchBar textDidChange:text];
    } else if ([sc.searchResultsUpdater respondsToSelector:@selector(updateSearchResultsForSearchController:)]) {
        [sc.searchResultsUpdater updateSearchResultsForSearchController:sc];
    }
}

- (void)sgsSearchBarDidTapClose:(SGSSearchBarView *)bar {
    [self finishSearchAnimated:YES];
}

- (void)finishSearchAnimated:(BOOL)animated {
    UISearchController *sc = self.searchController;
    UIViewController *vc = self.controller;

    self.searchActive = NO;
    [self.bar resetAnimated:animated];

    if (sc) {
        sc.searchBar.text = @"";
        sc.active = NO;
    }
    NSTimeInterval delay = animated ? 0.45 : 0.0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (self.searchActive) return;                      // user started another search meanwhile
        sc.searchBar.alpha = 1.0;
        sc.searchBar.userInteractionEnabled = YES;
        if (vc.navigationItem.searchController == sc) vc.navigationItem.searchController = nil;
    });
}

@end

#pragma mark - hooks

static SGSCoordinator *SGSCoordinatorFor(UIViewController *vc) {
    SGSCoordinator *c = objc_getAssociatedObject(vc, kSGSCoordinatorKey);
    if (!c) {
        c = [[SGSCoordinator alloc] initWithController:vc];
        objc_setAssociatedObject(vc, kSGSCoordinatorKey, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return c;
}

%group SettingsRoot

%hook PSUIPrefsListController

// Everything is deferred one runloop turn and wrapped, so a surprise in Settings' own
// setup code can never take the app down with us. viewDidAppear runs it again because on the
// very first appearance the view is often not in a window yet during viewWillAppear.
static void SGSRefresh(UIViewController *vc, BOOL appeared) {
    __weak UIViewController *weakVC = vc;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *strongVC = weakVC;
        if (!strongVC || !strongVC.isViewLoaded) return;
        @try {
            SGSCoordinator *c = SGSCoordinatorFor(strongVC);
            [c controllerWillAppear];
            if (appeared) {
                // Settings sometimes attaches its search bar a moment later; one retry, no loops.
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{ [c stripStockSearchBar]; });
            }
        } @catch (NSException *e) {
            SGSLog(@"refresh failed: %@", e);
        }
    });
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    SGSRefresh(self, NO);
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    SGSRefresh(self, YES);
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    SGSCoordinator *c = objc_getAssociatedObject(self, kSGSCoordinatorKey);
    @try { [c controllerWillDisappear]; } @catch (__unused NSException *e) {}
}

%end

%end

#pragma mark - crash guard

// If Settings dies in the first moments after launch, the next launch comes up with the tweak
// switched off for a few minutes, so a bug here can't lock you out of Settings.
static NSString *const kSGSInFlightKey  = @"SGSLaunchInFlight";
static NSString *const kSGSDisabledKey  = @"SGSDisabledUntil";

static void SGSClearInFlight(void) {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d removeObjectForKey:kSGSInFlightKey];
    [d synchronize];
}

%ctor {
    // iOS 26 already ships this exact search bar - nothing to do there.
    if ([NSProcessInfo.processInfo isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){26, 0, 0}]) return;

    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;

    if ([d doubleForKey:kSGSDisabledKey] > now) {
        SGSLog(@"SAFE MODE: tweak is off for another %.0fs after a crash", [d doubleForKey:kSGSDisabledKey] - now);
        return;
    }
    // stale marker only counts if it is recent, so an old kill can't switch us off later
    double started = [d doubleForKey:kSGSInFlightKey];
    if (started > 0 && now - started < 20.0) {
        [d setDouble:now + 300.0 forKey:kSGSDisabledKey];
        [d removeObjectForKey:kSGSInFlightKey];
        [d synchronize];
        SGSLog(@"SAFE MODE: previous launch died right after start - tweak off for 5 minutes");
        return;
    }

    [d setDouble:now forKey:kSGSInFlightKey];
    [d synchronize];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ SGSClearInFlight(); });
    for (NSNotificationName name in @[UIApplicationWillResignActiveNotification,
                                      UIApplicationDidEnterBackgroundNotification]) {
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil
                                                    usingBlock:^(NSNotification *n) { SGSClearInFlight(); }];
    }

    SGSLog(@"loaded");
    %init(SettingsRoot);
}
