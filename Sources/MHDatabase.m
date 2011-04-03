/*!
 * \file MHDatabase.m
 *
 * Copyright (c) 2010-2011 Matthijs Hollemans
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import "MHDatabase.h"

@interface MHDatabase ()
- (void)copyDatabaseIfNeeded:(NSString*)databasePath;
- (void)openDatabase:(NSString*)path;
- (void)closeDatabase;
- (void)checkSchemaVersion:(int)expectedVersion;
@end

@implementation MHDatabase

@synthesize handle;

- (id)initWithPath:(NSString*)databasePath schemaVersion:(int)schemaVersion delegate:(id<MHDatabaseDelegate>)delegate_
{
	if ((self = [super init]))
	{
		delegate = delegate_;
		[self copyDatabaseIfNeeded:databasePath];
		[self openDatabase:databasePath];
		[self checkSchemaVersion:schemaVersion];
		preparedStatements = [[NSMutableDictionary dictionaryWithCapacity:10] retain];
	}
	return self;
}

- (void)dealloc
{
	[self closeDatabase];
	[preparedStatements release];
	[super dealloc];
}

- (void)copyDatabaseIfNeeded:(NSString*)databasePath
{
	NSFileManager* fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:databasePath])
	{
		NSString* databaseFilename = [databasePath lastPathComponent];
		NSString* bundlePath = [[NSBundle mainBundle] pathForResource:databaseFilename ofType:nil];
		if (bundlePath != nil)
		{
			NSError* error;
			if (![fileManager copyItemAtPath:bundlePath toPath:databasePath error:&error])
				NSAssert1(NO, @"Failed to copy database file: %@", [error description]);
		}
	}
}

- (void)openDatabase:(NSString*)databasePath
{
	NSAssert(handle == NULL, @"Database already open");
	int result = sqlite3_open([databasePath UTF8String], &handle);
	if (result != SQLITE_OK)
	{
		sqlite3_close(handle);
		handle = NULL;
		NSAssert1(NO, @"Failed to open database, error: %d", result);
	}
}

- (void)closeDatabase
{
	if (handle != NULL)
	{
		sqlite3_close(handle);
		handle = NULL;
	}
}

- (void)setSchemaVersion:(int)version
{
	NSAssert(handle != NULL, @"Don't have a database connection");
	
	char query[128];
	sprintf(query, "PRAGMA user_version = %d", version);

	if (sqlite3_exec(handle, query, NULL, NULL, NULL) != SQLITE_OK)
		NSAssert1(NO, @"Error setting schema version: %s", sqlite3_errmsg(handle));
}

- (void)checkSchemaVersion:(int)expectedVersion
{
	NSAssert(handle != NULL, @"Don't have a database connection");

	const char* query = "PRAGMA user_version";
	sqlite3_stmt* statement;
	if (sqlite3_prepare_v2(handle, query, -1, &statement, NULL) == SQLITE_OK)
	{
		if (sqlite3_step(statement) != SQLITE_ROW)
			NSAssert(NO, @"Error retrieving schema version");

		int currentVersion = sqlite3_column_int(statement, 0);
		if (currentVersion != expectedVersion)
		{
			[self beginTransaction];

			if ([delegate respondsToSelector:@selector(database:migrateSchemaFromVersion:toVersion:)])
				[delegate database:self migrateSchemaFromVersion:currentVersion toVersion:expectedVersion];

			[self setSchemaVersion:expectedVersion];
			[self commitTransaction];
		}

		sqlite3_finalize(statement);
	}
}

- (void)beginTransaction
{
	NSAssert(handle != NULL, @"Don't have a database connection");
	char* errorMsg = NULL;
	if (sqlite3_exec(handle, "BEGIN", NULL, NULL, &errorMsg) != SQLITE_OK)
		NSAssert1(NO, @"Error starting transaction: %s", errorMsg);
}

- (void)commitTransaction
{
	NSAssert(handle != NULL, @"Don't have a database connection");
	char* errorMsg = NULL;
	if (sqlite3_exec(handle, "COMMIT", NULL, NULL, &errorMsg) != SQLITE_OK)
		NSAssert1(NO, @"Error committing transaction: %s", errorMsg);
}

- (void)rollbackTransaction
{
	NSAssert(handle != NULL, @"Don't have a database connection");
	char* errorMsg = NULL;
	if (sqlite3_exec(handle, "ROLLBACK", NULL, NULL, &errorMsg) != SQLITE_OK)
		NSAssert1(NO, @"Error rolling back transaction: %s", errorMsg);
}

- (MHStatement*)prepareStatementWithName:(NSString*)name query:(const char*)query
{
	NSAssert(handle != NULL, @"Don't have a database connection");

	MHStatement* statement = [preparedStatements objectForKey:name];
	if (statement != nil)
		return statement;

	sqlite3_stmt* statementHandle = NULL;
	if (sqlite3_prepare_v2(handle, query, -1, &statementHandle, NULL) != SQLITE_OK)
		NSAssert1(NO, @"Error preparing statement: %s", sqlite3_errmsg(handle));

	statement = [[MHStatement alloc] init];
	statement.handle = statementHandle;
	[preparedStatements setObject:statement forKey:name];
	[statement release];

	return statement;
}

- (int)executeQuery:(const char*)query
{
	return sqlite3_exec(handle, query, NULL, NULL, NULL);
}

- (void)executeFromFile:(NSString*)filename;
{
	NSString* path = [[NSBundle mainBundle] pathForResource:filename ofType:nil];
	NSAssert1(path != nil, @"Could not locate %@", filename);

	FILE* file = fopen([path UTF8String], "rt");
	NSAssert1(file != NULL, @"Could not open %@", filename);

	char line[1024];
	while (fgets(line, 1023, file))
	{
		if (strlen(line) > 4)
			sqlite3_exec(handle, line, NULL, NULL, NULL);
	}

	fclose(file);
}

- (sqlite3_int64)lastInsertRowId
{
	return sqlite3_last_insert_rowid(handle);
}

- (NSString*)errorMessage
{
	return [NSString stringWithUTF8String:sqlite3_errmsg(handle)];
}

- (void)didReceiveMemoryWarning
{
	[preparedStatements removeAllObjects];
}

@end

@implementation MHStatement

@synthesize handle;

- (void)dealloc
{
	sqlite3_finalize(handle);
	[super dealloc];
}

- (int)bindBool:(BOOL)value atIndex:(int)index
{
	return sqlite3_bind_int(handle, index, value);
}

- (int)bindInt:(int)value atIndex:(int)index
{
	return sqlite3_bind_int(handle, index, value);
}

- (int)bindDouble:(double)value atIndex:(int)index
{
	return sqlite3_bind_double(handle, index, value);
}

- (int)bindString:(NSString*)string atIndex:(int)index
{
	return sqlite3_bind_text(handle, index, [string UTF8String], -1, SQLITE_TRANSIENT);
}

- (int)bindDate:(NSDate*)date atIndex:(int)index
{
	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	NSString* dateString = [dateFormatter stringFromDate:date];
	int result = [self bindString:dateString atIndex:index];
	[dateFormatter release];
	return result;
}

- (int)bindNullAtIndex:(int)index
{
	return sqlite3_bind_null(handle, index);
}

- (int)step
{
	return sqlite3_step(handle);
}

- (BOOL)boolAtColumn:(int)index
{
	return sqlite3_column_int(handle, index) != 0;
}

- (int)intAtColumn:(int)index
{
	return sqlite3_column_int(handle, index);
}

- (double)doubleAtColumn:(int)index
{
	return sqlite3_column_double(handle, index);
}

- (NSString*)stringAtColumn:(int)index
{
	const char* result = (const char*)sqlite3_column_text(handle, index);
	if (result != NULL)
		return [NSString stringWithUTF8String:result];
	else
		return nil;
}

- (NSDate*)dateAtColumn:(int)index
{
	NSString* dateString = [self stringAtColumn:index];
	if (dateString == nil)
		return nil;

	NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
	[dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
	NSDate* date = [dateFormatter dateFromString:dateString];
	[dateFormatter release];
	return date;
}

- (int)reset
{
	return sqlite3_reset(handle);
}

@end
