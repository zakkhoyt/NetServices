//
//  VWWNetServices.m
//  NetServices
//
//  Created by Zakk Hoyt on 12/13/12.
//  Copyright (c) 2012 Zakk Hoyt. All rights reserved.
//
// https://developer.apple.com/library/ios/#documentation/Cocoa/Conceptual/NetServices/Introduction.html#//apple_ref/doc/uid/10000119i
// https://developer.apple.com/library/ios/#documentation/Networking/Conceptual/NSNetServiceProgGuide/Introduction.html
//
#import "VWWNetServices.h"
#include <CFNetwork/CFSocketStream.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>
#import <arpa/inet.h>

#define kBonjourServiceType @"_crypttest._tcp"

typedef enum {
    kVWWServerCouldNotBindToIPv4Address = 1,
    kVWWServerCouldNotBindToIPv6Address = 2,
    kVWWServerNoSocketsAvailable = 3,
	kVWWServerCouldNotBindOrEstablishNetService = 4
} VWWServerErrorCode;

NSString * const VWWServerErrorDomain = @"VWWServerErrorDomain";


#pragma  mark Static C callback
static void VWWNetServicesAcceptCallBack(CFSocketRef socket, CFSocketCallBackType type, CFDataRef address, const void *data, void *info) {
    VWWNetServices* services = (VWWNetServices *)info;
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
            [services handleConnection:peer inputStream:(NSInputStream *)readStream outputStream:(NSOutputStream *)writeStream];
        } else {
            // on any failure, need to destroy the CFSocketNativeHandle
            // since we are not going to use it any more
            close(nativeSocketHandle);
        }
        if (readStream) CFRelease(readStream);
        if (writeStream) CFRelease(writeStream);
    }
}



@interface VWWNetServices () <NSNetServiceDelegate>
@property (nonatomic, retain) NSNetService* netService;
//@property (nonatomic, retain) NSNetServiceBrowser* netServiceBrowser;
@property (nonatomic, retain) NSMutableSet * connectionBag;
@property (nonatomic) CFSocketRef ipv4socket;
@end

@implementation VWWNetServices



#pragma mark NSObject methods

-(id)init{
    self = [super init];
    if(self){
        [self initializeClass];
    }
    return self;
}

-(void)initializeClass{
    NSError* error = nil;
    [self setupServer:&error];
}

-(void)dealloc{
    [_netService release];
//    [_netServiceBrowser release];
    [super dealloc];
}


-(void)setupServer:(NSError**)error{
    uint16_t chosenPort = 0;
	struct sockaddr_in serverAddress;
	socklen_t nameLen = 0;
	nameLen = sizeof(serverAddress);
	
	if (self.netService && self.ipv4socket) {
		// Calling [self run] more than once should be a NOP.
		return;
	} else {
        
		if (!self.ipv4socket) {
			CFSocketContext socketCtxt = {0, self, NULL, NULL, NULL};
			self.ipv4socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM, IPPROTO_TCP, kCFSocketAcceptCallBack, (CFSocketCallBack)&VWWNetServicesAcceptCallBack, &socketCtxt);
            
			if (!self.ipv4socket) {
				if (error) * error = [[NSError alloc] initWithDomain:VWWServerErrorDomain code:kVWWServerNoSocketsAvailable userInfo:nil];
				[self teardown];
				return;
			}
			
			int yes = 1;
			setsockopt(CFSocketGetNative(self.ipv4socket), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
			
			// set up the IPv4 endpoint; use port 0, so the kernel will choose an arbitrary port for us, which will be advertised using Bonjour
			memset(&serverAddress, 0, sizeof(serverAddress));
			serverAddress.sin_len = nameLen;
			serverAddress.sin_family = AF_INET;
			serverAddress.sin_port = 0;
			serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
			NSData * address4 = [NSData dataWithBytes:&serverAddress length:nameLen];
			
			if (kCFSocketSuccess != CFSocketSetAddress(self.ipv4socket, (CFDataRef)address4)) {
				if (error) *error = [[NSError alloc] initWithDomain:VWWServerErrorDomain code:kVWWServerCouldNotBindToIPv4Address userInfo:nil];
				if (self.ipv4socket) CFRelease(self.ipv4socket);
				self.ipv4socket = NULL;
				return;
			}
			
			// now that the binding was successful, we get the port number
			// -- we will need it for the NSNetService
			NSData * addr = [(NSData *)CFSocketCopyAddress(self.ipv4socket) autorelease];
			memcpy(&serverAddress, [addr bytes], [addr length]);
			chosenPort = ntohs(serverAddress.sin_port);
			
			// set up the run loop sources for the sockets
			CFRunLoopRef cfrl = CFRunLoopGetCurrent();
			CFRunLoopSourceRef source = CFSocketCreateRunLoopSource(kCFAllocatorDefault, self.ipv4socket, 0);
			CFRunLoopAddSource(cfrl, source, kCFRunLoopCommonModes);
			CFRelease(source);
		}
        
		if (!self.netService && self.ipv4socket) {
			self.netService = [[NSNetService alloc] initWithDomain:@"local" type:kBonjourServiceType name:[[UIDevice currentDevice] name] port:chosenPort];
			[self.netService setDelegate:self];
            NSLog(@"set net services delegate to self");
		}
        
		if (!self.netService && !self.ipv4socket) {
			if (error) *error = [[NSError alloc] initWithDomain:VWWServerErrorDomain code:kVWWServerCouldNotBindOrEstablishNetService userInfo:nil];
			[self teardown];
            NSLog(@"Error. Could not set up bounjour. Tearing down");
			return;
		}
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



- (void)handleConnection:(NSString *)peerName inputStream:(NSInputStream *)readStream outputStream:(NSOutputStream *)writeStream {
	
    if(peerName == nil){
        NSLog(@"No peer name given for client.");
    }
    if(readStream == nil && writeStream == nil){
        NSLog(@"One or both streams are invalid.");
    }
	
//	if (peerName != nil && readStream != nil && writeStream != nil) {
//		CryptoServerRequest * newPeer = [[CryptoServerRequest alloc] initWithInputStream:readStream
//																			outputStream:writeStream
//																					peer:peerName
//																				delegate:self];
//		
//		if (newPeer) {
//			[newPeer runProtocol];
//			[self.connectionBag addObject:newPeer];
//		}
//        
//		[newPeer release];
//	}
}








#pragma mark - Implements NSNetServiceDelegate

/* Sent to the NSNetService instance's delegate prior to advertising the service on the network. If for some reason the service cannot be published, the delegate will not receive this message, and an error will be delivered to the delegate via the delegate's -netService:didNotPublish: method.
 */
- (void)netServiceWillPublish:(NSNetService *)sender{
    NSLog(@"%s", __FUNCTION__);
}

/* Sent to the NSNetService instance's delegate when the publication of the instance is complete and successful.
 */
- (void)netServiceDidPublish:(NSNetService *)sender{
    NSLog(@"%s", __FUNCTION__);
}

/* Sent to the NSNetService instance's delegate when an error in publishing the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants). It is possible for an error to occur after a successful publication.
 */
- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict{
    NSLog(@"%s", __FUNCTION__);
    
}

/* Sent to the NSNetService instance's delegate prior to resolving a service on the network. If for some reason the resolution cannot occur, the delegate will not receive this message, and an error will be delivered to the delegate via the delegate's -netService:didNotResolve: method.
 */
- (void)netServiceWillResolve:(NSNetService *)sender{
    NSLog(@"%s", __FUNCTION__);
    
}

/* Sent to the NSNetService instance's delegate when one or more addresses have been resolved for an NSNetService instance. Some NSNetService methods will return different results before and after a successful resolution. An NSNetService instance may get resolved more than once; truly robust clients may wish to resolve again after an error, or to resolve more than once.
 */
- (void)netServiceDidResolveAddress:(NSNetService *)sender{
    NSLog(@"%s", __FUNCTION__);
    
}

/* Sent to the NSNetService instance's delegate when an error in resolving the instance occurs. The error dictionary will contain two key/value pairs representing the error domain and code (see the NSNetServicesError enumeration above for error code constants).
 */
- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict{
    NSLog(@"%s", __FUNCTION__);
    
}

/* Sent to the NSNetService instance's delegate when the instance's previously running publication or resolution request has stopped.
 */
- (void)netServiceDidStop:(NSNetService *)sender{
    NSLog(@"%s", __FUNCTION__);
    
}

/* Sent to the NSNetService instance's delegate when the instance is being monitored and the instance's TXT record has been updated. The new record is contained in the data parameter.
 */
- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data{
    NSLog(@"%s", __FUNCTION__);
    
}

@end
