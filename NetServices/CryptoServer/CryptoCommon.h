

#import <UIKit/UIKit.h>

#if DEBUG
	#define LOGGING_FACILITY(X, Y)	\
				NSAssert(X, Y);	

	#define LOGGING_FACILITY1(X, Y, Z)	\
				NSAssert1(X, Y, Z);	
#else
	#define LOGGING_FACILITY(X, Y)	\
				if (!(X)) {			\
					NSLog(Y);		\
					exit(-1);		\
				}					

	#define LOGGING_FACILITY1(X, Y, Z)	\
				if (!(X)) {				\
					NSLog(Y, Z);		\
					exit(-1);			\
				}						
#endif

#define kBonjourServiceType @"_crypttest._tcp"
#define kMessageBody	"Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do \
eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut \
enim ad minim veniam, quis nostrud exercitation ullamco laboris \
nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor \
in reprehenderit in voluptate velit esse cillum dolore eu fugiat \
nulla pariatur. Excepteur sint occaecat cupidatat non proident, \
sunt in culpa qui officia deserunt mollit."

#define kMesTag "cryptoM"
#define kSigTag "cryptoS"
#define kPubTag "cryptoP"
#define kSymTag "cryptoK"
#define kPadTag "crypto7"
#define kMaxMessageLength 1024*1024*5
// Valid sizes are currently 512, 1024, and 2048.
#define kAsymmetricSecKeyPairModulusSize 512

// Uncomment line below to allow connection to self.
//
// #define ALLOW_TO_CONNECT_TO_SELF 1
//