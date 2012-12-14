

#import "CryptoServer.h"
#import "SecKeyWrapper.h"
#import "CryptoCommon.h"
#import "CryptoServerRequest.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#import <arpa/inet.h>
#include <CFNetwork/CFSocketStream.h>

NSString * const CryptoServerErrorDomain = @"CryptoServerErrorDomain";

@implementation CryptoServer

@synthesize netService, connectionBag, ipv4socket;

- (id)init {
	if (self = [super init]) {
		self.connectionBag = [[NSMutableSet alloc] init];
		NSError * thisError = nil;
		[self setupServer:&thisError];
		
		LOGGING_FACILITY( thisError == nil, [thisError localizedDescription] );

		[thisError release];
	}
	return self;
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [self teardown];
}

- (void)netServiceDidPublish:(NSNetService *)sender {
    self.netService = sender;
}

static void CryptoServerAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    CryptoServer * server = (CryptoServer *)info;
    if (kCFSocketAcceptCallBack == type) { 
        // for an AcceptCallBack, the data parameter is a pointer to a CFSocketNativeHandle
        CFSocketNativeHandle nativeSocketHandle = *(CFSocketNativeHandle *)data;
        struct sockaddr_in peerAddress;
        socklen_t peerLen = sizeof(peerAddress);
        NSString * peer = nil;
		
        if (getpeername(nativeSocketHandle, (struct sockaddr *)&peerAddress, (socklen_t *)&peerLen) == 0) {
            peer = [NSString stringWithUTF8String:inet_ntoa(peerAddress.sin_addr)];
		} else {
			peer = @"Generic Peer";
		}
		
        CFReadStreamRef readStream = NULL;
		CFWriteStreamRef writeStream = NULL;
        CFStreamCreatePairWithSocket(kCFAllocatorDefault, nativeSocketHandle, &readStream, &writeStream);
		
        if (readStream && writeStream) {
            CFReadStreamSetProperty(readStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            CFWriteStreamSetProperty(writeStream, kCFStreamPropertyShouldCloseNativeSocket, kCFBooleanTrue);
            [server handleConnection:peer inputStream:(NSInputStream *)readStream outputStream:(NSOutputStream *)writeStream];
        } else {
            // on any failure, need to destroy the CFSocketNativeHandle 
            // since we are not going to use it any more
            close(nativeSocketHandle);
        }
        if (readStream) CFRelease(readStream);
        if (writeStream) CFRelease(writeStream);
    }
}

- (void) setupServer:(NSError **)error {
	uint16_t chosenPort = 0;
	struct sockaddr_in serverAddress;
	socklen_t nameLen = 0;
	nameLen = sizeof(serverAddress);
	
	if (self.netService && ipv4socket) {
		// Calling [self run] more than once should be a NOP.
		return;
	} else {
	
		if (!ipv4socket) {
			CFSocketContext socketCtxt = {0, self, NULL, NULL, NULL};
			self.ipv4socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&CryptoServerAcceptCallBack, &socketCtxt);
	
			if (!ipv4socket) {
				if (error) * error = [[NSError alloc] initWithDomain:CryptoServerErrorDomain code:kCryptoServerNoSocketsAvailable userInfo:nil];
				[self teardown];
				return;
			}
			
			int yes = 1;
			setsockopt(CFSocketGetNative(ipv4socket), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
			
			// set up the IPv4 endpoint; use port 0, so the kernel will choose an arbitrary port for us, which will be advertised using Bonjour
			memset(&serverAddress, 0, sizeof(serverAddress));
			serverAddress.sin_len = nameLen;
			serverAddress.sin_family = AF_INET;
			serverAddress.sin_port = 0;
			serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
			NSData * address4 = [NSData dataWithBytes:&serverAddress length:nameLen];
			
			if (kCFSocketSuccess != CFSocketSetAddress(ipv4socket, (CFDataRef)address4)) {
				if (error) *error = [[NSError alloc] initWithDomain:CryptoServerErrorDomain code:kCryptoServerCouldNotBindToIPv4Address userInfo:nil];
				if (ipv4socket) CFRelease(ipv4socket);
				ipv4socket = NULL;
				return;
			}
			
			// now that the binding was successful, we get the port number 
			// -- we will need it for the NSNetService
			NSData * addr = [(NSData *)CFSocketCopyAddress(ipv4socket) autorelease];
			memcpy(&serverAddress, [addr bytes], [addr length]);
			chosenPort = ntohs(serverAddress.sin_port);
			
			// set up the run loop sources for the sockets
			CFRunLoopRef cfrl = CFRunLoopGetCurrent();
			CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, ipv4socket, 0);
			CFRunLoopAddSource(cfrl, source, kCFRunLoopCommonModes);
			CFRelease(source);
		}
	
		if (!self.netService && ipv4socket) {
			self.netService = [[NSNetService alloc] initWithDomain:@"local" type:kBonjourServiceType name:[[UIDevice currentDevice] name] port:chosenPort];
			[self.netService setDelegate:self];
		}
	
		if (!self.netService && !ipv4socket) {
			if (error) *error = [[NSError alloc] initWithDomain:CryptoServerErrorDomain code:kCryptoServerCouldNotBindOrEstablishNetService userInfo:nil];
			[self teardown];
			return;
		}
	}
}

- (void)run {
	NSError * thisError = nil;
	[self setupServer:&thisError];
	
	LOGGING_FACILITY( thisError == nil, [thisError localizedDescription] );
	[thisError release];
	
	[self.netService scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
	[self.netService publish];
}

- (void)handleConnection:(NSString *)peerName inputStream:(NSInputStream *)readStream outputStream:(NSOutputStream *)writeStream {
	
	LOGGING_FACILITY( peerName != nil, @"No peer name given for client." );
	LOGGING_FACILITY( readStream != nil && writeStream != nil, @"One or both streams are invalid." );
	
	if (peerName != nil && readStream != nil && writeStream != nil) {
		CryptoServerRequest * newPeer = [[CryptoServerRequest alloc] initWithInputStream:readStream 
																			outputStream:writeStream 
																					peer:peerName 
																				delegate:self];
		
		if (newPeer) {
			[newPeer runProtocol];
			[self.connectionBag addObject:newPeer];
		}

		[newPeer release];
	}
}

- (void)cryptoServerRequestDidFinish:(CryptoServerRequest *)request {
	if (request) {
		[self.connectionBag removeObject:request];
	}
}

- (void)cryptoServerRequestDidReceiveError:(CryptoServerRequest *)request {
	if (request) {
		[self.connectionBag removeObject:request];
	}
}

- (void)teardown {
	if (self.netService) {
		[self.netService stop];
		[self.netService removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
		self.netService = nil;
	}
	if (self.ipv4socket) {
		CFSocketInvalidate(self.ipv4socket);
		CFRelease(self.ipv4socket);
		self.ipv4socket = NULL;
	}
}

- (void)dealloc {
	[self teardown];
	[connectionBag release];
	[super dealloc];
}

@end
