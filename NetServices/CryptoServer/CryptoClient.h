
#import <UIKit/UIKit.h>

@class CryptoClient;

@protocol CryptoClientDelegate

- (void)cryptoClientDidCompleteConnection:(CryptoClient *)cryptoClient;
- (void)cryptoClientDidReceiveError:(CryptoClient *)cryptoClient;
- (void)cryptoClientWillBeginReceivingData:(CryptoClient *)cryptClient;
- (void)cryptoClientDidFinishReceivingData:(CryptoClient *)cryptClient;
- (void)cryptoClientWillBeginVerifyingData:(CryptoClient *)cryptClient;
- (void)cryptoClientDidFinishVerifyingData:(CryptoClient *)cryptClient verified:(BOOL)verified;

@end

@interface CryptoClient : NSObject {
	NSNetService * service;
	NSInputStream * istr;
	NSOutputStream * ostr;
	NSObject <CryptoClientDelegate, NSObject> * delegate;
	BOOL isConnected;
}

@property (nonatomic, retain) NSNetService * service;
@property (nonatomic, assign) NSObject <CryptoClientDelegate, NSObject> * delegate;
@property (nonatomic, retain) NSInputStream * istr;
@property (nonatomic, retain) NSOutputStream * ostr;
@property (nonatomic) BOOL isConnected;

- (id)initWithService:(NSNetService *)serviceInstance delegate:(NSObject <CryptoClientDelegate, NSObject> *)anObject;
- (NSData *)receiveData;
- (NSUInteger)sendData:(NSData *)outData;
- (void)runConnection;
- (BOOL)verifyBlob:(NSData *)blob;
- (void)forwardVerificationToDelegate:(NSNumber *)verified;

@end
