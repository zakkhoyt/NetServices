//
//  VWWServicesViewController.m
//  NetServices
//
//  Created by Zakk Hoyt on 12/13/12.
//  Copyright (c) 2012 Zakk Hoyt. All rights reserved.
//

#import "VWWServicesViewController.h"
#import "CryptoCommon.h"
#import "ServiceController.h"
#import "CryptoServer.h"
#import "KeyGeneration.h"
#import "SecKeyWrapper.h"
#import "CryptoClient.h"

@interface VWWServicesViewController ()<NSNetServiceBrowserDelegate, CryptoClientDelegate>
@property (nonatomic, retain) IBOutlet UITableView *tableView;
@property (nonatomic, retain) NSNetServiceBrowser * netServiceBrowser;
@property (nonatomic, retain) NSMutableArray * services;
@property (nonatomic, retain) KeyGeneration * keyGenerationController;
@property (nonatomic, retain) CryptoServer * cryptoServer;
@property (nonatomic, retain) CryptoClient * cryptoClient;
@end

@implementation VWWServicesViewController


-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
//    if ([segue.identifier isEqualToString:@"segueServicesToService"]){
//        ServiceController* serviceController = segue.destinationViewController;
//        serviceController.service = [self.services objectAtIndex:self.serviceIndex];
//    }
}
- (void)viewDidLoad {
    NSMutableArray *anArray = [[NSMutableArray alloc] init];
    self.services = anArray;
    [anArray release];
	
	// Check to see if keys have been generated.
    if (	![[SecKeyWrapper sharedWrapper] getPublicKeyRef]		||
        ![[SecKeyWrapper sharedWrapper] getPrivateKeyRef]		||
        ![[SecKeyWrapper sharedWrapper] getSymmetricKeyBytes]) {
		
        [[SecKeyWrapper sharedWrapper] generateKeyPair:kAsymmetricSecKeyPairModulusSize];
		[[SecKeyWrapper sharedWrapper] generateSymmetricKey];
    }
	
	CryptoServer * thisServer = [[CryptoServer alloc] init];
	self.cryptoServer = thisServer;
	[self.cryptoServer run];
	[thisServer release];
}

- (KeyGeneration *)keyGenerationController {
    if (self.keyGenerationController == nil) {
        self.keyGenerationController = [[[KeyGeneration alloc] initWithNibName:@"KeyGeneration" bundle:nil] autorelease];
    }
    return self.keyGenerationController;
}


- (IBAction)regenerateKeys {
//    KeyGeneration *controller = self.keyGenerationController;
//    controller.server = self.cryptoServer;
//    [self.navigationController presentModalViewController:controller animated:YES];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

// Creates an NSNetServiceBrowser that searches for services of a particular type in a particular domain.
// If a service is currently being resolved, stop resolving it and stop the service browser from
// discovering other services.
- (BOOL)searchForCryptoServices {
	[self.netServiceBrowser stop];
	[self.services removeAllObjects];
	[self.tableView reloadData];
    
	NSNetServiceBrowser * aNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
	aNetServiceBrowser.delegate = self;
	self.netServiceBrowser = aNetServiceBrowser;
	[aNetServiceBrowser release];
    
	[self.netServiceBrowser searchForServicesOfType:kBonjourServiceType inDomain:@"local"];
    
	return YES;
}

- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didRemoveService:(NSNetService*)service moreComing:(BOOL)moreComing {
	[self.services removeObject:service];
    if (!moreComing) [self.tableView reloadData];
}

- (void)netServiceBrowser:(NSNetServiceBrowser*)netServiceBrowser didFindService:(NSNetService*)service moreComing:(BOOL)moreComing {
	
#ifndef ALLOW_TO_CONNECT_TO_SELF
	// Don't display our published record
    if (![[self.cryptoServer.netService name] isEqualToString:[service name]]) {
        // If a service came online, add it to the list and update the table view if no more events are queued.
        [self.services addObject:service];
        
	}
#else
	[self.services addObject:service];
#endif
	
    if (!moreComing) {
        [self.tableView reloadData];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.services.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = (UITableViewCell *)[self.tableView dequeueReusableCellWithIdentifier:@"MyCell"];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MyCell"] autorelease];
    }
    cell.textLabel.text = [[self.services objectAtIndex:indexPath.row] name];
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self connectClient:[self.services objectAtIndex:indexPath.row]];
}

- (void)viewDidAppear:(BOOL)animated {
    [self searchForCryptoServices];
}

- (void)dealloc {
	[_netServiceBrowser release];
	[_services release];
	[_tableView release];
	[_keyGenerationController release];
	[_cryptoServer release];
	[super dealloc];
}



-(void)connectClient:(NSNetService*)service{
    CryptoClient * thisClient = [[CryptoClient alloc] initWithService:service delegate:self];
    self.cryptoClient = thisClient;
    [self.cryptoClient runConnection];
    [thisClient release];
}

#pragma mark - Impelments CryptoClientDelegate

- (void)cryptoClientDidCompleteConnection:(CryptoClient *)cryptoClient {
//    self.statusLog.text = [statusLog.text stringByAppendingString:@" Done\n"];
    NSLog(@"%s Done", __FUNCTION__);
}

- (void)cryptoClientWillBeginReceivingData:(CryptoClient *)cryptClient {
    //    self.statusLog.text = [statusLog.text stringByAppendingString:@"Receiving data..."];
    NSLog(@"%s Receiving data...", __FUNCTION__);
}

- (void)cryptoClientDidFinishReceivingData:(CryptoClient *)cryptClient {
    //    self.statusLog.text = [statusLog.text stringByAppendingString:@" Done\n"];
    NSLog(@"%s Done", __FUNCTION__);
}

- (void)cryptoClientWillBeginVerifyingData:(CryptoClient *)cryptClient {
    //    self.statusLog.text = [statusLog.text stringByAppendingString:@"Verifying blob..."];
    NSLog(@"%s Verifying data...", __FUNCTION__);
}

- (void)cryptoClientDidFinishVerifyingData:(CryptoClient *)cryptClient verified:(BOOL)verified {
//    self.statusLog.text = [statusLog.text stringByAppendingString:verified?@" Verified!" : @" Failed!"];
//    [spinner stopAnimating];
//    self.spinner.hidden = YES;
//	self.connectButton.enabled = YES;
    //	self.cryptoClient = nil;
    NSLog(@"%s %s", __FUNCTION__, verified? "Verified" : "Failed");
}
-(void)cryptoClientDidReceiveError:(CryptoClient *)cryptoClient{
    NSLog(@"%s", __FUNCTION__);
}

@end
