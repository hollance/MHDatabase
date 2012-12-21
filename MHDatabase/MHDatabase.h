/*
 * Copyright (c) 2010-2012 Matthijs Hollemans
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

#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class MHDatabase;
@class MHStatement;

/*
 * Delegate for MHDatabase.
 */
@protocol MHDatabaseDelegate <NSObject>

@optional

/*
 * Invoked when the schema version of the installed database differs from the
 * expected version. This executes within a transaction. You don't have to 
 * update the schema version number; that is done automatically before the
 * transaction is committed.
 */
- (void)database:(MHDatabase *)database migrateSchemaFromVersion:(int)fromVersion toVersion:(int)toVersion;

@end

/*
 * A thin wrapper around SQLite 3.
 *
 * Your app needs to link with libsqlite3.dylib.
 */
@interface MHDatabase : NSObject 

/* The database connection. For advanced use only. */
@property (nonatomic, assign) sqlite3 *handle;

/*
 * Initializes the database.
 *
 * @param databasePath Where the database lives at runtime; typically this would
 *        be in your app's Documents directory (or a private subdir in Library).
 *        If there is no database present at that location, a database with the
 *        same name will be copied from your app bundle to the destination path.
 * @param schemaVersion The expected version of the database schema. This is a
 *        user-defined number that is stored with "PRAGMA user_version". If the
 *        installed database has a lower version number, the delegate will be 
 *        asked to migrate it dynamically.
 * @param delegate May be nil.
 */
- (id)initWithPath:(NSString *)databasePath schemaVersion:(int)schemaVersion delegate:(id <MHDatabaseDelegate>)delegate;

/*
 * Begins a database transaction block.
 */
- (void)beginTransaction;

/*
 * Commits a database transaction block.
 */
- (void)commitTransaction;

/*
 * Rolls back a database transaction block.
 */
- (void)rollbackTransaction;

/*
 * Creates a new prepared statement for the specified query.
 */
- (MHStatement *)prepareStatementWithName:(NSString *)name query:(const char *)query;

/*
 * Immediately executes an SQL query. Returns SQLITE_OK upon success.
 */
- (int)executeQuery:(const char *)query;

/*
 * Executes all the SQL statements from a file inside the app bundle. You can
 * use this to migrate your schema.
 */
- (void)executeFromFile:(NSString *)filename;

/*
 * Returns the primary key of the most recently inserted row.
 */
- (sqlite3_int64)lastInsertRowId;

/*
 * Returns the most recent SQLite error message.
 */
- (NSString *)errorMessage;

/*
 * Deletes all cached data.
 */
- (void)didReceiveMemoryWarning;

@end

/*
 * Represents a prepared statement.
 */
@interface MHStatement : NSObject

/* The statement handle. For advanced use only. */
@property (nonatomic, assign) sqlite3_stmt *handle;

/*
 * Binds a BOOL parameter to the statement. The column must have an int type!
 *
 * @param value the BOOL value
 * @param index The index of the parameter. Note: parameter indices start at 1.
 */
- (int)bindBool:(BOOL)value atIndex:(int)index;

/*
 * Binds an integer parameter to the statement.
 *
 * @param value the integer value
 * @param index The index of the parameter. Note: parameter indices start at 1.
 */
- (int)bindInt:(int)value atIndex:(int)index;

/*
 * Binds a double parameter to the statement.
 *
 * @param value the double value
 * @param index The index of the parameter. Note: parameter indices start at 1.
 */
- (int)bindDouble:(double)value atIndex:(int)index;

/*
 * Binds a string parameter to the statement.
 *
 * @param string the string value
 * @param index The index of the parameter. Note: parameter indices start at 1.
 */
- (int)bindString:(NSString *)string atIndex:(int)index;

/*
 * Binds a date parameter to the statement. The column must have a text type!
 *
 * @param date the date value
 * @param index The index of the parameter. Note: parameter indices start at 1.
 */
- (int)bindDate:(NSDate *)date atIndex:(int)index;

/*
 * Binds a null parameter to the statement.
 *
 * @param index The index of the parameter. Note: parameter indices start at 1.
 */
- (int)bindNullAtIndex:(int)index;

/*
 * Evaluates the statement.
 *
 * A SELECT query will return SQLITE_ROW until there are no more rows left.
 *
 * An INSERT, UPDATE or DELETE query will return SQLITE_DONE upon success.
 * Any other return codes indicate an error.
 */
- (int)step;

/*
 * Returns a BOOL value from a query. The column type should be integer.
 * If the column value is NULL, this method returns NO.
 *
 * @param index The index of the column. Column indices start at 0.
 */
- (BOOL)boolAtColumn:(int)index;

/*
 * Returns an int value from a query. If the column value is NULL, this
 * method returns 0.
 *
 * @param index The index of the column. Column indices start at 0.
 */
- (int)intAtColumn:(int)index;

/*
 * Returns a double value from a query. If the column value is NULL, this
 * method returns 0.
 *
 * @param index The index of the column. Column indices start at 0.
 */
- (double)doubleAtColumn:(int)index;

/*
 * Returns a string value from a query. If the column value is NULL, this
 * method returns nil.
 *
 * @param index The index of the column. Column indices start at 0.
 */
- (NSString *)stringAtColumn:(int)index;

/*
 * Returns a date value from a query. The column type should be text. 
 * If the column value is NULL, this method returns nil.
 *
 * @param index The index of the column. Column indices start at 0.
 */
- (NSDate *)dateAtColumn:(int)index;

/*
 * Makes the statement ready to be re-executed.
 */
- (int)reset;

@end
