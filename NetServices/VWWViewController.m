//
//  VWWViewController.m
//  NetServices
//
//  Created by Zakk Hoyt on 12/13/12.
//  Copyright (c) 2012 Zakk Hoyt. All rights reserved.
//

#import "VWWViewController.h"
#import "VWWNetServices.h"
@interface VWWViewController ()
@property (nonatomic, retain) VWWNetServices* netServices;
@end

@implementation VWWViewController

- (void)viewDidLoad
{
    self.netServices = [[VWWNetServices alloc]init];
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
