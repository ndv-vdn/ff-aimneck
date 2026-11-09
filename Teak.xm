#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define FF_BUNDLE @"com.dts.freefireth"

static void show_menu(void) {
    UIWindow *w = UIApplication.sharedApplication.keyWindow;
    UIViewController *vc = w.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    if (!vc) return;
    
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Menu Freddy" message:@"Build thanh cong!" preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Dong" style:UIAlertActionStyleDefault handler:nil]];
    [vc presentViewController:a animated:YES completion:nil];
}

__attribute__((constructor)) static void init_aimneck(void) {
    if (![NSBundle.mainBundle.bundleIdentifier isEqualToString:FF_BUNDLE]) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        UITapGestureRecognizer *g = [[UITapGestureRecognizer alloc] init];
        g.numberOfTapsRequired = 2; 
        g.numberOfTouchesRequired = 2;
        [UIApplication.sharedApplication.keyWindow addGestureRecognizer:g];
        SEL sel = NSSelectorFromString(@"handleGesture:");
        IMP imp = imp_implementationWithBlock(^(id self, id gr){ show_menu(); });
        class_addMethod([g class], sel, imp, "v@:@");
        [g addTarget:g action:sel];
    });
}
