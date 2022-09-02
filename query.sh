#!/bin/bash

DBDIR=databases
SQLDIR=sql
RESDIR=results

sqlite3 $DBDIR/Db_SMS_Main.db < $SQLDIR/all_swipes.sql > $RESDIR/all_swipes.csv
sqlite3 $DBDIR/Db_SMS_Main.db < $SQLDIR/by_customer.sql > $RESDIR/by_customer.csv

