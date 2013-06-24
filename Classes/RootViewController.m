/*
     File: RootViewController.m 
 Abstract: Controller for the main table view of the LazyTable sample.
    This table view controller works off the AppDelege's data model.
    produce a three-stage lazy load:
    1. No data (i.e. an empty table)
    2. Text-only data from the model's RSS feed
    3. Images loaded over the network asynchronously
 
    This process allows for asynchronous loading of the table to keep the UI responsive.
    Stage 3 is managed by the AppRecord corresponding to each row/cell.
 
    Images are scaled to the desired height.
    If rapid scrolling is in progress, downloads do not begin until scrolling has ended.
  
  Version: 1.4 
  
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple 
 Inc. ("Apple") in consideration of your agreement to the following 
 terms, and your use, installation, modification or redistribution of 
 this Apple software constitutes acceptance of these terms.  If you do 
 not agree with these terms, please do not use, install, modify or 
 redistribute this Apple software. 
  
 In consideration of your agreement to abide by the following terms, and 
 subject to these terms, Apple grants you a personal, non-exclusive 
 license, under Apple's copyrights in this original Apple software (the 
 "Apple Software"), to use, reproduce, modify and redistribute the Apple 
 Software, with or without modifications, in source and/or binary forms; 
 provided that if you redistribute the Apple Software in its entirety and 
 without modifications, you must retain this notice and the following 
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc. may 
 be used to endorse or promote products derived from the Apple Software 
 without specific prior written permission from Apple.  Except as 
 expressly stated in this notice, no other rights or licenses, express or 
 implied, are granted by Apple herein, including but not limited to any 
 patent rights that may be infringed by your derivative works or by other 
 works in which the Apple Software may be incorporated. 
  
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE 
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION 
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS 
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND 
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS. 
  
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL 
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, 
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED 
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), 
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE 
 POSSIBILITY OF SUCH DAMAGE. 
  
 Copyright (C) 2013 Apple Inc. All Rights Reserved. 
  
 */

#import "RootViewController.h"
#import "AppRecord.h"
#import "IconDownloader.h"

#define kCustomRowCount     7


@interface RootViewController () <UITableViewDelegate, UIScrollViewDelegate>
@property (nonatomic, strong) NSOperationQueue *downloadQueue;
@end


@implementation RootViewController

#pragma mark 

// -------------------------------------------------------------------------------
//	viewDidLoad
// -------------------------------------------------------------------------------
- (void)viewDidLoad
{
    [super viewDidLoad];

    self.downloadQueue = [[NSOperationQueue alloc] init];
    self.downloadQueue.maxConcurrentOperationCount = 5;
    self.downloadQueue.name = @"Icon Download Queue";
}

// -------------------------------------------------------------------------------
//	didReceiveMemoryWarning
// -------------------------------------------------------------------------------
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    for (AppRecord *appRecord in self.entries)
    {
        appRecord.appIcon = nil;
    }
}

#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0
// -------------------------------------------------------------------------------
//	shouldAutorotateToInterfaceOrientation:
//  Rotation support for iOS 5.x and earlier, note for iOS 6.0 and later all you
//  need is "UISupportedInterfaceOrientations" defined in your Info.plist.
// -------------------------------------------------------------------------------
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}
#endif

#pragma mark - UITableViewDataSource

// -------------------------------------------------------------------------------
//	tableView:numberOfRowsInSection:
//  Customize the number of rows in the table view.
// -------------------------------------------------------------------------------
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSUInteger count = [self.entries count];
	
    return count;
}

// -------------------------------------------------------------------------------
//	tableView:cellForRowAtIndexPath:
// -------------------------------------------------------------------------------
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	// customize the appearance of table view cells
	//
	static NSString *CellIdentifier = @"LazyTableCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    // Set up the cell...
    AppRecord *appRecord = [self.entries objectAtIndex:indexPath.row];

    cell.textLabel.text = appRecord.appName;
    cell.detailTextLabel.text = appRecord.artist;

    // Only load cached images; defer new downloads until scrolling ends
    if (appRecord.appIcon)
    {
        cell.imageView.image = appRecord.appIcon;
    }
    else
    {
        // if a download is deferred or in progress, return a placeholder image
        cell.imageView.image = [UIImage imageNamed:@"Placeholder.png"];

        // now start download
        [self startIconDownload:appRecord forIndexPath:indexPath];
    }

    return cell;
}

#pragma mark - Table cell image support

// -------------------------------------------------------------------------------
//	startIconDownload:forIndexPath:
// -------------------------------------------------------------------------------
- (void)startIconDownload:(AppRecord *)appRecord forIndexPath:(NSIndexPath *)indexPath
{
    if (appRecord.downloadOperation) return;

    IconDownloader *operation = [[IconDownloader alloc] init];
    operation.appRecord = appRecord;

    [operation setCompletionBlock:^{

        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];

            // Display the newly loaded image
            cell.imageView.image = appRecord.appIcon;
        }];
    }];

    appRecord.downloadOperation = operation;
    [self.downloadQueue addOperation:operation];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    AppRecord *appRecord = [self.entries objectAtIndex:indexPath.row];
    if (appRecord.downloadOperation)
        [appRecord.downloadOperation cancel];
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    // if iOS version less than 6.0, then we don't have `didEndDisplayingCell`, so we have to check if a cell scrolled away in scrollViewDidScroll
    
    if ([self iOSVersionMajor] < 6)
    {
        [self.entries enumerateObjectsUsingBlock:^(AppRecord *appRecord, NSUInteger idx, BOOL *stop) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]];

            // if the cell is not visible, but there's a download operation in progress

            if (cell == nil && appRecord.downloadOperation != nil)
            {
                // then cancel it

                [appRecord.downloadOperation cancel];
            }
        }];
    }
}

- (NSInteger) iOSVersionMajor
{
    static NSInteger iOSVersion = -1;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        iOSVersion = [[[UIDevice currentDevice] systemVersion] integerValue];
    });

    return iOSVersion;
}

@end
