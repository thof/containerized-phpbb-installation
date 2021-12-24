#!/bin/bash

echo "Setting required permissions..."
# phpBB files
chmod 666 web/config.php
chmod 777 web/store/
chmod 777 web/cache/
chmod 777 web/files/
chmod 777 web/images/
chmod 777 web/images/avatars/upload/
# SQLite DB dir
mkdir -p web/sqlitedb
chmod 777 web/sqlitedb/
