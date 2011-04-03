
#include "MHDatabase.h"

@interface MyDelegate : NSObject <MHDatabaseDelegate>
@end

@implementation MyDelegate

- (void)database:(MHDatabase*)database migrateSchemaFromVersion:(int)fromVersion toVersion:(int)toVersion
{
	NSLog(@"migrateSchemaFromVersion %d toVersion %d", fromVersion, toVersion);

	/*
	   Below is an example of how you could write this method. Note the lack
	   of break statements; we always want to fall through to the next version!

	switch (fromVersion + 1)
	{
		case 2:
			[database executeQuery:"ALTER TABLE table ADD COLUMN col1 INTEGER;"];

		case 3:
			[database executeQuery:"ALTER TABLE table ADD COLUMN col2 TEXT;"];
	}
	*/
}

@end

int main(int argc, char* argv[])
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

	NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString* documentsDirectory = [paths objectAtIndex:0];
	NSString* path = [documentsDirectory stringByAppendingPathComponent:@"Database.sqlite"];

	MyDelegate* myDelegate = [[MyDelegate alloc] init];
	MHDatabase* database = [[MHDatabase alloc] initWithPath:path schemaVersion:1 delegate:myDelegate];

	MHStatement* statement;

	// Select all genres

	statement = [database prepareStatementWithName:@"SelectGenres"
		query:"SELECT * FROM genre ORDER BY genre_name"];

	while ([statement step] == SQLITE_ROW)
	{
		int genreId = [statement intAtColumn:0];
		NSString* genreName = [statement stringAtColumn:1];
		NSLog(@"Found genre with ID: %d, name: %@", genreId, genreName);
	}

	[statement reset];

	// Insert a pianist
	
	NSString* pianistName = @"Keith Jarett";
	int pianistGenreId = 3;

	statement = [database prepareStatementWithName:@"InsertPianist" 
		query:"INSERT INTO pianist (pianist_name, genre_id) VALUES (?, ?)"];

	[statement bindString:pianistName atIndex:1];
	[statement bindInt:pianistGenreId atIndex:2];

	if ([statement step] != SQLITE_DONE)
		NSLog(@"Error inserting row: %@", [database errorMessage]);

	int pianistId = [database lastInsertRowId];
	NSLog(@"Inserted pianist with primary key: %d", pianistId);

	[statement reset];

	// Whoops, we misspelled his name
	
	NSString* newName = @"Keith Jarrett";

	statement = [database prepareStatementWithName:@"UpdatePianistName" 
		query:"UPDATE pianist SET pianist_name = ? WHERE pianist_id = ?"];

	[statement bindString:newName atIndex:1];
	[statement bindInt:pianistId atIndex:2];

	if ([statement step] != SQLITE_DONE)
		NSLog(@"Error updating row: %@", [database errorMessage]);

	[statement reset];

	// Find all pianists and their genres who don't play jazz

	statement = [database prepareStatementWithName:@"SelectPianistsNoJazz"
		query:"SELECT pianist_name, genre_name FROM pianist JOIN genre USING (genre_id) WHERE genre_id <> 3 ORDER BY pianist_name"];

	while ([statement step] == SQLITE_ROW)
	{
		NSString* pianistName = [statement stringAtColumn:0];
		NSString* genreName = [statement stringAtColumn:1];
		NSLog(@"Pianist %@ plays %@", pianistName, genreName);
	}
	
	[statement reset];

	// Delete the pianist we inserted earlier

	if ([database executeQuery:"DELETE FROM pianist WHERE pianist_name LIKE '%Jarrett%'"] != SQLITE_OK)
		NSLog(@"Error deleting rows: %@", [database errorMessage]);

	[database release];
	[myDelegate release];
	
	[pool release];
	return 0;
}
