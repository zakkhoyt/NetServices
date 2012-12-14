

#import <UIKit/UIKit.h>

@class CryptoServer;

@interface KeyGeneration : UIViewController {
    IBOutlet UIActivityIndicatorView * spinner;
    IBOutlet UILabel * label;
    CryptoServer *server;
}

@property (nonatomic, retain) UIActivityIndicatorView * spinner;
@property (nonatomic, retain) UILabel * label;
@property (nonatomic, retain) CryptoServer * server;

- (IBAction)startGeneratingKeys;
- (IBAction)cancelKeyGeneration;
- (void)generateKeyPairOperation;
- (void)generateKeyPairCompleted;

@end
