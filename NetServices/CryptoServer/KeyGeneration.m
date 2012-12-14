

#import "KeyGeneration.h"
//#import "AppDelegate.h"
#import "SecKeyWrapper.h"
#import "CryptoServer.h"
#import "CryptoCommon.h"

@implementation KeyGeneration

@synthesize spinner, label, server;

- (void)viewDidLoad {
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
}

- (IBAction)startGeneratingKeys {
    [server teardown];
    // start generation operation
    [spinner startAnimating];
    spinner.hidden = NO;
    label.hidden = NO;
//    AppDelegate * appDelegate = (AppDelegate *)([UIApplication sharedApplication].delegate);
    NSInvocationOperation * genOp = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(generateKeyPairOperation) object:nil];
//    [appDelegate.cryptoQueue addOperation:genOp];
    [genOp release];
}

- (void)generateKeyPairOperation {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    // Generate the asymmetric key (public and private)
    [[SecKeyWrapper sharedWrapper] generateKeyPair:kAsymmetricSecKeyPairModulusSize];
    [[SecKeyWrapper sharedWrapper] generateSymmetricKey];
    [self performSelectorOnMainThread:@selector(generateKeyPairCompleted) withObject:nil waitUntilDone:NO];
    [pool release];
}

- (void)generateKeyPairCompleted {
	[server run];
    [spinner stopAnimating];
    spinner.hidden = YES;
    label.hidden = YES;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)cancelKeyGeneration {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc {
	[spinner release];
	[label release];
	[server release];
	[super dealloc];
}


@end
