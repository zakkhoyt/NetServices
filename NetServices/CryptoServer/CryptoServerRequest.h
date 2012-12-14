
#import <UIKit/UIKit.h>

@class CryptoServerRequest;

@protocol CryptoServerRequestDelegate

- (void)cryptoServerRequestDidFinish:(CryptoServerRequest *)request;
- (void)cryptoServerRequestDidReceiveError:(CryptoServerRequest *)request;

@end

@interface CryptoServerRequest : NSObject {
	NSInputStream * istr;
	NSOutputStream * ostr;
	NSString * peerName;
	NSData * peerPublicKey;
	NSObject <CryptoServerRequestDelegate, NSObject> * delegate;
}

@property (nonatomic, retain) NSInputStream * istr;
@property (nonatomic, retain) NSOutputStream * ostr;
@property (nonatomic, retain) NSString * peerName;
@property (nonatomic, retain) NSData * peerPublicKey;
@property (nonatomic, assign) NSObject <CryptoServerRequestDelegate, NSObject> * delegate;

- (id)initWithInputStream:(NSInputStream *)readStream 
			 outputStream:(NSOutputStream *) writeStream 
					 peer:(NSString *)peerAddress 
				 delegate:(NSObject <CryptoServerRequestDelegate, NSObject> *)anObject;
- (NSData *)receiveData;
- (NSUInteger)sendData:(NSData *)outData;
- (NSData *)createBlob:(NSString *)peer peerPublicKey:(NSData *)peerKey;
- (void)createBlobAndSend;
- (void)runProtocol;

@end
