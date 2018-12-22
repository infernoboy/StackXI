#import "Tweak.h"

#define kClear @"CLEAR"
#define kCollapse @"COLLAPSE"
#define kOneMoreNotif @"ONE_MORE_NOTIFICATION"
#define kMoreNotifs @"MORE_NOTIFICATIONS"
#define ICON_COLLAPSE_PATH @"/Library/PreferenceBundles/StackXIPrefs.bundle/SXICollapse.png"
#define ICON_CLEAR_ALL_PATH @"/Library/PreferenceBundles/StackXIPrefs.bundle/SXIClearAll.png"
#define LANG_BUNDLE_PATH @"/Library/PreferenceBundles/StackXIPrefs.bundle/StackXILocalization.bundle"
#define TEMPWIDTH 0
#define TEMPDURATION 0.4
#define CLEAR_DURATION 0.2
#define MAX_SHOW_BEHIND 3 //amount of blank notifications to show behind each stack

extern dispatch_queue_t __BBServerQueue;

static SBDashBoardCombinedListViewController *sbdbclvc = nil;
static BBServer *bbServer = nil;
static NCNotificationPriorityList *priorityList = nil;
static NCNotificationListCollectionView *listCollectionView = nil;
static NCNotificationCombinedListViewController *clvc = nil;
static NCNotificationStore *store = nil;
static NCNotificationDispatcher *dispatcher = nil;
static bool showButtons = false;
static bool useIcons = false;
static bool canUpdate = true;
static bool isOnLockscreen = true;
static NSDictionary<NSString*, NSString*> *translationDict;

UIImage * imageWithView(UIView *view) {
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@interface UIButton(Blur)
- (void)addBlurEffect;
@end

@implementation UIButton(Blur)

- (void)addBlurEffect {
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    blur.frame = self.bounds;
    blur.userInteractionEnabled = false;
    [self insertSubview:blur atIndex:0];
    if (UIImageView *imageView = self.imageView) {
        [self bringSubviewToFront:imageView];
    }
}

@end

static void fakeNotification(NSString *sectionID, NSDate *date, NSString *message) {
    dispatch_sync(__BBServerQueue, ^{
        BBBulletin *bulletin = [[BBBulletin alloc] init];

        bulletin.title = @"StackXI";
        bulletin.message = message;
        bulletin.sectionID = sectionID;
        bulletin.bulletinID = [[NSProcessInfo processInfo] globallyUniqueString];
        bulletin.recordID = [[NSProcessInfo processInfo] globallyUniqueString];
        bulletin.publisherBulletinID = [[NSProcessInfo processInfo] globallyUniqueString];
        bulletin.date = date;
        bulletin.defaultAction = [BBAction actionWithLaunchBundleID:sectionID callblock:nil];

        [bbServer publishBulletin:bulletin destinations:4 alwaysToLockScreen:YES];
    });
}

static void fakeNotifications() {
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 1!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 2!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 3!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 4!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 5!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 6!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 7!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 8!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 9!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 10!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 11!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 12!");
    fakeNotification(@"com.apple.MobileSMS", [NSDate date], @"Test notification 13!");
    fakeNotification(@"com.apple.Music", [NSDate date], @"Test notification 14!");
    fakeNotification(@"com.apple.mobilephone", [NSDate date], @"Test notification 15!");
}

%group StackXIDebug


%hook BBServer
-(id)initWithQueue:(id)arg1 {
    bbServer = %orig;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        fakeNotifications();
    });

    return bbServer;
}

-(id)initWithQueue:(id)arg1 dataProviderManager:(id)arg2 syncService:(id)arg3 dismissalSyncCache:(id)arg4 observerListener:(id)arg5 utilitiesListener:(id)arg6 conduitListener:(id)arg7 systemStateListener:(id)arg8 settingsListener:(id)arg9 {
    bbServer = %orig;
    return bbServer;
}

- (void)dealloc {
  if (bbServer == self) {
    bbServer = nil;
  }
  
  %orig;
}
%end

%end

%group StackXI

%hook SBDashBoardCombinedListViewController

-(void)viewDidLoad{
    %orig;
    sbdbclvc = self; 
}

%end


%hook NCNotificationListSectionRevealHintView

-(void)layoutSubviews{
    self.alpha = 0;
    self.hidden = YES;
    %orig;
}

%end

%hook NCNotificationRequest

%property (assign,nonatomic) BOOL sxiIsStack;
%property (assign,nonatomic) BOOL sxiIsExpanded;
%property (assign,nonatomic) BOOL sxiVisible;
%property (assign,nonatomic) NSUInteger sxiPositionInStack;
%property (nonatomic,retain) NSMutableOrderedSet *sxiStackedNotificationRequests;

-(id)init {
    id orig = %orig;
    self.sxiStackedNotificationRequests = [[NSMutableOrderedSet alloc] init];
    self.sxiVisible = true;
    self.sxiIsStack = false;
    self.sxiIsExpanded = false;
    self.sxiPositionInStack = 0;
    return orig;
}

%new
-(void)sxiInsertRequest:(NCNotificationRequest *)request {
    [self.sxiStackedNotificationRequests addObject:request];
}

%new
-(void)sxiExpand {
    self.sxiIsExpanded = true;

    for (NCNotificationRequest *request in self.sxiStackedNotificationRequests) {
        request.sxiVisible = true;
    }
    
    [listCollectionView sxiExpand:self.bulletin.sectionID];
}


%new
-(void)sxiCollapse {
    self.sxiIsExpanded = false;

    for (NCNotificationRequest *request in self.sxiStackedNotificationRequests) {
        request.sxiVisible = false;
    }
    
    [listCollectionView sxiCollapse:self.bulletin.sectionID];
}

%new
-(void)sxiClear:(BOOL)reload {
    if (reload) {
        canUpdate = false;
    }
    [priorityList removeNotificationRequest:self];
    //[self.clearAction.actionRunner executeAction:self.clearAction fromOrigin:self withParameters:nil completion:nil]; - TODO: check if this helps sometimes
    [dispatcher destination:nil requestsClearingNotificationRequests:@[self]];
    [listCollectionView sxiClear:self.notificationIdentifier];
    if (reload) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, CLEAR_DURATION * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            canUpdate = true;
            [listCollectionView reloadData];
        });
    }
}

%new
-(void)sxiClearStack {
    canUpdate = false;
    for (NCNotificationRequest *request in self.sxiStackedNotificationRequests) {
        [request sxiClear:false];
    }
    
    [self sxiClear:false];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, CLEAR_DURATION * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        canUpdate = true;
        [listCollectionView reloadData];
    });
}

%end


%hook NCNotificationSectionList

-(id)removeNotificationRequest:(id)arg1 {
    //[priorityList removeNotificationRequest:(NCNotificationRequest *)arg1];
    return nil;
}

-(id)insertNotificationRequest:(id)arg1 {
    [priorityList insertNotificationRequest:(NCNotificationRequest *)arg1];
    return nil;
}

-(NSUInteger)sectionCount {
    return 0;
}

-(NSUInteger)rowCountForSectionIndex:(NSUInteger)arg1 {
    return 0;
}

-(id)notificationRequestsForSectionIdentifier:(id)arg1 {
    return nil;
}

-(id)notificationRequestsAtIndexPaths:(id)arg1 {
    return nil;
}

%end

%hook NCNotificationChronologicalList

-(id)removeNotificationRequest:(id)arg1 {
    //[priorityList removeNotificationRequest:(NCNotificationRequest *)arg1];
    return nil;
}

-(id)insertNotificationRequest:(id)arg1 {
    [priorityList insertNotificationRequest:(NCNotificationRequest *)arg1];
    return nil;
}

%end

%hook NCNotificationPriorityList

%property (nonatomic,retain) NSMutableOrderedSet* allRequests;

-(id)init {
    NSLog(@"[StackXI] Init!");
    id orig = %orig;
    priorityList = self;
    self.allRequests = [[NSMutableOrderedSet alloc] initWithCapacity:1000];
    return orig;
}

%new
-(void)sxiUpdateList {
    if (!canUpdate) return;
    [self.requests removeAllObjects];

    NSMutableDictionary* stacks = [[NSMutableDictionary alloc] initWithCapacity:1000];

    for (int i = 0; i < [self.allRequests count]; i++) {
        NCNotificationRequest *req = self.allRequests[i];
        if (req.bulletin && req.bulletin.sectionID && req.timestamp && req.options && req.options.lockScreenPriority) {
            if (stacks[req.bulletin.sectionID]) {
                if ([req.timestamp compare:stacks[req.bulletin.sectionID][@"timestamp"]] == NSOrderedDescending) {
                    stacks[req.bulletin.sectionID] = @{
                        @"timestamp" : req.timestamp,
                        @"priority" : stacks[req.bulletin.sectionID][@"priority"]
                    };
                }
                if (req.options.lockScreenPriority > [stacks[req.bulletin.sectionID][@"priority"] longValue]) {
                    stacks[req.bulletin.sectionID] = @{
                        @"timestamp" : stacks[req.bulletin.sectionID][@"timestamp"],
                        @"priority" : @(req.options.lockScreenPriority)
                    };
                }
            } else {
                stacks[req.bulletin.sectionID] = @{
                    @"timestamp" : req.timestamp,
                    @"priority" : @(req.options.lockScreenPriority)
                };
            }
        }
    }

    [self.allRequests sortUsingComparator:(NSComparator)^(id obj1, id obj2){
        NCNotificationRequest *a = (NCNotificationRequest *)obj1;
        NCNotificationRequest *b = (NCNotificationRequest *)obj2;

        if ([a.bulletin.sectionID isEqualToString:b.bulletin.sectionID]) {
            return [b.timestamp compare:a.timestamp] == NSOrderedDescending;
        }

        if (b.bulletin.sectionID && a.bulletin.sectionID && stacks[b.bulletin.sectionID] && stacks[a.bulletin.sectionID]) {
            if ([stacks[b.bulletin.sectionID][@"priority"] compare:stacks[a.bulletin.sectionID][@"priority"]] == NSOrderedSame) {
                return [stacks[b.bulletin.sectionID][@"timestamp"] compare:stacks[a.bulletin.sectionID][@"timestamp"]] == NSOrderedDescending;
            }
            return [stacks[b.bulletin.sectionID][@"priority"] compare:stacks[a.bulletin.sectionID][@"priority"]] == NSOrderedDescending;
        }

        return [a.bulletin.sectionID localizedStandardCompare:b.bulletin.sectionID] == NSOrderedAscending;
    }];

    NSString *expandedSection = nil;

    for (int i = 0; i < [self.allRequests count]; i++) {
        NCNotificationRequest *req = self.allRequests[i];
        if (req.bulletin.sectionID && req.sxiIsExpanded && req.sxiIsStack) {
            expandedSection = req.bulletin.sectionID;
            break;
        }
    }

    NSString *lastSection = nil;
    NCNotificationRequest *lastStack = nil;
    NSUInteger sxiPositionInStack = 0;

    for (int i = 0; i < [self.allRequests count]; i++) {
        NCNotificationRequest *req = self.allRequests[i];
        if (isOnLockscreen && (!req.options || (req.options && !req.options.addToLockScreenWhenUnlocked))) {
            continue;
        }

        if (req.bulletin.sectionID) {
            [req.sxiStackedNotificationRequests removeAllObjects];
            req.sxiIsStack = false;
            req.sxiVisible = false;
            req.sxiIsExpanded = false;
            req.sxiPositionInStack = ++sxiPositionInStack;

            if ([expandedSection isEqualToString:req.bulletin.sectionID]) {
                req.sxiVisible = true;
            }

            if (!lastSection || ![lastSection isEqualToString:req.bulletin.sectionID]) {
                lastSection = req.bulletin.sectionID;
                lastStack = req;

                req.sxiVisible = true;
                req.sxiIsStack = true;
                req.sxiPositionInStack = 0;
                sxiPositionInStack = 0;
                if ([expandedSection isEqualToString:req.bulletin.sectionID]) {
                    req.sxiIsExpanded = true;
                }

                [self.requests addObject:req];

                continue;
            }

            if (lastStack && [lastSection isEqualToString:req.bulletin.sectionID]) {
                [lastStack sxiInsertRequest:req];
            }
            
            if (req.sxiPositionInStack <= MAX_SHOW_BEHIND || [expandedSection isEqualToString:req.bulletin.sectionID]) {
                [self.requests addObject:req];
            }
        } else {
            req.sxiVisible = true;
            req.sxiIsStack = true;
            req.sxiIsExpanded = false;
            req.sxiPositionInStack = 0;

            [self.requests addObject:req];
        }
    }
}

-(NSUInteger)insertNotificationRequest:(NCNotificationRequest *)request {
    if (!request || !request.notificationIdentifier) return 0;

    bool found = false;

    for (int i = 0; i < [self.allRequests count]; i++) {
        NCNotificationRequest *req = self.allRequests[i];
        if ([req.notificationIdentifier isEqualToString:request.notificationIdentifier]) {
            found = true;
            [self.allRequests replaceObjectAtIndex:(NSUInteger)i withObject:request];
            break;
        }
    }

    if (!found) {
        %orig;
        request.sxiVisible = true;
        [self.allRequests addObject:request];
        [listCollectionView reloadData];
    }
    return 0;
}

-(NSUInteger)removeNotificationRequest:(NCNotificationRequest *)request {
    if (!request) return 0;

    if (request.notificationIdentifier) {
        for (int i = 0; i < [self.allRequests count]; i++) {
            NCNotificationRequest *req = self.allRequests[i];
            if ([req.notificationIdentifier isEqualToString:request.notificationIdentifier]) {
                [self.allRequests removeObjectAtIndex:i];
            }
        }
    }

    [self.allRequests removeObject:request];
    [listCollectionView reloadData];
    return 0;
}

-(id)_clearRequestsWithPersistence:(unsigned long long)arg1 {
    return nil;
}

-(id)clearNonPersistentRequests {
    return nil;
}

-(id)clearRequestsPassingTest:(id)arg1 {
    //it removes notifications on unlock/lock :c
    //so i had to disable this
    return nil;
}

-(id)clearAllRequests {
    //not sure if i want this working too :D
    return nil;
}

%new
-(void)sxiClearAll {
    canUpdate = false;
    [dispatcher destination:nil requestsClearingNotificationRequests:[self.allRequests array]];
    [self.allRequests removeAllObjects];
    [listCollectionView sxiClearAll];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, CLEAR_DURATION * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        canUpdate = true;
        [listCollectionView reloadData];
    });
}

%end

%hook NCNotificationListViewController

-(void)clearAllNonPersistent {
    // nothing
}

-(BOOL)hasVisibleContent {
    return [priorityList.requests count] > 0;
}

%end

%hook NCNotificationCombinedListViewController

-(id)init {
    id orig = %orig;
    clvc = self;
    return orig;
}

-(void)clearAllNonPersistent {
    // nothing
}

/*-(BOOL)hasContent {
    return true;
}*/

-(void)viewWillAppear:(bool)animated {
    [listCollectionView sxiCollapseAll];
    %orig;
}

-(void)viewWillDisappear:(bool)animated {
    [listCollectionView sxiCollapseAll];
    %orig;
}

-(NSInteger)numberOfSectionsInCollectionView:(id)arg1 {
    return 1;
}

-(NSInteger)collectionView:(id)arg1 numberOfItemsInSection:(NSInteger)arg2 {
    if (arg2 != 0) {
        return 0;
    }

    return %orig;
}

-(NCNotificationListCell*)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section > 0) {
        return nil;
    }

    NCNotificationRequest* request = [self.notificationPriorityList.requests objectAtIndex:indexPath.row];
    if (!request) {
        NSLog(@"[StackXI] request is gone");
        return nil;
    }

    NCNotificationListCell* cell = %orig;
    
    if (!cell.contentViewController.notificationRequest.sxiVisible) {
        if (cell.contentViewController.notificationRequest.sxiPositionInStack > MAX_SHOW_BEHIND) {
            cell.hidden = YES; 
        } else {
            cell.hidden = NO;
            if (cell.frame.size.height != 50) {
                cell.frame = CGRectMake(cell.frame.origin.x + (10 * cell.contentViewController.notificationRequest.sxiPositionInStack), cell.frame.origin.y - 50, cell.frame.size.width - (20 * cell.contentViewController.notificationRequest.sxiPositionInStack), 50);
            }
        }
    } else {
        cell.hidden = NO;
    }
    
    return cell;
}

-(CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section > 0) {
        return CGSizeZero;
    }

    CGSize orig = %orig;
    if (indexPath.section == 0) {
        NCNotificationRequest *request = [self.notificationPriorityList.requests objectAtIndex:indexPath.row];
        if (!request.sxiVisible) {
            if (request.sxiPositionInStack > MAX_SHOW_BEHIND) {
                return CGSizeMake(orig.width,0);
            } else {
                return CGSizeMake(orig.width,1);
            }
        }

        if (request.sxiIsStack && !request.sxiIsExpanded && [request.sxiStackedNotificationRequests count] > 0) {
            return CGSizeMake(orig.width,orig.height + 15);
        }
    }
    return orig;
}

-(void)_clearAllPriorityListNotificationRequests {
    [priorityList sxiClearAll];
}

-(void)_clearAllSectionListNotificationRequests {
    //[priorityList sxiClearAll];
}

-(void)_moveNotificationRequestsToHistorySectionPassingTest:(/*^block*/id)arg1 animated:(BOOL)arg2 movedAll:(BOOL)arg3 {
    //do nothing
}

-(BOOL)modifyNotificationRequest:(NCNotificationRequest*)arg1 forCoalescedNotification:(id)arg2 {
    [priorityList insertNotificationRequest:arg1];
    return true;
}

%end

%hook NCNotificationListCell


-(void)layoutSubviews {
    /*//NSLog(@"[StackXI] SUBVIEWS!!!!");
    if (self.contentViewController.notificationRequest.sxiIsStack && !self.contentViewController.notificationRequest.sxiIsExpanded) {
        //NSLog(@"[StackXI] STACK CELL!!!!");
        [self.rightActionButtonsView.defaultActionButton setTitle: @"Clear All"];
        [self.rightActionButtonsView.defaultActionButton.titleLabel setText: @"Clear All"];
    } else {
        [self.rightActionButtonsView.defaultActionButton setTitle: @"Clear"];
        [self.rightActionButtonsView.defaultActionButton.titleLabel setText: @"Clear"];
    }*/
    %orig;
    if (!self.contentViewController.notificationRequest.sxiIsStack) {
        [listCollectionView sendSubviewToBack:self];
    }
}

-(void)cellClearButtonPressed:(id)arg1 {
    [self _executeClearAction];
}

-(void)_executeClearAction {
    if (self.contentViewController.notificationRequest.sxiIsStack && !self.contentViewController.notificationRequest.sxiIsExpanded) {
        [self.contentViewController.notificationRequest sxiClearStack];
        return;
    }

    [self.contentViewController.notificationRequest sxiClear:true];
}

%end

%hook NCNotificationDispatcher

-(id)init {
    id orig = %orig;
    dispatcher = self;
    return orig;
}

-(id)initWithAlertingController:(id)arg1 {
    id orig = %orig;
    dispatcher = self;
    return orig;
}

%end

%hook NCNotificationStore

-(id)init {
    id orig = %orig;
    store = self;
    return orig;
}

-(id)insertNotificationRequest:(NCNotificationRequest*)arg1 {
    [priorityList insertNotificationRequest:arg1];
    return %orig;
}

-(id)removeNotificationRequest:(NCNotificationRequest*)arg1 {
    [priorityList removeNotificationRequest:arg1];
    return %orig;
}

-(id)replaceNotificationRequest:(NCNotificationRequest*)arg1 {
    [priorityList insertNotificationRequest:arg1];
    return %orig;
}

%end

%hook NCNotificationShortLookViewController

%property (retain) UILabel* sxiNotificationCount;
%property (retain) UIButton* sxiClearAllButton;
%property (retain) UIButton* sxiCollapseButton;
%property (assign,nonatomic) BOOL sxiIsLTR;

-(void)viewWillAppear:(bool)whatever {
    %orig;
    [self sxiUpdateCount];
}

-(void)viewDidAppear:(bool)whatever {
    %orig;
    [self sxiUpdateCount];
}

-(void)viewDidLayoutSubviews {
    [self sxiUpdateCount];
    %orig;
}

%new
-(void)sxiCollapse:(UIButton *)button {
    [self.notificationRequest sxiCollapse];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, TEMPDURATION * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [listCollectionView reloadData];
    });
}

%new
-(void)sxiClearAll:(UIButton *)button {
    [self.notificationRequest sxiClearStack];
}

%new
-(int)sxiButtonWidth {
    if (useIcons) return 45;
    return 75;
}

%new
-(int)sxiButtonSpacing {
    return 5;
}

%new
-(CGRect)sxiGetClearAllButtonFrame {
    int width = [self sxiButtonWidth];
    int spacing = [self sxiButtonSpacing];
    if (self.sxiIsLTR) {
        return CGRectMake(self.view.frame.origin.x + self.view.frame.size.width - (2*spacing) - (2*width), self.view.frame.origin.y + spacing, width, 25);
    } else {
        return CGRectMake(self.view.frame.origin.x + spacing, self.view.frame.origin.y + spacing, width, 25);
    }
}

%new
-(CGRect)sxiGetCollapseButtonFrame {
    int width = [self sxiButtonWidth];
    int spacing = [self sxiButtonSpacing];
    if (self.sxiIsLTR) {
        return CGRectMake(self.view.frame.origin.x + self.view.frame.size.width - spacing - width, self.view.frame.origin.y + spacing, width, 25);
    } else {
        return CGRectMake(self.view.frame.origin.x + (2*spacing) + width, self.view.frame.origin.y + spacing, width, 25);
    }
}

%new
-(CGRect)sxiGetNotificationCountFrame {
    return CGRectMake(self.view.frame.origin.x + 11, self.view.frame.origin.y + self.view.frame.size.height - 30, self.view.frame.size.width - 21, 25);
}

%new
-(void)sxiUpdateCount {
    bool inBanner = FALSE;
    if (!self.nextResponder || !self.nextResponder.nextResponder || ![NSStringFromClass([self.nextResponder.nextResponder class]) isEqualToString:@"NCNotificationListCell"]) {
        inBanner = TRUE; //probably, but it's a safe assumption
    }

    if (inBanner && !self.sxiNotificationCount) return;

    self.sxiIsLTR = true;
    if ([UIView userInterfaceLayoutDirectionForSemanticContentAttribute:self.view.semanticContentAttribute] == UIUserInterfaceLayoutDirectionRightToLeft) {
        self.sxiIsLTR = false;
    }

    NCNotificationShortLookView *lv = (NCNotificationShortLookView *)MSHookIvar<UIView *>(self, "_lookView");

    if (inBanner) {
        self.sxiNotificationCount.hidden = TRUE;
        if (self.sxiClearAllButton) self.sxiClearAllButton.hidden = TRUE;
        if (self.sxiCollapseButton) self.sxiCollapseButton.hidden = TRUE;

        if (lv) {
            lv.customContentView.hidden = TRUE;
            [lv _headerContentView].hidden = TRUE;
            lv.alpha = 1.0;
        }

        return;
    }

    if (!self.sxiNotificationCount) {
        self.sxiNotificationCount = [[UILabel alloc] initWithFrame:[self sxiGetNotificationCountFrame]];
        [self.sxiNotificationCount setFont:[UIFont systemFontOfSize:12]];
        self.sxiNotificationCount.numberOfLines = 1;
        self.sxiNotificationCount.clipsToBounds = YES;
        self.sxiNotificationCount.hidden = YES;
        self.sxiNotificationCount.alpha = 0.0;
        self.sxiNotificationCount.textColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
        [self.view addSubview:self.sxiNotificationCount];

        if (showButtons) {
            self.sxiClearAllButton = [[UIButton alloc] initWithFrame:[self sxiGetClearAllButtonFrame]];
            [self.sxiClearAllButton.titleLabel setFont:[UIFont systemFontOfSize:12]];
            self.sxiClearAllButton.hidden = YES;
            self.sxiClearAllButton.alpha = 0.0;
            [self.sxiClearAllButton setTitle:[translationDict objectForKey:kClear] forState: UIControlStateNormal];
            //self.sxiClearAllButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
            [self.sxiClearAllButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            self.sxiClearAllButton.layer.masksToBounds = true;
            self.sxiClearAllButton.layer.cornerRadius = 12.5;
            [self.sxiClearAllButton addBlurEffect];

            self.sxiCollapseButton = [[UIButton alloc] initWithFrame:[self sxiGetCollapseButtonFrame]];
            [self.sxiCollapseButton.titleLabel setFont:[UIFont systemFontOfSize:12]];
            self.sxiCollapseButton.hidden = YES;
            self.sxiCollapseButton.alpha = 0.0;
            [self.sxiCollapseButton setTitle:[translationDict objectForKey:kCollapse] forState:UIControlStateNormal];
            //self.sxiCollapseButton.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
            [self.sxiCollapseButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            self.sxiCollapseButton.layer.masksToBounds = true;
            self.sxiCollapseButton.layer.cornerRadius = 12.5;
            [self.sxiCollapseButton addBlurEffect];
            
            [self.sxiClearAllButton addTarget:self action:@selector(sxiClearAll:) forControlEvents:UIControlEventTouchUpInside];
            [self.sxiCollapseButton addTarget:self action:@selector(sxiCollapse:) forControlEvents:UIControlEventTouchUpInside];
            
            if (useIcons) {
                self.sxiCollapseButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
                [self.sxiCollapseButton setTitle:NULL forState:UIControlStateNormal];
                UIImage *btnCollapseImage = [UIImage imageWithContentsOfFile:ICON_COLLAPSE_PATH];
                [self.sxiCollapseButton setImage:btnCollapseImage forState:UIControlStateNormal];

                self.sxiClearAllButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
                [self.sxiClearAllButton setTitle:NULL forState:UIControlStateNormal];
                UIImage *btnClearAllImage = [UIImage imageWithContentsOfFile:ICON_CLEAR_ALL_PATH];
                [self.sxiClearAllButton setImage:btnClearAllImage forState:UIControlStateNormal];
            }

            [self.view addSubview:self.sxiClearAllButton];
            [self.view addSubview:self.sxiCollapseButton];
        }
    }

    if (showButtons) {
        [self.view bringSubviewToFront:self.sxiClearAllButton];
        [self.view bringSubviewToFront:self.sxiCollapseButton];
    }

    if (lv && [lv _notificationContentView] && [lv _notificationContentView].primaryLabel && [lv _notificationContentView].primaryLabel.textColor) {
        self.sxiNotificationCount.textColor = [[lv _notificationContentView].primaryLabel.textColor colorWithAlphaComponent:0.8];
    }

    if (lv) {
        lv.customContentView.hidden = !self.notificationRequest.sxiVisible;
        [lv _headerContentView].hidden = !self.notificationRequest.sxiVisible;

        if (!self.notificationRequest.sxiVisible) {
            lv.alpha = 0.7;
        } else {
            lv.alpha = 1.0;
        }
    }

    self.sxiNotificationCount.frame = [self sxiGetNotificationCountFrame];
    self.sxiNotificationCount.hidden = YES;
    self.sxiNotificationCount.alpha = 0.0;

    if (showButtons) {
        self.sxiClearAllButton.frame = [self sxiGetClearAllButtonFrame];
        self.sxiCollapseButton.frame = [self sxiGetCollapseButtonFrame];

        self.sxiClearAllButton.hidden = YES;
        self.sxiClearAllButton.alpha = 0.0;

        self.sxiCollapseButton.hidden = YES;
        self.sxiCollapseButton.alpha = 0.0;
    }

    if ([NSStringFromClass([self.view.superview class]) isEqualToString:@"UIView"] && self.notificationRequest.sxiIsStack && [self.notificationRequest.sxiStackedNotificationRequests count] > 0) {
        if (!self.notificationRequest.sxiIsExpanded) {
            self.sxiNotificationCount.hidden = NO;
            self.sxiNotificationCount.alpha = 1.0;

            int count = [self.notificationRequest.sxiStackedNotificationRequests count];
            if (count == 1) {
                self.sxiNotificationCount.text = [NSString stringWithFormat:[translationDict objectForKey:kOneMoreNotif], count];
            } else {
                self.sxiNotificationCount.text = [NSString stringWithFormat:[translationDict objectForKey:kMoreNotifs], count];
            }
        } else if (showButtons) {
            self.sxiClearAllButton.hidden = NO;
            self.sxiClearAllButton.alpha = 1.0;

            self.sxiCollapseButton.hidden = NO;
            self.sxiCollapseButton.alpha = 1.0;
        }
    }

    [self.view bringSubviewToFront:self.sxiNotificationCount];
}

- (void)_handleTapOnView:(id)arg1 {
    bool inBanner = FALSE;
    if (!self.nextResponder || !self.nextResponder.nextResponder || ![NSStringFromClass([self.nextResponder.nextResponder class]) isEqualToString:@"NCNotificationListCell"]) {
        inBanner = TRUE; //probably, but it's a safe assumption
    }

    if (!inBanner && self.notificationRequest.sxiIsStack && !self.notificationRequest.sxiIsExpanded && [self.notificationRequest.sxiStackedNotificationRequests count] > 0) {
        [UIView animateWithDuration:TEMPDURATION animations:^{
            self.sxiNotificationCount.alpha = 0;
        }];
        [self.notificationRequest sxiExpand];
        return;
    }

    return %orig;
}

%end

%hook NCNotificationListCollectionView

-(id)initWithFrame:(CGRect)arg1 collectionViewLayout:(id)arg2 {
    id orig = %orig;
    listCollectionView = self;
    return orig;
}

-(void)reloadData {
    if (!canUpdate) return;
    %orig;
    [priorityList sxiUpdateList];
    [self.collectionViewLayout invalidateLayout];
    [self setNeedsLayout];
    [self layoutIfNeeded];
    for (NSInteger row = 0; row < [self numberOfItemsInSection:0]; row++) {
        id c = [self _visibleCellForIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        if (!c) continue;

        NCNotificationListCell* cell = (NCNotificationListCell*)c;
        [self sendSubviewToBack:cell];
        [(NCNotificationShortLookViewController *)cell.contentViewController sxiUpdateCount];
    }

    //LPP compatibility
    if ([self numberOfItemsInSection:0] > 0) {
        [sbdbclvc _setListHasContent:YES];
    } else {
        [sbdbclvc _setListHasContent:NO];
    }
}

%new
-(void)sxiClearAll {
    for (NSInteger row = 0; row < [self numberOfItemsInSection:0]; row++) {
        id c = [self _visibleCellForIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        if (!c) continue;
        NCNotificationListCell* cell = (NCNotificationListCell*)c;
        [UIView animateWithDuration:CLEAR_DURATION animations:^{
            cell.alpha = 0.0;
        }];
    }
}

%new
-(void)sxiClear:(NSString *)notificationIdentifier {
    for (NSInteger row = 0; row < [self numberOfItemsInSection:0]; row++) {
        id c = [self _visibleCellForIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        if (!c) continue;
        NCNotificationListCell* cell = (NCNotificationListCell*)c;
        if ([notificationIdentifier isEqualToString:cell.contentViewController.notificationRequest.notificationIdentifier]) {
            
            [UIView animateWithDuration:CLEAR_DURATION animations:^{
                cell.alpha = 0.0;
            }];
        }
    }
}

%new
-(void)sxiCollapseAll {
    NSMutableOrderedSet *sectionIDs = [[NSMutableOrderedSet alloc] initWithCapacity:100];

    for (NCNotificationRequest *request in priorityList.requests) {
        if (!request.bulletin.sectionID) continue;

        if (![sectionIDs containsObject:request.bulletin.sectionID] && request.sxiIsStack && request.sxiIsExpanded) {
            [request sxiCollapse];
            [sectionIDs addObject:request.bulletin.sectionID];
        }
    }

    [listCollectionView reloadData];
}

%new
-(void)sxiExpand:(NSString *)sectionID {
    NSMutableOrderedSet *sectionIDs = [[NSMutableOrderedSet alloc] initWithCapacity:100];
    [sectionIDs addObject:sectionID];

    // DON'T REPLACE THIS WITH sxiCollapseAll; it doesn't work because of that line above
    for (NCNotificationRequest *request in priorityList.requests) {
        if (!request.bulletin.sectionID) continue;

        if (![sectionIDs containsObject:request.bulletin.sectionID] && request.sxiIsStack && request.sxiIsExpanded) {	
            [request sxiCollapse];	
            [sectionIDs addObject:request.bulletin.sectionID];	
        }	
    }

    [listCollectionView reloadData];

    CGRect frame = CGRectMake(0,0,0,0);
    bool frameFound = false;
    for (NSInteger row = 0; row < [self numberOfItemsInSection:0]; row++) {
        id c = [self _visibleCellForIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        if (!c) continue;

        NCNotificationListCell* cell = (NCNotificationListCell*)c;
        if ([sectionID isEqualToString:cell.contentViewController.notificationRequest.bulletin.sectionID]) {
            if (!frameFound) {
                frameFound = true;
                frame = cell.frame;
                continue;
            }

            //[self sendSubviewToBack:cell];

            CGRect properFrame = cell.frame;
            cell.frame = frame;
            [UIView animateWithDuration:TEMPDURATION animations:^{
                cell.frame = properFrame;
            }];
        }
    }
}

%new
-(void)sxiCollapse:(NSString *)sectionID {
    CGRect frame = CGRectMake(0,0,0,0);
    bool frameFound = false;
    for (NSInteger row = 0; row < [self numberOfItemsInSection:0]; row++) {
        id c = [self _visibleCellForIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
        if (!c) continue;

        NCNotificationListCell* cell = (NCNotificationListCell*)c;
        if ([sectionID isEqualToString:cell.contentViewController.notificationRequest.bulletin.sectionID]) {
            if (!frameFound) {
                frameFound = true;
                frame = cell.frame;
                continue;
            }

            [UIView animateWithDuration:TEMPDURATION animations:^{
                cell.frame = frame;
            }];
        }
    }
}

-(void)deleteItemsAtIndexPaths:(id)arg1 { [self reloadData]; }
-(void)insertItemsAtIndexPaths:(id)arg1 { [self reloadData]; }
-(void)reloadItemsAtIndexPaths:(id)arg1 { [self reloadData]; }
-(void)reloadSections:(id)arg1 { [self reloadData]; }
-(void)deleteSections:(id)arg1 { [self reloadData]; }
-(void)insertSections:(id)arg1 { [self reloadData]; }
-(void)moveItemAtIndexPath:(id)prevPath toIndexPath:(id)newPath { [self reloadData]; }

-(void)performBatchUpdates:(id)updates completion:(void (^)(bool finished))completion {
	[self reloadData];
	if (completion) completion(true);
}

%end

%hook NCNotificationListCollectionViewFlowLayout

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect {
	NSArray *attrs =  %orig;

    for (UICollectionViewLayoutAttributes *attr in attrs) {
        if (attr.size.height == 0) {
            attr.hidden = YES;
        } else {
            attr.hidden = NO;
        }
    }

    return attrs;
}

%end

%hook SBDashBoardViewController

-(void)viewWillAppear:(BOOL)animated {
    %orig;

    isOnLockscreen = !self.authenticated;
    [listCollectionView sxiCollapseAll];
}

%end

%end

static void displayStatusChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    isOnLockscreen = true;
    [listCollectionView sxiCollapseAll];
}

%ctor{
    HBPreferences *file = [[HBPreferences alloc] initWithIdentifier:@"io.ominousness.stackxi"];
    bool enabled = [([file objectForKey:@"Enabled"] ?: @(YES)) boolValue];
    showButtons = [([file objectForKey:@"ShowButtons"] ?: @(NO)) boolValue];
    useIcons = [([file objectForKey:@"UseIcons"] ?: @(NO)) boolValue];
    bool debug = false;
    #ifdef DEBUG
    debug = true;
    #endif

    if (enabled) {
        NSBundle *langBundle = [NSBundle bundleWithPath:LANG_BUNDLE_PATH];
        translationDict = [@{
            kClear : langBundle ? [langBundle localizedStringForKey:kClear value:@"Clear All" table:nil] : @"Clear All",
            kCollapse : langBundle ? [langBundle localizedStringForKey:kCollapse value:@"Collapse" table:nil] : @"Collapse",
            kOneMoreNotif : langBundle ? [langBundle localizedStringForKey:kOneMoreNotif value:@"%d more notification" table:nil] : @"%d more notification",
            kMoreNotifs : langBundle ? [langBundle localizedStringForKey:kMoreNotifs value:@"%d more notifications" table:nil] : @"%d more notifications"
        } retain];
        [langBundle release];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, displayStatusChanged, CFSTR("com.apple.iokit.hid.displayStatus"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        %init(StackXI);
        if (debug) %init(StackXIDebug);
    }
}
