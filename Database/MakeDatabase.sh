#!/bin/sh
# This script creates the database that goes into the application bundle.

OUTFILE=Database.sqlite
cat Schema1.sql | sqlite3 $OUTFILE
echo "PRAGMA user_version = 1;" | sqlite3 $OUTFILE
