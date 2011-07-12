//
//  TweetFeedViewController.m
//  TwitterFeed
//
//  Created by Laura Savino on 7/3/11.
//

#import "TwitterFeedAppDelegate.h" //Debug: is this a bad idea? How do we know we're not creating a retain cycle by referencing the parent?
#import "TweetFeedViewController.h"
#import "JSONKit.h"


@implementation TweetFeedViewController

@synthesize tweets;

- (id)init{
	// JSS: initializers are allowed to return an object different from the
	// current value of "self" -- consequently, you should ALWAYS assign the
	// result to "self" (which is, after all, just a variable)
	[super initWithStyle:UITableViewStyleGrouped];
	return self;
}

- (id) initWithStyle:(UITableViewStyle)style{
	return [self init];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
}

// JSS: try to group protocol methods in a meaningful way, so that they're all
// easy to find
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
	return [tweetTexts count];
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	// JSS: try not to use magic numbers -- UIAlertView has properties for
	// identifying *what* a given button index is
	if(buttonIndex == 1){
		[self loadUniversalTweetStream];
	}
}

- (UITableViewCell *) tableView:(UITableView *)tableView 
		  cellForRowAtIndexPath:(NSIndexPath *)indexPath{
	// JSS: usually, reuse identifiers are pulled out into a single variable
	// (rather than passed in as literal strings) so that they only have to be
	// changed or defined in one place
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
	
	if(cell == nil){
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"UITableViewCell"] autorelease]; 
	}
	
	if([indexPath row] < [tweetTexts count]){
		Tweet *tweetText = [tweetTexts objectAtIndex:[indexPath row]];

		// JSS: you can use dot-syntax for all these too, if you'd like
		[[cell textLabel] setText:tweetText.screenName];
		[[cell imageView] setImage:tweetText.userPhoto];

		[cell.detailTextLabel setLineBreakMode:UILineBreakModeTailTruncation];
		[cell.detailTextLabel setNumberOfLines:3];
		[[cell detailTextLabel] setText:tweetText.tweetText];

	}

	return cell;

}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
	return 100;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	// JSS: you don't need to go to the app delegate for this -- this view
	// controller has a "navigationViewController" property
	TwitterFeedAppDelegate *appDelegate = (TwitterFeedAppDelegate*)[[UIApplication sharedApplication] delegate];
	UINavigationController *navigationController = appDelegate.navigationController;
	if(userProfileViewController == nil){
		userProfileViewController = [[UserProfileViewController alloc] init];
	}
	
	// JSS: too much nesting! break it down!
	[userProfileViewController setUserScreenName:[[tweetTexts objectAtIndex:[indexPath row]] screenName]];

	[navigationController pushViewController:userProfileViewController animated:YES];
	[userProfileViewController release];
	userProfileViewController = nil;

}

- (void)dealloc
{
	// JSS: prefer setting properties to nil to calling -release (since it stays
	// correct regardless of the property's memory management semantics)
	[tweetTexts release];
	[tweets release];
	[userProfileViewController release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
	//Debug: I'd actually like this to run before the view loads, and for the table view to load after this method returns. Is there a method to that effect?
	//
	// JSS: i'm unclear why you want to run code before the view loads when it
	// affects the view
    [super viewDidLoad];
	[self setTitle:@"Recent tweets"];

	// JSS: it's bad form to start loading data from the network in
	// -viewDidLoad, as the view controller may not actually be getting
	// presented immediately -- use -viewWillAppear: for that instead
	[self loadUniversalTweetStream];
}


- (void) loadUniversalTweetStream{
	NSURL *feedURL = [NSURL URLWithString:@"https://api.twitter.com/statuses/public_timeline.json"];
	//NSURL *feedURL = [NSURL URLWithString:@"https://awefawoeighlariueghiaeruksiergh.com"];
	NSURLRequest *twitterRequest = [NSURLRequest requestWithURL:feedURL];
	
	//Callback when Twitter feed data is complete
	void (^tweetFeedBlock)(NSData*) = ^(NSData *data){
		[self setTweets:[data objectFromJSONData]];

		// JSS: don't assign to ivars! use properties!
		tweetTexts = [[NSMutableArray alloc] init];
		
		// JSS: it's somewhat unconventional to declare these outside of the
		// loop if you only use them INSIDE (and it also makes it harder to trace
		// through their memory management)
		NSDictionary *tweetCurrent;
		NSDictionary *user;
		Tweet *tweetText;
		NSURL *photoURL;
		URLWrapper *tweetURLRequest;
		//Fill tweetTexts from tweets:
		for(int i = 0; i < [tweets count]; i++){
			tweetCurrent = [tweets objectAtIndex:i];
			user = [tweetCurrent objectForKey:@"user"];
			photoURL = [NSURL URLWithString:[user objectForKey:@"profile_image_url"]];
			tweetText = [[Tweet alloc] initWithName:[user objectForKey:@"screen_name"] tweetTextContent:[tweetCurrent objectForKey:@"text"] URL:photoURL];
			
			tweetURLRequest = [[URLWrapper alloc] initWithURLRequest:[NSURLRequest requestWithURL:photoURL] connectionCompleted:^(NSData *data){
				// JSS: can you figure out how to move your image creation to
				// a background thread and then finish back on the main thread?
				// loading or creating an image from data can be surprisingly
				// expensive
				UIImage *userPhoto = [[UIImage alloc] initWithData:data];
				[tweetText setUserPhoto:userPhoto];
				[userPhoto release];
				[[self tableView] reloadData];
			}];
			
			[tweetURLRequest start];
			
			[tweetTexts addObject:tweetText];
			[tweetText release];
			
			[tweetURLRequest release]; 
			
		}
	};
	
	// JSS: what if one of your specific tweet requests fails?
	void (^failBlock)() = ^(){
		NSLog(@"Fail callback.");
		UIAlertView *tweetConnectionFail = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Connection error; please try again." delegate:self cancelButtonTitle:@"cancel" otherButtonTitles:@"retry", nil];
		[tweetConnectionFail show];
		[tweetConnectionFail release];
		
	};
	
	URLWrapper *tweetFeedRequest = [[URLWrapper alloc] initWithURLRequest:twitterRequest connectionCompleted:tweetFeedBlock connectionFailed:failBlock];
	[tweetFeedRequest start];
	[tweetFeedRequest release];
	

}

- (void)viewDidUnload
{
	// JSS: calls to super in destruction and disappearance methods should be at
	// the end (the opposite order of construction/appearance)
    [super viewDidUnload];

    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;

	// JSS: prefer setting properties to nil to calling -release (since it stays
	// correct regardless of the property's memory management semantics)
	[userProfileViewController release];
	userProfileViewController = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
