//
//  TweetFeedViewController.m
//  TwitterFeed
//
//  Created by Laura Savino on 7/3/11.
//


#import <UIKit/UIKit.h>
#import <dispatch/dispatch.h>

#import "UserProfileViewController.h"
#import "TweetFeedViewController.h"
#import "JSONKit.h"
#import "Tweet.h"
#import "URLWrapper.h"

@interface TweetFeedViewController () <UIAlertViewDelegate>

@property (nonatomic, retain) NSString *alertTextReload;
@property (nonatomic) BOOL didLoadInitialData;
@property (nonatomic, retain) NSMutableArray *tweetTexts;
@property (nonatomic, retain) UserProfileViewController *userProfileViewController;

- (void) loadUniversalTweetStream;
- (void)releaseProperties;

@end


@implementation TweetFeedViewController

@synthesize tweets = m_tweets;
@synthesize tweetTexts = m_tweetTexts;
@synthesize userProfileViewController = m_userProfileViewController;
@synthesize alertTextReload = m_alertTextReload;
@synthesize didLoadInitialData = m_didLoadInitialData;

- (id)init{
	// JSS:x initializers are allowed to return an object different from the
	// current value of "self" -- consequently, you should ALWAYS assign the
	// result to "self" (which is, after all, just a variable)
	self = [self initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (id) initWithStyle:(UITableViewStyle)style{
	if((self = [super initWithStyle:style])){
		self.alertTextReload = @"retry";
		self.didLoadInitialData = NO;
	}
	return self;
}

// JSS:x try to group protocol methods in a meaningful way, so that they're all
// easy to find


- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	// JSS:x try not to use magic numbers -- UIAlertView has properties for
	// identifying *what* a given button index is
	NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
	if([buttonTitle isEqualToString:self.alertTextReload]){
		[self loadUniversalTweetStream];
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return [self.tweetTexts count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView 
		  cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	// JSS:x usually, reuse identifiers are pulled out into a single variable
	// (rather than passed in as literal strings) so that they only have to be
	// changed or defined in one place
	static NSString *cellIdentifier = @"UITableViewCell";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	
	if(cell == nil){
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier] autorelease]; 
	}
	
	if([indexPath row] < [self.tweetTexts count]){
		Tweet *tweetText = [self.tweetTexts objectAtIndex:[indexPath row]];

		// JSS:x you can use dot-syntax for all these too, if you'd like
		cell.textLabel.text = tweetText.screenName;
		cell.imageView.image = tweetText.userPhoto;

		cell.detailTextLabel.lineBreakMode = UILineBreakModeTailTruncation;
		cell.detailTextLabel.numberOfLines = 3;
		cell.detailTextLabel.text = tweetText.tweetText;

	}

	return cell;

}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	return 100;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	// JSS:x you don't need to go to the app delegate for this -- this view
	// controller has a "navigationViewController" property
	if(self.userProfileViewController == nil){
		self.userProfileViewController = [[[UserProfileViewController alloc] init] autorelease];
	}
	
	// JSS:x too much nesting! break it down!
	NSInteger row = [indexPath row];
	Tweet *currentTweet = [self.tweetTexts objectAtIndex:row];
	self.userProfileViewController.userScreenName = [currentTweet screenName];

	[self.navigationController pushViewController:self.userProfileViewController animated:YES];

}

- (void)dealloc
{
	[self releaseProperties];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewWillAppear:(BOOL)animated{
	[super viewWillAppear:animated];
	
	// JSS:x it's bad form to start loading data from the network in
	// -viewDidLoad, as the view controller may not actually be getting
	// presented immediately -- use -viewWillAppear: for that instead
	if(!self.didLoadInitialData){
		[self loadUniversalTweetStream];
		self.didLoadInitialData = YES;
	}
}

- (void)viewDidLoad
{
	// JSS:x i'm unclear why you want to run code before the view loads when it
	// affects the view
    [super viewDidLoad];
	self.title = @"Recent tweets";
}


- (void) loadUniversalTweetStream{
	NSURL *feedURL = [NSURL URLWithString:@"https://api.twitter.com/statuses/public_timeline.json"];
//	NSURL *feedURL = [NSURL URLWithString:@"https://awefawoeighlariueghiaeruksiergh.com"];
	NSURLRequest *twitterRequest = [NSURLRequest requestWithURL:feedURL];
	
	//Callback when Twitter feed data is complete
	void (^tweetFeedBlock)(NSData*) = ^(NSData *data){
		dispatch_queue_t photoQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		
		self.tweets = [data objectFromJSONData];

		// JSS:x don't assign to ivars! use properties!
		self.tweetTexts = [[[NSMutableArray alloc] init] autorelease];
		
		// JSS:x it's somewhat unconventional to declare these outside of the
		// loop if you only use them INSIDE (and it also makes it harder to trace
		// through their memory management)

		//Fill tweetTexts from tweets:
		int tweetIndex = 0;
		for(NSDictionary *tweetCurrent in self.tweets){
			NSDictionary *user = [tweetCurrent objectForKey:@"user"];
			NSURL *photoURL = [NSURL URLWithString:[user objectForKey:@"profile_image_url"]];
			Tweet *tweetText = [[Tweet alloc] initWithName:[user objectForKey:@"screen_name"] tweetTextContent:[tweetCurrent objectForKey:@"text"] URL:photoURL];
			
			URLWrapper *tweetURLRequest = [[URLWrapper alloc] initWithURLRequest:[NSURLRequest requestWithURL:photoURL] connectionCompleted:^(NSData *data){
				// JSS:x can you figure out how to move your image creation to
				// a background thread and then finish back on the main thread?
				// loading or creating an image from data can be surprisingly
				// expensive

				dispatch_async(photoQueue,^{
					UIImage *userPhoto = [[UIImage alloc] initWithData:data];
					tweetText.userPhoto = userPhoto;
					dispatch_async( dispatch_get_main_queue(), ^{
						NSIndexPath *indexPath = [NSIndexPath indexPathForRow:tweetIndex inSection:0];
						NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
						[self.tableView reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
					});
					[userPhoto release];
				}); 
				
			}];
			
			[tweetURLRequest start];			
			[tweetURLRequest release];

			[self.tweetTexts addObject:tweetText];
			[tweetText release];
			tweetIndex++;
		}
		
		[self.tableView reloadData];

	};
	
	// JSS: what if one of your specific tweet requests fails?
	void (^failBlock)() = ^(){
		NSLog(@"Fail callback.");
		UIAlertView *tweetConnectionFail = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Connection error; please try again." delegate:self cancelButtonTitle:@"cancel" otherButtonTitles:self.alertTextReload, nil];
		[tweetConnectionFail show];
		[tweetConnectionFail release];
		
	};
	
	URLWrapper *tweetFeedRequest = [[URLWrapper alloc] initWithURLRequest:twitterRequest connectionCompleted:tweetFeedBlock connectionFailed:failBlock];
	[tweetFeedRequest start];
	[tweetFeedRequest release];
	

}

- (void)releaseProperties{
	// JSS:x prefer setting properties to nil to calling -release (since it stays
	// correct regardless of the property's memory management semantics)
	self.tweetTexts = nil;
	self.tweets = nil;
	self.userProfileViewController = nil;
}

- (void)viewDidUnload
{
	// JSS:x prefer setting properties to nil to calling -release (since it stays
	// correct regardless of the property's memory management semantics)
	[self releaseProperties];
	
	// JSS:x calls to super in destruction and disappearance methods should be at
	// the end (the opposite order of construction/appearance)
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
