
#import "CryptoClient.h"
#import "SecKeyWrapper.h"
#import "CryptoCommon.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <unistd.h>
#import <arpa/inet.h>

@implementation CryptoClient

@synthesize service, istr, ostr, delegate, isConnected;

- (id)initWithService:(NSNetService *)serviceInstance delegate:(NSObject <CryptoClientDelegate, NSObject> *)anObject {
	if (self = [super init]) {
		self.service = serviceInstance;
        self.delegate = anObject;
		self.isConnected = NO;
		[self.service getInputStream:&istr outputStream:&ostr];
	}
	
	return self;
}

- (void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode
{
	switch(eventCode) {
		case NSStreamEventOpenCompleted:
		{
			if ([self.ostr streamStatus] == NSStreamStatusOpen && [self.istr streamStatus] == NSStreamStatusOpen && !self.isConnected) {
				[delegate performSelectorOnMainThread:@selector(cryptoClientDidCompleteConnection:) withObject:self waitUntilDone:NO];
				self.isConnected = YES;
			}
		}
		case NSStreamEventHasSpaceAvailable:
		{
			if (stream == self.ostr) {
				if ([(NSOutputStream *) stream hasSpaceAvailable]) { 
					size_t retLen = 0;
					NSData * publicKey = [[SecKeyWrapper sharedWrapper] getPublicKeyBits];
					retLen = [self sendData:publicKey];
					
					LOGGING_FACILITY1( retLen == [publicKey length], @"Attempt to send public key failed, only sent %d bytes.", (int)retLen );
					
					[self.ostr close];
				}
			}
			break;
		}
		case NSStreamEventHasBytesAvailable:
		{
			if (stream == self.istr) {
				[delegate performSelectorOnMainThread:@selector(cryptoClientWillBeginReceivingData:) withObject:self waitUntilDone:NO];
				NSData * theBlob = [self receiveData];
				[self.istr close];
				[delegate performSelectorOnMainThread:@selector(cryptoClientDidFinishReceivingData:) withObject:self waitUntilDone:NO];
				if (theBlob) {
					[delegate performSelectorOnMainThread:@selector(cryptoClientWillBeginVerifyingData:) withObject:self waitUntilDone:NO];
					BOOL verify = [self verifyBlob:theBlob];
					[self performSelectorOnMainThread:@selector(forwardVerificationToDelegate:) withObject:[NSNumber numberWithBool:verify] waitUntilDone:NO];
				} else {
					LOGGING_FACILITY( 0, @"Connected Server sent too large of a blob." );
					[delegate cryptoClientDidReceiveError:self];
				}
			}
			break;
		}
		case NSStreamEventErrorOccurred:
		{
			// No debugging facility because we don't want to exit even in DEBUG.
			// It's annoying.
			NSLog(@"stream: %@", stream);
			[delegate cryptoClientDidReceiveError:self];
			break;
		}
		default:
			break;
	}
}

- (void)runConnection {
	
	LOGGING_FACILITY( self.istr != nil && self.ostr != nil, @"Streams not set up properly." );
	
	if (self.istr && self.ostr) {
		self.istr.delegate = self;
		[self.istr scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
		[self.istr open];
		self.ostr.delegate = self;
		[self.ostr scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
		[self.ostr open];
	}
}

- (void)forwardVerificationToDelegate:(NSNumber *)verified {
    [delegate cryptoClientDidFinishVerifyingData:self verified:[verified boolValue]];
}

- (NSData *)receiveData {
	int len = 0;
	size_t lengthByte = 0;
	NSMutableData * retBlob = nil;
	
	len = [self.istr read:(uint8_t *)&lengthByte maxLength:sizeof(size_t)];
	
	LOGGING_FACILITY1( len == sizeof(size_t), @"Read failure errno: [%d]", errno );
	
	if (lengthByte <= kMaxMessageLength && len == sizeof(size_t)) {
		retBlob = [NSMutableData dataWithLength:lengthByte];
		
		len = [self.istr read:(uint8_t *)[retBlob mutableBytes] maxLength:lengthByte];
		
		LOGGING_FACILITY1( len == lengthByte, @"Read failure, after buffer errno: [%d]", errno );
		
		if (len != lengthByte) {
			retBlob = nil;
		}
	}
	
	return retBlob;
}

- (NSUInteger)sendData:(NSData *)outData {
	size_t len = 0;
	
	if (outData) {
		len = [outData length];
		if (len > 0) {
			size_t longSize = sizeof(size_t);
	
			NSMutableData * message = [[NSMutableData alloc] initWithCapacity:(len + longSize)];
			[message appendBytes:(const void *)&len length:longSize];
			[message appendData:outData];
	
			[self.ostr write:[message bytes] maxLength:[message length]];
			[message release];
		}
	}
	
	return len;
}

- (BOOL)verifyBlob:(NSData *)blob {
	NSMutableDictionary * message = nil;
	NSString * error = nil;
	NSString * peerName = nil;
	BOOL verified = NO;
	CCOptions pad = 0;
	SecKeyRef publicKeyRef = NULL;
	
	peerName = [self.service name];
	
	message = [NSPropertyListSerialization propertyListFromData:blob mutabilityOption:NSPropertyListMutableContainers format:nil errorDescription:&error];
	
	if (!error) {
		
		// Get the unwrapped symmetric key.
		NSData * symmetricKey = [[SecKeyWrapper sharedWrapper] unwrapSymmetricKey:(NSData *)[message objectForKey:[NSString stringWithUTF8String:(const char *)kSymTag]]];
		
		// Get the padding PKCS#7 flag.
		pad = [(NSNumber *)[message objectForKey:[NSString stringWithUTF8String:(const char *)kPadTag]] unsignedIntValue];
		
		// Get the encrypted message and decrypt.
		NSData * plainText = [[SecKeyWrapper sharedWrapper]	doCipher:(NSData *)[message objectForKey:[NSString stringWithUTF8String:(const char *)kMesTag]]
																 key:symmetricKey
															 context:kCCDecrypt 
															 padding:&pad];
		
		// Add peer public key.
		publicKeyRef = [[SecKeyWrapper sharedWrapper] addPeerPublicKey:peerName 
															   keyBits:(NSData *)[message objectForKey:[NSString stringWithUTF8String:(const char *)kPubTag]]];
		
		// Verify the signature.
		verified = [[SecKeyWrapper sharedWrapper] verifySignature:plainText
														secKeyRef:publicKeyRef
														signature:(NSData *)[message objectForKey:[NSString stringWithUTF8String:(const char *)kSigTag]]];
		
		// Clean up by removing the peer public key.
		[[SecKeyWrapper sharedWrapper] removePeerPublicKey:peerName];
	} else {
		LOGGING_FACILITY( 0, error );
		[error release];
	}
	
	return verified;
}

-(void) dealloc {
	[istr removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[istr release];
	
	[ostr removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[ostr release];
	
	[service release];
	[super dealloc];
}

@end
