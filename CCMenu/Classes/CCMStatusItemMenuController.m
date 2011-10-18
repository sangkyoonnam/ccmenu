
#import <EDCommon/EDCommon.h>
#import "NSCalendarDate+CCMAdditions.h"
#import "CCMStatusItemMenuController.h"
#import "CCMImageFactory.h"
#import "CCMServerMonitor.h"
#import "CCMProject.h"

@interface NSStatusItem(MyTitleFormatting)

- (void)setFormattedTitle:(NSString *)aTitle;

@end

@implementation NSStatusItem(MyTitleFormatting)

- (void)setFormattedTitle:(NSString *)aTitle
{
    NSMutableDictionary *attr = [NSMutableDictionary dictionary];
    [attr setObject:[NSFont fontWithName:@"Lucida Grande" size:12] forKey:NSFontAttributeName];
    NSAttributedString *strg = [[[NSAttributedString alloc] initWithString:aTitle attributes:attr] autorelease];
    [self setAttributedTitle:strg];
}

@end


@implementation CCMStatusItemMenuController

- (void)awakeFromNib
{
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];	
	[statusItem setImage:[imageFactory imageForUnavailableServer]];
	[statusItem setHighlightMode:YES];
	[statusItem setMenu:statusMenu];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self selector:@selector(displayProjects:) name:CCMProjectStatusUpdateNotification object:nil];
}

- (NSStatusItem *)statusItem
{
    return statusItem;
}


- (void)setupItemsForProjects:(NSArray *)projectList inMenu:(NSMenu *)menu
{	
	int index = 0;
    for(CCMProject *project in [projectList sortedArrayByComparingAttribute:@"name"])
    {
        NSMenuItem *menuItem = [[menu itemArray] objectAtIndex:index];
        while(([menuItem isSeparatorItem] == NO) && ([[project name] compare:[menuItem title]] == NSOrderedDescending))
        {
            [menu removeItemAtIndex:index];
            menuItem = [[menu itemArray] objectAtIndex:index];
        }
        if([menuItem representedObject] != project)
        {
            menuItem = [menu insertItemWithTitle:[project name] action:@selector(openProject:) keyEquivalent:@"" atIndex:index];
            [menuItem setTarget:self];
            [menuItem setRepresentedObject:project];
        }
		NSImage *image = [imageFactory imageForActivity:[[project status] activity] lastBuildStatus:[[project status] lastBuildStatus]];
		[menuItem setImage:[imageFactory convertForMenuUse:image]];
        index += 1;
    }
    while([[[menu itemArray] objectAtIndex:index] isSeparatorItem] == NO)
    {
        [menu removeItemAtIndex:index];
    }
}


- (void)displayProjects:(id)sender
{
    NSArray *projectList = [serverMonitor projects];
	
	[self setupItemsForProjects:projectList inMenu:[statusItem menu]];
    
	unsigned failCount = 0;
	unsigned buildCount = 0;
	bool isFixing = NO;
	bool haveAtLeastOneStatus = NO;
    CCMProject *displayProject = nil;
    for(CCMProject *project in projectList)
	{
        if([project isBuilding])
        {
            buildCount += 1;
            NSCalendarDate *estimatedComplete = [project estimatedBuildCompleteTime];
            if(estimatedComplete != nil)
            {
                if(displayProject == nil)
                {
                    displayProject = project;
                }
                else if([project isFailed])
                {
                    if(![displayProject isFailed] || [estimatedComplete precedesDate:[displayProject estimatedBuildCompleteTime]])
                        displayProject = project;
                }
                else
                {
                    if(![displayProject isFailed] && [estimatedComplete precedesDate:[displayProject estimatedBuildCompleteTime]])
                        displayProject = project;
                }
            }
        }
		if([project isFailed])
			failCount += 1;
		if([project isBuilding])
			buildCount += 1;
		if([project isBuilding] && [project isFailed])
			isFixing = YES;
		if([project status] != nil)
			haveAtLeastOneStatus = YES;
	}
	if(haveAtLeastOneStatus == NO)
	{
		[statusItem setImage:[imageFactory imageForActivity:nil lastBuildStatus:nil]];
		[statusItem setTitle:@""];
	}
	else if(buildCount > 0)
	{
		NSString *status = isFixing ? CCMFailedStatus : CCMSuccessStatus;
		[statusItem setImage:[imageFactory imageForActivity:CCMBuildingActivity lastBuildStatus:status]];
		if(displayProject == nil)
        {
            [statusItem setTitle:@""];
        }
        else
        {
            [statusItem setFormattedTitle:[[NSCalendarDate date] descriptionOfIntervalSinceDate:[displayProject estimatedBuildCompleteTime] withSign:YES]];
        }
        [timer invalidate];
        [timer release];
        timer = [[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(displayProjects:) userInfo:nil repeats:NO] retain];
    }
	else if(failCount > 0)
	{
		[statusItem setImage:[imageFactory imageForActivity:CCMSleepingActivity lastBuildStatus:CCMFailedStatus]];
		[statusItem setFormattedTitle:[NSString stringWithFormat:@"%u", failCount]];
	}
	else
	{
		[statusItem setImage:[imageFactory imageForActivity:CCMSleepingActivity lastBuildStatus:CCMSuccessStatus]];
		[statusItem setTitle:@""];
    }
}


- (IBAction)openProject:(id)sender
{
    CCMProject *project = [sender representedObject];
	if([[project status] webUrl] != nil)
    {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[[project status] webUrl]]];
    }
    else
	{
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		if([project statusError] != nil) 
		{
			[alert setMessageText:NSLocalizedString(@"An error occured when retrieving the project status", "Alert message when an error occured talking to the server.")];
			[alert setInformativeText:[project statusError]];
		}
		else
		{
			[alert setMessageText:NSLocalizedString(@"Cannot open web page", "Alert message when server does not provide webUrl")];
			[alert setInformativeText:NSLocalizedString(@"This continuous integration server does not provide web URLs for projects. Please contact the server administrator.", "Informative text when server does not provide webUrl")];
		}
		[alert runModal];
	}
}

@end