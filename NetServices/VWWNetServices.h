//
//  VWWNetServices.h
//  NetServices
//
//  Created by Zakk Hoyt on 12/13/12.
//  Copyright (c) 2012 Zakk Hoyt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VWWNetServices : NSObject
- (void)handleConnection:(NSString *)peerName inputStream:(NSInputStream *)readStream outputStream:(NSOutputStream *)writeStream;
@end
