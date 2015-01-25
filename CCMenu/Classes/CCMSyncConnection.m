
#import "CCMSyncConnection.h"
#import "CCMServerStatusReader.h"

@implementation CCMSyncConnection

@synthesize runLoop;

- (id)initWithFeedURL:(NSURL *)theServerUrl
{
    self = [super initWithFeedURL:theServerUrl];
    runLoop = [NSRunLoop currentRunLoop];
    return self;
}

- (void)dealloc
{
    [receivedError release];
    [super dealloc];
}

- (void)setUpForNewRequest
{
    [super setUpForNewRequest];
    [receivedError release];
    receivedError = nil;
    didFinish = NO;
}

- (NSInteger)testConnection
{
    [self setUpForNewRequest];
    NSURLConnection *c = [[NSURLConnection connectionWithRequest:[self createRequest] delegate:self] retain];
    while(didFinish == NO)
        [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    [c release];
    if([self responseIsHudsonJenkinsAuthRequest] && (useHudsonJenkinsAuthWorkaround == NO))
    {
        [self cleanUpAfterRequest];
        useHudsonJenkinsAuthWorkaround = YES;
        return [self testConnection];
    }
    if(receivedError != nil)
    {
        // faking a 401 status code for authentications we cancelled
        if(([receivedError domain] == NSURLErrorDomain) && ([receivedError code] == NSURLErrorUserCancelledAuthentication))
            return 401;
        else
		    [NSException raise:@"ConnectionException" format:@"%@", [self errorStringForError:receivedError]];
    }
	return [receivedResponse statusCode];
}

- (NSArray *)retrieveServerStatus
{
    [self setUpForNewRequest];
    [NSURLConnection connectionWithRequest:[self createRequest] delegate:self];
    while(didFinish == NO)
        [runLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
    if([self responseIsHudsonJenkinsAuthRequest] && (useHudsonJenkinsAuthWorkaround == NO))
    {
        [self cleanUpAfterRequest];
        useHudsonJenkinsAuthWorkaround = YES;
        return [self retrieveServerStatus];
    }
    if(receivedError != nil)
        [NSException raise:@"ConnectionException" format:@"%@", [self errorStringForError:receivedError]];
    if([receivedResponse statusCode] != 200)
        [NSException raise:@"ConnectionException" format:@"%@", [self errorStringForResponse:receivedResponse]];
    CCMServerStatusReader *reader = [[[CCMServerStatusReader alloc] initWithServerResponse:receivedData] autorelease];
    NSError *parseError = nil;
    NSArray *infos = [reader readProjectInfos:&parseError];
    if(infos == nil)
        [NSException raise:@"ConnectionException" format:@"%@", [self errorStringForParseError:parseError]];
    return infos;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    didFinish = YES;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)anError
{
    receivedError = [anError retain];
    didFinish = YES;
}

@end
