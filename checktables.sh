#!/bin/sh
#
#	checktables.sh - Checks all tables in all databases for errors
#
#	@author: Johan Hedberg <mail@johan.pp.se>
#
# Copyright 2011 Johan Hedberg. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright notice, this list
#       of conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY COPYRIGHT HOLDER ''AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are those of the
# authors and should not be interpreted as representing official policies, either expressed
# or implied, of copyright holder.
#

# Config
DBHOST="localhost"
DBUSER="debian-sys-maint"
DBPASS="xxxx"
ADMIN_EMAIL="root@localhost"

# Programs
MYSQL="/usr/bin/mysql"

# Fetch db list
DATABASES=$(echo "SHOW DATABASES;" | $MYSQL -h $DBHOST -u $DBUSER -p$DBPASS | egrep -v '^(Database|information_schema$)')

for db in $DATABASES; do
	# Fetch tables in db
	tables=$(echo "SHOW TABLES FROM \`$db\`;" | $MYSQL -h $DBHOST -u $DBUSER -p$DBPASS | egrep -v '^Tables_in')
	for tbl in $tables; do
		# Is CHECK TABLE possible on this table?
		tbl_info=$(echo "SHOW CREATE TABLE \`$db\`.\`$tbl\`;" | $MYSQL -h $DBHOST -u $DBUSER -p$DBPASS)
		echo $tbl_info | grep -q ENGINE=MyISAM
		if [ $? -eq 0 ]; then
			# Check the table for errors
			check_result=$(echo "CHECK TABLE \`$db\`.\`$tbl\` EXTENDED;" | $MYSQL -h $DBHOST -u $DBUSER -p$DBPASS)
			echo "$check_result" | tail -n1 | awk '{print $NF;}' | grep -q '^OK$'
			if [ $? -ne 0 ]; then
				# If there are any errors, send an email to the admin
				echo "$db.$tbl BROKEN!" | mail -E -s "MySQL corrupt table!" $ADMIN_EMAIL
			else
				# Optimize the table and fuck the output
				echo "OPTIMIZE TABLE \`$db\`.\`$tbl\`;" | $MYSQL -h $DBHOST -u $DBUSER -p$DBPASS 2>&1 > /dev/null
			fi
		fi
		
	done
done

