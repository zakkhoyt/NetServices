
#import <UIKit/UIKit.h>
#import "CryptoServerRequest.h"

NSString * const CryptoServerErrorDomain;

typedef enum {
    kCryptoServerCouldNotBindToIPv4Address = 1,
    kCryptoServerCouldNotBindToIPv6Address = 2,
    kCryptoServerNoSocketsAvailable = 3,
	kCryptoServerCouldNotBindOrEstablishNetService = 4
} CryptoServerErrorCode;

@interface CryptoServer : NSObject <CryptoServerRequestDelegate> {
	NSMutableSet * connectionBag;
	NSNetService * netService;
	CFSocketRef ipv4socket;
}

@property (nonatomic, retain) NSNetService * netService;
@property (nonatomic, retain) NSMutableSet * connectionBag;
@property (assign) CFSocketRef ipv4socket;

- (id)init;
- (void)run;
- (void)setupServer:(NSError **)error;
- (void)handleConnection:(NSString *)peerName inputStream:(NSInputStream *)readStream outputStream:(NSOutputStream *)writeStream;
- (void)teardown;
- (void)cryptoServerRequestDidFinish:(CryptoServerRequest *)request;

@end
