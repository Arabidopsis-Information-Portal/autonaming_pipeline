#!/usr/local/bin/perl
use strict;
use Cwd 'realpath';
use File::Basename;
use DBI;

my $program = realpath($0);
my $pgmdir = dirname($program);
our $myLib = dirname($program) . "/lib";
push @INC, $myLib;
require 'db.pm';
require 'generic.pm';
require 'cm_parse.pm';

$| = 1;
my ( $database, $outpath, $pipeid ) = @ARGV;
$outpath =~ s/\/output_repository.*$//;

# create empty database
my $workroot = dirname(realpath( $database ));
my $workspace = create_my_workspace( $workroot );
my $is_transcripts = 0;
system "sqlite3 $database < $pgmdir/config/naming.ddl";

# collect TIGR/PFAM details
my $dbh = connectSQLite($database) || die "Error connecting.\n";
print "collecting TIGR/PFAM details\n";
collect_TigrPfam_details($dbh);
$dbh->disconnect();

# load evidence
for my $dataname ( "TRNPRO", "QRYSEQ", "UNIREF", "CDD", "PRIAMRPS", "TAIR", "CUSTOMDB", "CAZY", "PFAM_TIGR", "PRIAMEC", "TMHMM" ) {
		
	if ( $dataname eq "TRNPRO" ) { ## Not sure what this is yet.
		my $datafile = "$outpath/longest_reading_frame.faa.list";
		if ( -e $datafile ) {
			print "$dataname: loading $datafile\n";
			my $tmptrnpro = "$workspace/tmptrnpro";
			unlink $tmptrnpro;
			do_linux( "cat $datafile | xargs grep \">\" | sed 's/^[^>]*>//' | sed 's/[\\t ].*read_id=\\([^ ]*\\).*/\\t\\1/' > $tmptrnpro" );
			do_sql( $database, "delete from transcript_protein;" );
			do_sql( $database, ".mode tabs\n.import '$tmptrnpro' transcript_protein" );
#			do_sql( $database, "vacuum analyze;" );
			unlink $tmptrnpro;
			$is_transcripts = 1;
		}
		else {
			print "$dataname: $datafile does not exist\n";
		}
	}
	elsif ( $dataname eq "QRYSEQ" ) { ## Not sure what this is yet.
		my $datafile = "$outpath/split_multifasta.fsa.list";
		if ( -e $datafile ) {
			print "$dataname: loading $datafile\n";
			my $tmpqryseq = "$workspace/tmpqryseq";
			unlink $tmpqryseq;
			do_linux( "cat $datafile | xargs grep \">\" | sed 's/^[^>]*>//' | sed 's/[\\t ].*//' >> $tmpqryseq" );
			do_sql( $database, "delete from query_sequence;" );
			do_sql( $database, ".mode tabs\n.import '$tmpqryseq' query_sequence" );
#			do_sql( $database, "vacuum analyze;" );
			unlink $tmpqryseq;
		}
		else {
			print "$dataname: $datafile does not exist\n";
		}
	}
	elsif ( $dataname =~ /^(UNIREF|CDD|CUSTOMDB|PRIAMRPS|TAIR)$/ ) {
		my $datafile;
		if ( $dataname eq "UNIREF" ) {
			if ( ! $is_transcripts ) {
				$datafile = "$outpath/uniref_results/ncbi-blastp.btab.list";
			}
			else {
				$datafile = "$outpath/uniref_results/ncbi-blastx.btab.list";
			}
		}
		elsif ( $dataname eq "CUSTOMDB" ) {
			if ( ! $is_transcripts ) {
				$datafile = "$outpath/_customdb/ncbi-blastp.btab.list";
			}
			else {
				$datafile = "$outpath/_customdb/ncbi-blastx.btab.list";
			}
		}
		elsif ( $dataname eq "TAIR" ) {
			if ( ! $is_transcripts ) {
				$datafile = "$outpath/tair_results/ncbi-blastp.btab.list";
			}
			else {
				$datafile = "$outpath/tair_results/ncbi-blastx.btab.list";
			}
		}
		elsif ( $dataname eq "CDD" ) {
			$datafile = "$outpath/cdd_results/rpsblast.btab.list";
		}
		elsif ( $dataname eq "PRIAMRPS" ) {
			$datafile = "$outpath/priamrps_results/rpsblast.btab.list";
		}
		else {
			die "\nUnprogrammed blast job: \"$dataname\"\n";
		}
		if ( -e $datafile ) {
			print "$dataname: loading $datafile\n";
			my $tmpbtab = "$workspace/tmpbtab";
			unlink $tmpbtab;
			if ( $dataname eq "CDD" ) {
				my $cmd2 = "cat $datafile | xargs cat | grep -v \"^ *\$\" | sed \"s/\\\"/|DOUBLEQUOTE|/g\" >> $tmpbtab";
#print "cmd=$cmd2\n";
				do_linux( $cmd2 );
			}
			else {
				do_linux( "cat $datafile | xargs cat | grep -v \"^ *\$\" >> $tmpbtab" );
			}
			do_sql( $database, "delete from btab_tmp;" );
			do_sql( $database, ".mode tabs\n.import '$tmpbtab' btab_tmp" );
			if ($dataname eq "UNIREF" ) {
				do_sql( $database, "update btab_tmp set job_name='$dataname';" );
			} else {
				do_sql( $database, "update btab_tmp set job_name='$dataname',subject_definition=subject_id||' '||subject_definition;" );
			}
			do_sql( $database, "update btab_tmp set query_left=query_right,query_right=query_left where frame<0;" );
			if ( $dataname =~ /^(CDD|PRIAMRPS)$/ ) {
				do_sql( $database, "update btab_tmp set program_name='rpsblast';" );
				if ( $dataname eq "CDD" ) {
					do_sql( $database, "update btab_tmp set subject_definition=replace(subject_definition,'|DOUBLEQUOTE|','\\\"');" );
				}
			}
			else {
				do_sql( $database, "update btab_tmp set program_name=lower(program_name);" );
			}
			do_sql( $database, "delete from btab where job_name='$dataname';" );
			do_sql( $database, "insert into btab select * from btab_tmp;" );
			do_sql( $database, "delete from btab_tmp;" );
#			do_sql( $database, "vacuum analyze;" );
			unlink $tmpbtab;
		}
		else {
			print "$dataname: $datafile does not exist\n";
		}
	}
	elsif ( $dataname =~ /^(CAZY|PFAM_TIGR)$/ ) {
		my $datafile;
		if ( $dataname eq "CAZY" ) {
			$datafile = "$outpath/hmm3cazy_results/hmmpfam.htab.list";
		}
		elsif ( $dataname eq "PFAM_TIGR" ) {
			$datafile = "$outpath/hmm3pfam_results/hmmpfam.htab.list";
		}
		if ( -e $datafile ) {
			print "$dataname: loading $datafile\n";
			my $tmphtab = "$workspace/tmphtab";
			unlink $tmphtab;
			do_linux( "cat $datafile | xargs cat >> $tmphtab" );
			do_sql( $database, "delete from htab_tmp;" );
			do_sql( $database, ".mode tabs\n.import '$tmphtab' htab_tmp" );
			do_sql( $database, "update htab_tmp set job_name='$dataname', query_id=trim(query_id);" );
			if ( $dataname =~ /^(PFAM_TIGR)$/ ) {
				my $dbh = connectSQLite( $database );
				$dbh->func( "clean_acc", 1, sub { my $acc = shift; $acc =~ s/\.[0-9 ]+$//; return $acc }, "create_function" );
				executeSQL( $dbh, "update htab_tmp set hmm_acc=clean_acc(hmm_acc);" );
				$dbh->commit;
				$dbh->disconnect;			
			}
			do_sql( $database, "delete from htab where job_name='$dataname';" );
			do_sql( $database, "insert into htab select * from htab_tmp;" );
			do_sql( $database, "delete from htab_tmp;" );
#			do_sql( $database, "vacuum analyze;" );
			unlink $tmphtab;
		}
		else {
			print "$dataname: $datafile does not exist\n";
		}
	}
	elsif ( $dataname eq "PRIAMEC" ) {
		my $datafile = "$outpath/priamec_results/priam_ec_assignment.bsml.list";
		if ( -e $datafile ) {
			print "$dataname: loading $datafile\n";
			my $tmpprm = "$workspace/tmpec";
			unlink $tmpprm;
			my $prot;
			my @eclist;
			open( BSML, "cat $datafile | xargs cat | grep -E '<Sequence |<Attribute name=\"EC\"' | grep -B1 'name=\"EC\" content=\"[^\"]' |" );
			open( TSV, ">$tmpprm" );
			my %protec;
			for my $line ( <BSML> ) {
				chomp $line;
				if ( $line =~ /<Sequence / ) {
					$line =~ s/^.* id="[_ ]*//;
					$line =~ s/".*//;
					$prot = $line;
				}
				elsif ( $line =~ /name="EC"/ ) {
					$line =~ s/^.* content="//;
					$line =~ s/".*//;
					@eclist = split /;/, $line;
					for my $ec ( @eclist ) {
						if ( ! exists $protec{$prot}{$ec} ) {
							print TSV "$prot\t$ec\n";
							$protec{$prot}{$ec} = 1;
						}
					}
				}
			}
			close BSML;
			close TSV;
			do_sql( $database, "delete from priam;" );
			do_sql( $database, ".mode tabs\n.import '$tmpprm' priam" );
#			do_sql( $database, "vacuum analyze;" );
			unlink $tmpprm;
		}
		else {
			print "$dataname: $datafile does not exist\n";
		}
	}
	elsif ( $dataname eq "TMHMM" ) {
		my $datafile = "$outpath/tmhmm_results/tmhmm.raw.list";
		if ( -e $datafile ) {
			print "$dataname: loading $datafile\n";
			my $tmptm = "$workspace/tmptm";
			unlink $tmptm;
			do_linux( "cat $datafile | xargs grep TMhelix | sed 's/^[^:]*://' | cut -f1 | uniq >> $tmptm" );
			do_sql( $database, "delete from tmhmm;" );
			do_sql( $database, ".mode tabs\n.import '$tmptm' tmhmm" );
#			do_sql( $database, "vacuum analyze;" );
			unlink $tmptm;
		}
		else {
			print "$dataname: $datafile does not exist\n";
		}
	}
	else {
		die "\nUnprogrammed job: \"$dataname\"\n";
	}
}
do_sql( $database, "delete from htab_tmp;" );
do_sql( $database, "delete from btab_tmp;" );
do_sql( $database, "vacuum analyze;" );

system "rm -rf $workspace";
#print "rm -rf $workspace\n";
exit(0);

sub do_linux {
	my ( $cmd ) = @_;
	if ( system $cmd ) {
		die "\nCommand failed: $cmd\n";
	}
}

sub do_sql {
	my ( $db, $cmd ) = @_;
	
	do_linux( "echo \"$cmd\" | sqlite3 $db" );
}

sub create_my_workspace {
	my ( $workroot ) = @_;
	
	if ( ! -e $workroot || ! -w $workroot ) {
		die "\ncannot write to direcroty $workroot\n";
	}
	my $workspace;
	
	$workspace = "$workroot/QL" . rand(1000000);
	while ( -e $workspace ) {
		$workspace = "$workroot/QL" . rand(1000000);
	}
	print "workspace=" . realpath($workspace) . "\n";
	mkdir $workspace || die "\ncannot create workspace at $workspace\n";
	return $workspace;
}
