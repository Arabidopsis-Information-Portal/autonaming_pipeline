use DBI;

our $errorMessage;

my %dbSessions;
my %sequences;
my $sybaseServer = "SYBTIGR";
	
sub connectSQLite {
	my ( $dbfile, $autocommit ) = @_;
	if ( !defined $autocommit ) { $autocommit = 0 }
	$errorMessage = undef;
	
	my $dsn = "dbi:SQLite:$dbfile";
   	my %session;
   	$session{dsn} = $dsn;
   	$session{dbfile} = realpath($dbfile);
   	$session{username} = "";
   	$session{password} = "";
   	$session{schema} = "";
	$session{rdbms} = "sqlite";
	$session{autocommit} =	$autocommit;
	$dbSessions{attachments} = undef;
	
	my $dbh = DBI->connect( $dsn, "", "", {PrintError=>1,RaiseError=>1,AutoCommit=>$autocommit } );
	if ( !$dbh ) {
		$errorMessage = "connectSQLite connect to $dbfile failed: $DBI::errstr";
		return undef;
	}

	$dbSessions{$dbh} = \%session;
	
	return $dbh;
}

sub connectSybase {
    my ($schema,$username,$password) = @_;
	$errorMessage = undef;

	my $dsn = "dbi:Sybase:server=$sybaseServer";
	my %session;
   	$session{dsn} = $dsn;
	$session{schema} = $schema;
	$session{username} = $username;
   	$session{password} = $password;
	$session{rdbms} = "Sybase";

    $ENV{ SYBASE }  = '/usr/local/packages/sybase';
	my $dbh = DBI->connect($dsn,$username,$password);
	if ( ! $dbh ) {
		$errorMessage = "could not connect to Sybase: " . $DBI::errstr;
		return undef;
	}

	if ( ! $dbh->do("use $schema") ) {
		$errorMessage = "could not connect to schema $schema: " . $DBI::errstr;
		$dbh->disconnect();
		return undef;
	}

	$dbh->{LongReadLen} = 10000000;
	
	$dbSessions{$dbh} = \%session;
	return $dbh;
}

sub connectAutonomous {
	my ( $dbh ) = @_;
	
	my $autodbh;
	
	if ( ! exists $dbSessions{$dbh} ) {
		$errorMessage = "connectAutonomous: could not locaste current session.";
		return undef;
	} elsif ( $dbSessions{$dbh}{rdbms} eq "sqlite") {
		$autodbh = &connectSQLite($dbSessions{$dbh}{dbfile});
	} elsif ( $dbSessions{$dbh}{rdbms} eq "sybase" ) {
		$autodbh = &connectSybase($dbSessions{$dbh}{schema},$dbSessions{$dbh}{username},$dbSessions{$dbh}{password});
	}
	if ( !defined $autodbh ) {
		$errorMessage = "connectAutonomous: " . $errorMessage;
		return undef;
	}
	
	return $autodbh;
}

sub attachDB {
	my ( $dbh, $db, $alias ) = @_;
	$errorMessage = undef;

	if ( exists $dbSessions{$dbh} ) {
		if ( $dbSessions{$dbh}{rdbms} ne "sqlite" ) {
			$errorMessage = "attachDB is not available for " . $dbSessions{$dbh}{rdbms};
			return undef;
		}
		if ( defined &executeSQL($dbh,"attach database '$db' as $alias") ) {
			return $alias;
		} else {
			$errorMessage ="attachDB '$db' as $alias failed: $DBI::errstr";
			return undef;
		}
		my $session = $dbSessions{$dbh};
		my $attachments = $$session{attachments};
		push (@$attachments,\($db,$alias));
		$$session{attachments} = $attachments;
		$dbSessions{$dbh} = $session;
		return scalar @$attachments;
		 
	} else {
		$errorMessage = "attachDB could not determine rdbms";
		return undef;
	}	
}

sub vacuumDB {
	my ($dbfile) = @_;
	$errorMessage = undef;

	my $dsn = "dbi:SQLite:$dbfile";
	my $dbh = DBI->connect( $dsn, "", "", {PrintError=>0,RaiseError=>0,AutoCommit=>1} );
	if ( ! &executeSQL($dbh,"vacuum") ) {
		my $saveErrMsg  = $errorMessage;
		$errorMessage = "vacuumDB: " . $saveErrMsg;
		return undef;
	}

	return 1;
}

sub firstRowSQL {
	$errorMessage = undef;
	
	my $result = &querySQLArrayArray(@_);

	if ( !defined $result ) {
		$errorMessage = "firstRowSQL: " . $errorMessage;
		return undef;
	}
	
	my @row = ();
	my $tmp = $$result[0];
	if ( scalar @$tmp > 0 ) {
		@row = @$tmp;
	}

	return \@row;	
}

sub querySQL {
	my $result = &querySQLinternal(0,@_);
	if ( !defined $result ) {
		$errorMessage = "querySQLinternal: " . $errorMessage;
		return undef;
	}
	return $result;
}

sub querySQLArrayArray {
	my $result = &querySQLinternal(0,@_);
	if ( !defined $result ) {
		$errorMessage = "querySQLArrayArray: " . $errorMessage;
		return undef;
	}
	return $result;
}

sub querySQLArrayHash {
	my $result = &querySQLinternal(1,@_);
	if ( !defined $result ) {
		$errorMessage = "querySQLArrayHash: " . $errorMessage;
		return undef;
	}
	return $result;
}

sub querySQLHashHash {
	my $result = &querySQLinternal(2,@_);
	if ( !defined $result ) {
		$errorMessage = "querySQLHashHash: " . $errorMessage;
		return undef;
	}
	return $result;
}

sub querySQLHashArray {
	my $result = &querySQLinternal(3,@_);
	if ( !defined $result ) {
		$errorMessage = "querySQLHashArray: " . $errorMessage;
		return undef;
	}
	return $result;
}

sub querySQLinternal {
	my @args = @_;
	my $nargs = @args;

	my $fetchMode = $args[0];
	my $dbh = $args[1];
	my $sql = $args[2];

	my $ibind = 3;
	my $keycol;
	if ( $fetchMode == 2 || $fetchMode==3 ) {
		$keycol = $args[3];
		$ibind++;
	}
	
	my @binds = ();
	while ( $ibind<$nargs ) {
		if ( length($args[$ibind]) ) {
			push(@binds,$args[$ibind]);
		} else {
			push(@binds,undef);
		}
		$ibind++;
	}
	$errorMessage = undef;
    
 # prepare SQL
 	my $stmt = $dbh->prepare("$sql");
	if ( !defined $stmt) {
		$errorMessage = "querySQLinternal could not prepare SQL $sql: $DBI::errstr";
		return undef;
	}
	

# execute statement
	if ( !$stmt->execute(@binds) ) {
		$errorMessage = "querySQLinternal could not execute SQL $sql: $DBI::errstr";
		return undef;
	}
	
    
# fetch the rows back from the SELECT statement;

# fetch array of arrays
	if ( $fetchMode==0 ) {
		my @results = ();
		while ( my @row = $stmt->fetchrow ) {
			push(@results,\@row);
		}
		$stmt->finish;
		return \@results;

	} elsif ( $fetchMode==1 ) {
		my @results = ();
		while ( my $row = $stmt->fetchrow_hashref() ) {
			push(@results,$row);
		}
		$stmt->finish;
		return \@results;
		
	} elsif ( $fetchMode==2 ) {
		my %results;
		while ( my $row = $stmt->fetchrow_hashref() ) {
			my $hashkey = $$row{$keycol};
			$results{$hashkey} = $row;
		}
		$stmt->finish;
		if ( !defined \%results ) { return 0 }
		return \%results;
		
	} elsif ( $fetchMode==3 ) {
		my %results;
		while ( my @row = $stmt->fetchrow ) {
			my $hashkey = $row[$keycol];
			$results{$hashkey} = \@row;
		}
		$stmt->finish;
		return \%results;

	} else {
		$errorMessage = "querySQLinternal: unknown fetchMode: $fetchMode.";
		return undef;
	}
}

sub bulkInsertData {
	my ($dbh,$insertSQL,$rowdata) = @_;
	$errorMessage = undef;

# prepare insert statement
	my $stmt = $dbh->prepare($insertSQL);
	if ( !defined $stmt) {
		$errorMessage = "bulkInsertData could not prepare SQL $insertSQL: $DBI::errstr";
		return undef;
	}

# if no data return without doing anything	
	my @data = @$rowdata;
	my $nrows = scalar @data;
	if ( $nrows == 0 ) { return 0; }

	my @rowStatus = ();
    my $numInserted = $stmt->execute_array( { ArrayTupleStatus => \@rowStatus, ArrayTupleFetch => sub{ shift @data } } );
	if ( ! defined $numInserted ) {
		$errorMessage = "bulkInsertData insert ($insertSQL) failed: " . &bulkErrorMessage(\@rowStatus);
		return undef;
	} elsif ( ! $numInserted == $nrows ) {
		my $numFailed = $nrows - $numInserted;
		$errorMessage = "bulkInsertData $numFailed rows failed to insert: " . &bulkErrorMessage(\@rowStatus);
		return undef;
	} else {
		$errorMessage = undef;
	}

	return $numInserted;	
}

sub bulkErrorMessage {
	my ($rowStatus) = @_;
	$errorMessage = undef;

	my $bulkerr = "";
	my %errors;
	my $msg = "";
	foreach my $rstatus(@$rowStatus) {
		if ( defined $$rstatus[1] && length($$rstatus[1])>0 ) {
			$msg = $$rstatus[1];
			if ( $errors{$msg} ) {
				$errors{$msg} += 1;
			} else {
				$errors{$msg} = 1;
			}
		}
	}

	foreach $msg(keys(%errors)) {
		if ( $bulkerr ne "" ) {
			$bulkerr .= "\n";
		}
		if ( $errors{$msg}==1 ) {
			$bulkerr .= $msg . " (1 row)";
		} else {
			$bulkerr .= $msg . " ($errors{$msg} rows)";
		}
	}

	return $bulkerr;
}

sub executeSQL{
	my @args = @_;
	my $nargs = scalar(@args);
	my $dbh = $args[0];
	my $sql = $args[1];
	my @binds = ();
	my $i = 2;
	while ( $i<$nargs ) {
		if ( length($args[$i]) ) {
			push(@binds,$args[$i]);
		} else {
			push(@binds,undef);
		}
		$i++;
	}
	$errorMessage = undef;

 # prepare SQL
 	my $stmt = $dbh->prepare($sql);
 	if ( !$stmt ) {
 		$errorMessage = "executeSQL could not prepare SQL: " . $sql . ": " . $DBI::errstr;
 		return undef;
 	}

# execute statement
	my $result = $stmt->execute(@binds);

# check result
	if ( !$result ) {
		$errorMessage = "executeSQL could not execute SQL " . $sql . ": " . $DBI::errstr;
		return undef;
	}

	if ( $result == 0 ) {
		return 0;
	} else {    
		return $result;
	}
}

sub listDBs {
	$errorMessage = undef;
	my @dbList = keys(%dbSessions);
	return \@dbList;
}

sub commitDBs {
	my @dbArray = @_;
	$errorMessage = undef;

	my $numSucceeded = 0;
	foreach my $dbh ( @dbArray)  {
		if ( ! $dbh->commit() ) {
			$errorMessage .= "commit failed: $DBI::errstr";
		} else {
			$numSucceeded++;
		}
	}
	return $numSucceeded;
}

sub rollbackDBs {
	my @dbArray = @_;
	$errorMessage = undef;

	my $numSucceeded = 0;
	foreach my $dbh ( @dbArray)  {
		if ( ! $dbh->rollback() ) {
			$errorMessage .= "rollback failed: $DBI::errstr";
		} else {
			$numSucceeded++;
		}
	}

	if ( $errorMessage eq "") {
		return $numSucceeded;
	} else {
		return undef;
	}
}

sub disconnectDBs {
	my @dbArray = @_;
	$errorMessage = "";

	my $numSucceeded = 0;
	foreach my $dbh ( @dbArray)  {
		if ( ! $dbh->disconnect() ) {
			$errorMessage .= "disconnect failed: $DBI::errstr";
		} else {
			$numSucceeded++;
		}
	}

	if ( $errorMessage eq "" ) {
		$errorMessage = undef;
		return $numSucceeded;
	} else {
		return undef;
	}
}

sub copyTableData {
# copy table contents between databases
# current implementation is quick and dirty
	my ( $tableName, $fconn, $tconn ) = @_;
	$errorMessage = undef;
# determine to/from rdbms
# if they differ we need to worry about date formats
	my ($frdbms, $trdbms);
	if ( !exists $dbSessions{$fconn} ) {
		$errorMessage = "could not location session for \"from\" database.";
	} else {
		$frdbms = $dbSessions{$fconn}{rdbms};
	}
	if ( !exists $dbSessions{$tconn} ) {
		$errorMessage = "could not location session for \"to\" database.";
	} else {
		$trdbms = $dbSessions{$tconn}{rdbms};
	}

# find columns common between the two tables
	my $fcols = &describeTable($fconn,$tableName);
	my $tcols = &describeTable($tconn,$tableName);

	my %fcheck;
	foreach my $col(@$fcols) {
		$fcheck{$$col[1]}{datatype} = $$col[2];
	}

	my %tcheck;
	foreach my $col(@$tcols) {
		$tcheck{$$col[1]}{datatype} = $$col[2];
	}

	my %common;
	foreach my $col( keys %fcheck ) {
		if ( exists $tcheck{$col} ) {
			$common{$col}{datatype} = $tcheck{$col}{datatype};
		}
	}
	
# format select and insert statements
	my $selectCols = "";
	my $insertCols = "";
	my $ncols = 0;
	my $ndates = 0;
	my @datecols = ();
	foreach my $col( keys %common ) {
		my $datatype = $common{$col}{datatype};
		if ( length($selectCols)>0 ) {
			$selectCols .= ",";
			$insertCols .= ",";
		}
		$selectCols .= &formatColumnName($col,$frdbms);
		$insertCols .= &formatColumnName($col,$trdbms);

# flag date columns (sybase and sqlite have incompatible date formats)
		if ( $frdbms ne $trdbms ) {
			if ( $datatype =~ /date/ || $datatype =~ /time/ ) {
				$datecols[$ndates++] = $ncols;
			}
		}
		$ncols++;
	}
	my $selectSQL = "select " . $selectCols . " from " . $tableName;
	my $insertSQL = "insert into " . $tableName . "(" . $insertCols . ")"
		. "values ( " . join( ",", split( //, &rpad( "?", $ncols, "?" ) ) ) . ")";
	my $results = &querySQL($fconn,$selectSQL); 
	if ( ! defined $results ) {
		$errorMessage = "&copyTableData failed at querySQL: " . $errorMessage;
		return undef;
	}

	my $nrows = scalar @$results;
	if ( $nrows==0 ) {
		return 0;
	} else {
		my $row = $$results[0];
		my @data = ();
		for my $i(0..$nrows-1) {
			$row = $$results[$i];
			if ( $ndates>0 ) {
				foreach my $col(@datecols) {
					my $tmpdate = $$row[$col]; 
					$$row[$col] = &convertDate($tmpdate,$frdbms,$trdbms);
				}
			}
			push @data,$row;
		}
		
		my $numInserted = &bulkInsertData($tconn,$insertSQL,\@data);
		if ( ! defined $numInserted ) {
			$errorMessage = "&copyTableData failed at bulkInsertData: " . $errorMessage;
			return undef;
		}

		return $numInserted;
	}
}

sub formatColumnName {
	my ($colname, $rdbms) = @_;
	$errorMessage = undef;
	
		if ( ! ( $colname =~ /#/ ) || $rdbms eq "sybase" ) {
		return $colname;
	} else {
		return "\"" . $colname . "\"";
	}	
}

sub convertDate {
# Sybase format: Dec 20 2008  3:27AM
# SQLite format: 2008-12-20 03:27:08
# will implement error handling later
	my ($value,$fromRDBMS,$toRDBMS) = @_;
	$errorMessage = undef;

	if ( !defined $value || length($value)==0 ) {
		$errorMessage = "convertDate: emopty or undefined value.";
		return undef;
	} elsif ( lc($fromRDBMS) eq lc($toRDBMS) ) {
		return $value;
	}

	my ( $yyyy, $mm, $dd, $hr24, $mi, $ss ) = &parseDate($value,$fromRDBMS);
	if ( !defined $yyyy ) {
		$errorMessage = "convertDate: " . $errorMessage;
		return undef;
	}

	my $date;
	if ( lc($toRDBMS) eq "sqlite" ) {
		$date = "$yyyy-$mm-$dd $hr24:$mi:$ss";
	} else {
		my $mon = substr("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ",4*($mm-1),3);
		my $hr = $hr24;
		my $min = $mi;
		if ( $hr>12 ) {
			$hr -= 12;
			$min .= "PM";
		} else {
			$min .="AM";
		}
		$date = "$mon $dd $yyyy  $hr:$min";
	}
	return $date;
}

sub parseDate {
	my($value,$rdbms) =  @_;
	$errorMessage = undef;

	my ( $yyyy, $mm, $dd, $hr24, $mi, $ss );

	if ( lc($rdbms) eq "sqlite" ) {
		my @datetime = split(" ",$value);
		my @date = split("-",$datetime[0]);
		my @time = split(":",$datetime[1]);
		$yyyy = $date[0];
		$mm = $date[1];
		$dd = $date[2];
		$hr24 = $time[0];
		$mi = $time[1];
		$ss = $time[2];
	} elsif ( lc($rdbms) eq "sybase" ) {
		my @datetime = split(" ",$value);
		$yyyy = $datetime[2];
		if ( $yyyy<1000 ) { $yyyy += 2000 }	
		$mm = index("jan feb mar apr may jun jul aug sep oct nov dec ",lc($datetime[0]));
		$mm = 1 + int($mm/4);
		$dd = $datetime[1];
		my @time = split(":",$datetime[3]);
		$hr24 = $time[0]; 
		if ( uc($time[1]) =~ /\d+PM/) {
			$hr24 += 12;
			$mi = uc($time[1]);
			$mi =~ s/PM//;
		} else {
			$mi = uc($time[1]);
			$mi =~ s/AM//;
		}
		$ss = "00";
	} else {
		$errorMessage = "parseDate: invald RDBMS: $rdbms";
		return ();	
	}
	return ($yyyy,$mm,$dd,$hr24,$mi,$ss);
}

sub describeTable {
	my ( $dbh, $tableName, $rdbms ) = @_;
	$errorMessage = undef;
		
	if ( !exists $dbSessions{$dbh}{rdbms} ) {
		if ( !defined $rdbms ) {
			$errorMessage = "describeTable: no session associated with DB handle and no RDBMS specified.";
			return undef;m
		} else {
			$rdbms =~ lc;
			if ( $rdbms ne "sqlite" && $rdbms ne "sybase" ) {
				$errorMessage = "describeTable: unrecognized RDBMS \"$rdbms\".";
				return undef;
			}
		}
	} else {
			$rdbms = $dbSessions{$dbh}{rdbms};
	}
	
	my @tableColumns = ();
	my @column = ();
	my $result;
	if ( $rdbms eq "sqlite") {
		$result = &querySQL($dbh,"pragma table_info($tableName)");
	} else {
		$result = &querySQL($dbh,"sp_columns $tableName");
	}
	if ( ! defined $result ) {
		$errorMessage = "describeTable ($rdbms) failed: $DBI::errstr";
		return undef;
	}
	my $colnum = 0;
	for my $row(@$result) {
		my @column = ();
		if ( $rdbms eq "sqlite") {
			$column[0] = $$row[0];	#column number
			$column[1] = $$row[1];	#column name
			$column[2] = lc($$row[2]);	#column datatype
			if ( $$row[3]==99 || $$row[5]==1 ) {
				$column[3] = 1;	#column required
			} else {
				$column[3] = 0;	#column optional
			}
		} else {
			$column[0] = $colnum++;	#column number
			$column[1] = $$row[3];	#column name
			$column[2] = lc($$row[5]);	#column datatype
			if ( $$row[19] ne "YES"  ) {
				$column[3] = 1;	#column required
			} else {
				$column[3] = 0;	#column optional
			}
		}
		push (@tableColumns,\@column);
	}
	return \@tableColumns;
}

sub printDescribeTable {
	my ( $dbh, $tableName, $rdbms) = @_;
	$errorMessage = undef;

	my $result = &describeTable($dbh,$tableName,$rdbms);
	if ( ! defined $result ) {
		$errorMessage = "printDescribeTable " . $errorMessage;
		return undef;
	}

	print &lpad("#",5," ") . "  " . &rpad("name",40," ") . &rpad("type",20," ") . &lpad("reqd",5," ") . "\n";
	foreach my $row(@$result) {
		print &lpad($$row[0],5," ") . "  " . &rpad($$row[1],40," ") . &rpad($$row[2],20," ") . &lpad($$row[3],5," ") . "\n";
	}

	return scalar @$result;
}

sub getSession {
	my ( $dbh ) = @_;
	if ( !exists $dbSessions{$dbh} ) {
		$errorMessage = "getSession: unknown db handle.";
		return undef;
	}
	
	return $dbSessions{$dbh};
}
sub getSessionDBFile {
	my ($dbh) = @_;
	$errorMessage = undef;
	
	if ( defined $dbSessions{$dbh}{dbfile} ) {
		return $dbSessions{$dbh}{dbfile};
	} elsif ( !exists $dbSessions{$dbh} ) {
		$errorMessage = "getSessionDBFile: Could not find session.";
		return undef;
	} else {
		$errorMessage = "getSessionDBFile: no dbfile.";
		return undef;
	}
}		

sub getSessionDSN {
	my ($dbh) = @_;
	$errorMessage = undef;
	
	if ( defined $dbSessions{$dbh}{dsn} ) {
		return $dbSessions{$dbh}{dbfile};
	} elsif ( !exists $dbSessions{dsn} ) {
		$errorMessage = "getSessionDSN: Could not find session.";
		return undef;
	} else {
		$errorMessage = "getSessionDSN: no DSN.";
		return undef;
	}
}		
	
sub openSequence{
	my ( $dbh, $seqname, $blksize, $startval ) = @_;
#
# initialize a sequence
# $dbh - database to which sequence should be added
# $seqname -  name of sequence
# $blksize - number of values to reserve, sequence needs to be re-initialized when values exhausted, defaults to 1000
# $startval - optional, force sequence to start at this value
	if ( !defined $dbh ) {
		$errorMessage = "openSequence: unknown database handle.";
		return undef;
	}
	if ( !defined $blksize ) {
		$blksize = 1;
	}

	my $curval;
	my $topval;

# if no db handle create a cache-only sequence
	if ( !defined $dbh ) {
		if ( defined $startval ) {
			$curval = $startval-1;
		} else {
			$curval = 0;
		}
		$blksize = 1000000000000;
		$topval = $curval + $blksize;

# db available
# use update to lock the sequence table and reserve a block of values
	} else {
		my $reserve =
			&executeSQL($dbh,
				"update sequence set last_value = coalesce(?-1,last_value)+? where sequence_name = ?",
				$startval, $blksize, $seqname );
		if ( !defined $reserve ) {
			$errorMessage = "openSequence: reserve: " . $errorMessage;
			return undef;
		}

# fetch current sequence from db
		my $fetch =
			&firstRowSQL($dbh,
				"select last_value from sequence where sequence_name = ?",
				$seqname);
		if ( !defined $fetch ) {
			$errorMessage = "openSequence: fetch: " . $errorMessage;
			return undef;
		} elsif ( scalar @$fetch > 0 ) {
			$topval = @$fetch[0];
			$curval = $topval - $blksize;

# sequence not in db, create a new sequence in db
		} else {
			if ( !defined $startval ) {
				$topval = $blksize;
				$curval = 0;
			} else {
				$curval = $startval - 1;
				$topval = $curval + $blksize;
			}
			my $add = &executeSQL($dbh,"insert into sequence(sequence_name,last_value) values(?,?)",$seqname,$topval); 		
			if ( !defined $add ) {
				$errorMessage = "openSequence: add: " . $errorMessage;
				return undef;
			}
		}
	}
	
# add sequence to cache
	$sequences{$seqname}{curval} = $curval;
	$sequences{$seqname}{topval} = $topval;
	$sequences{$seqname}{blksize} = $blksize;
	$sequences{$seqname}{dbh} = $dbh;
	
# return the sequence offset, THIS VALUE IS NOT IN YOUR RESERVED LIST OF VALUES
	return $curval;
}

sub nextSequenceValue {
	my ( $seqname, $inc) = @_;

# return next value from sequence
	if ( !defined $inc ) { $inc = 1 }
	if ( !exists $sequences{$seqname} ) {
		$errorMessage = "nextSequenceValue: sequence \"$seqname\" not initialized.";
		return undef;
	}
	$sequences{$seqname}{curval} += $inc;

# reserved values have been used up, reserve more
	if ( $sequences{$seqname}{curval} > $sequences{$seqname}{topval} ) {
		if ( $inc > $sequences{$seqname}{blksize} ) {
			$errorMessage= "nextSequenceValue: increment \"$inc\" > block size \"" . $sequences{$seqname}{blksize} . "\"";
			return undef;
		} elsif ( !defined &openSequence($sequences{$seqname}{dbh},$seqname,$sequences{$seqname}{blksize}) ) {
			$errorMessage = "nextSequenceValue: " . $errorMessage;
			return undef;
		}
		$sequences{$seqname}{curval} += $inc;
	}

# return next value
	return $sequences{$seqname}{curval};	
}	

sub currentSequenceValue {
	my ( $seqname ) = @_;

# return last used value from sequence
# return error (undef) if no reserved values have been used
# nextSequenceValue MUST have been called at least once before currentSequenceValue can be called
	
	if ( !exists $sequences{$seqname} ) {
		$errorMessage = "currentSequenceValue: sequence \"$seqname\" not initialized.";
		return undef;
	} elsif ( $sequences{$seqname}{curval} > ( $sequences{$seqname}{topval} - $sequences{$seqname}{blksize} ) ) {
		return $sequences{$seqname}{curval};	
	} else {
		$errorMessage = "CurrentSequenceValue: cannot be called before nextSequenceValue.";
		return undef;
	}
}	

sub closeSequence {
	my ( $seqname ) = @_;

# close sequence and return unused values

# get sequence data
	if ( ! exists $sequences{$seqname} ) {
		$errorMessage = "closeSequence: could not find sequence \"$seqname\".";
		return undef;
	}
	
	my $topval = $sequences{$seqname}{topval};
	my $curval = $sequences{$seqname}{curval};
	my $dbh = $sequences{$seqname}{dbh};

# restore unused values (unless someone else has already extended the sequence)
	if ( defined $dbh && $curval < $topval ) {
		my $release =
		&executeSQL($dbh,
			"update sequence set last_value=? where last_value=? and sequence_name=?",
			$curval,$topval,$seqname);
	}

# remove sequence from cache
	delete($sequences{$seqname});

}

sub describeSequences {
	my ( $dbh ) = @_;
	
	my $sequences = &querySQLArrayHash( $dbh, "select * from sequence order by sequence_name");
	if ( !defined $sequences ) {
		$errorMessage = "describeSequences: " . $errorMessage;
		return undef;
	}
	
	return $sequences;
}
1;

