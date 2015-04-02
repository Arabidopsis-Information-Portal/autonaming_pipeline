#!/usr/local/bin/perl
#use warnings;
use strict;
require "/usr/local/devel/ANNOTATION/APIS/pipeline/lib/com2GOutl.pm";

our $strict = 0;
our ( $dbg, $DBG );
our %goNames;
our ( %ecDefs, %ecProfs );
$dbg = 0;
#open( $DBG, ">debug.output" );

our $errorMessage;    # db.pm 'throws' this around, often with something informative inside.
our $TF;
our %namingRules;
our %evidenceTypes;
our %isotype_rank = (
		'equivalog'             => 0,
		'equivalog_domain'      => 1,
		'PFAM_equivalog'        => 2,
		'PFAM_equivalog_domain' => 3,
		'subfamily'             => 4,
		'domain'                => 5,
		'repeat'                => 6,
		'subfamily_domain'      => 7,
		'superfamily'           => 8
	);
our $no_isotype = 9;
our $verbose;
our ( $excludecompute, $target_taxon_id, $exclude_taxon_id, $excludebranch_taxon_id, $taxonomy_lookup );

sub extract_evidence {

	my ( $dbh, $query_list, $job_name, $table_name ) = @_;

	my @evidence;

	# load blast evidence
	if ( $table_name eq 'btab' ) {
		my $query_sql = "select * from $table_name"
			. " where job_name='$job_name' and query_id in ($query_list)"
			. " order by subject_id";
		my $query_data = querySQLArrayHash( $dbh, $query_sql );
		if ( defined $query_data ) {
			my $tmpid = "";
			my %subjhits;
			
			# collect HSPs
			for my $row ( @$query_data ) {
				$$row{hit_id} = "$job_name|$$row{subject_id}";
				$$row{query_coverage} = $$row{query_right} - $$row{query_left} + 1;
				$$row{subject_coverage} = $$row{subject_right} - $$row{subject_left} + 1;
				$$row{query_gaps} = $$row{alignment_length} - $$row{query_coverage}; 
				if ( $$row{query_gaps} < 0 ) { $$row{query_gaps} = 0 }
				$$row{subject_gaps} = $$row{alignment_length} - $$row{subject_coverage}; 
				if ( $$row{subject_gaps} < 0 ) { $$row{subject_gaps} = 0 }
				$$row{num_identical} = int( $$row{pct_identity} / 100.0 * $$row{alignment_length} + 0.5 );
				$$row{num_similar} = int( $$row{pct_similarity} / 100.0 * $$row{alignment_length} + 0.5 );
	
				$$row{num_hsps} = 1;
				$$row{ref_id} = $$row{subject_id};
				$$row{ref_description} = $$row{subject_definition};

				if ( ! defined $subjhits{ $$row{subject_id} } ) {
					my @tmp = ( $row );
					$subjhits{ $$row{subject_id} } = \@tmp;
				}
				else {
					push @{ $subjhits{ $$row{subject_id} }  }, $row;
				}
				#push @evidence, formatBlastHit( $row );
			}
			
			# merge HSPs into hits
			for my $hsps ( values %subjhits ) {
				#if ( @$hsps > 1 ) {
					my $hit = sumHSPs( @$hsps );
					my $blasthit = formatBlastHit( $hit );
					if ( defined $$blasthit{deflines} && @{ $$blasthit{deflines} } ) {
						push @evidence, $blasthit;
					}
				#}
			}
		}
	}

	# load hmm evidenmce
	elsif ( $table_name eq 'htab' ) {
		my $query_sql = "select *, (select iso_type from hmm3 where hmm3.hmm_acc=htab.hmm_acc) as iso_type"
			. " from htab where job_name='$job_name' and query_id in ($query_list)"
			. " order by hmm_acc";
#print "SQL: $query_sql\n";
		my $query_data = querySQLArrayHash( $dbh, $query_sql );
		if ( defined $query_data ) {
			
			# collect domain hits
			my %combinedHmms;
			for my $row ( @$query_data ) {
				$combinedHmms{$$row{hmm_acc}}{$$row{domain_number}} = $row;
				$$row{hit_id} = "$job_name|$$row{hmm_acc}";
				$$row{num_hsps} = 1;
				$$row{evalue} = $$row{total_evalue};
				$$row{pct_scoverage} = &calculate_coverage( $$row{hmm_begin}, $$row{hmm_end}, $$row{hmm_length} );
				if ( " $$row{query_definition} " =~ / length=([0-9]+) / ) {
					$$row{query_length} = $1;	
					$$row{pct_qcoverage} = &calculate_coverage( $$row{query_begin}, $$row{query_end}, $$row{query_length} );
					$$row{pct_coverage} = $$row{pct_qcoverage};
					if ( $$row{pct_scoverage} > $$row{pct_coverage} ) { $$row{pct_coverage} =  $$row{pct_scoverage} }	
				}
				else {
					$$row{pct_coverage} = $$row{pct_scoverage};
				}
			}
			
			# merge domain hits into total hit
			for my $hmm_acc ( keys %combinedHmms ) {
				my $hmm = sumDomains( values %{ $combinedHmms{$hmm_acc} } );
				push @evidence, formatHmmHit( $hmm );
#print_hash( "HMM", $evidence[@evidence-1] );
			}
		}
	}
	
	# load tmhmm evidence
	elsif ( $table_name eq "tmhmm" ) {
		my $query_sql = "select 'TMHMM' as job_name, query_id from tmhmm where query_id in ($query_list)";
#print "SQL: $query_sql\n";
		my $query_data = querySQLArrayHash( $dbh, $query_sql );
		if ( defined $query_data ) {
			for my $row ( @$query_data ) {
				$$row{hit_id} = $job_name;
				$$row{ref_id} = "TMHMM";
				$$row{pros} = 9;
				$$row{cons} = 1;
				$$row{confidence} = calculate_confidence( $row );
				
				my %defline;
				$defline{id} = "TMHMM";
				$defline{definition} = "transmembrane protein, putative";
				$defline{original} = $defline{definition};
				my @deflines = ( \%defline );
				$$row{deflines} = \@deflines;

				push @evidence, $row;
			}
		}
	}

	# unexpected table
	else {
		die "\nRequest for data from unknown table: \"$table_name\".\n";
	}		

	return \@evidence;
}

sub calculate_confidence {
	my ( $hit ) = @_;
	
	my $confidence = $$hit{pros} / ( $$hit{pros} + $$hit{cons} );

	if ( $confidence !~ /\./ ) { $confidence .= "." }
	$confidence = rpad( $confidence, 5, "0" );

	return $confidence;
}

sub formatHmmHit {
	my ( $row ) = @_;
	
	my $wpct = 0.0;
	if ( $$row{total_score} >= $$row{trusted_cutoff} ) {
		$wpct = 0.900;
	}
	elsif ( $$row{total_score} >= $$row{noise_cutoff} ) {
		$wpct = 0.510;
	}
	else {
		if ( $$row{total_evalue} <= 1E-50 ) {
			$wpct = 0.450;
		}
		elsif ( $$row{total_evalue} <= 1E-20 ) {
			$wpct = 0.420;
		}
		elsif ( $$row{total_evalue} <= 1E-10 ) {
			$wpct = 0.400;
		}
		elsif ( $$row{total_evalue} <= 1E-5 ) {
			$wpct = 0.350;
		}
		else {
			$wpct = 0.300;
		}
	}

	my $games = int ( 0.75 * $$row{pct_scoverage} / 100.0 * $$row{hmm_length} + 0.5 );
	my $pros = int ( $wpct * $games + 0.5 );
	my $cons = $games - $pros;
	$$row{pros} = $pros;
	$$row{cons} = $cons;
	$$row{confidence} = calculate_confidence( $row );
	
	my %defline;
	$defline{id} = $$row{hmm_acc};
	if ( $$row{job_name} eq "CAZY" ) {
		$defline{definition} = cazy_name_parser( $$row{hmm_acc} );
	}
	else {
		$defline{definition} = tigrfam_name_parser( $$row{hmm_acc}, $$row{hmm_definition}, $$row{iso_type} );
	}
	$defline{original} = $defline{definition};
	
	my @deflines = ( \%defline );
	$$row{deflines} = \@deflines;

	return $row;
}


sub formatBlastHit {
	my ( $hit ) = @_;
	
	# compute coverages
	$$hit{pct_qcoverage} = int( 1000.0 * $$hit{query_coverage} / $$hit{query_length} + 0.5 ) / 10.0;
	$$hit{pct_scoverage} = int( 1000.0 * $$hit{subject_coverage} / $$hit{subject_length} + 0.5 ) / 10.0;
	$$hit{pct_coverage} = $$hit{pct_qcoverage};
	if ( $$hit{pct_scoverage} > $$hit{pct_coverage} ) { $$hit{pct_coverage} =  $$hit{pct_scoverage} }	

	# recompute identity/similarity using standard algorithm
	$$hit{pct_identity} = int( 1000.0 * $$hit{num_identical} / $$hit{alignment_length} + 0.5 ) / 10.0;
	$$hit{pct_similarity} = int( 1000.0 * $$hit{num_similar} / $$hit{alignment_length} + 0.5 ) / 10.0;			

	# score hit
	my $seq_length = minval( $$hit{query_length}, $$hit{subject_length} );
	my $maxpros = 0.90 * $seq_length;
	my $num_covered = minval( $$hit{subject_coverage}, $$hit{query_coverage} );
	my $pros = ( $num_covered + $$hit{num_similar} + $$hit{num_identical} ) / 3.0;
	if ( $pros > $maxpros ) { $pros = $maxpros }
	my $cons = $seq_length - $pros;
	
#	my $maxpros = int( 0.90 * $$hit{alignment_length} + 0.5 );
#	my $pros = ( $$hit{num_similar} + $$hit{num_identical} ) / 2.0;
#	my $bonus = 0.15 * sqr( minval( $$hit{pct_scoverage}, $$hit{pct_qcoverage} ) / 100.0 ) * $$hit{alignment_length};
#	$pros = minval( $pros + $bonus, $maxpros );
#	my $cons = $$hit{alignment_length} - minval( $maxpros, $$hit{num_similar} );
#
#	# adjust short hits by extending to 50% coverage using 45% sim and 25% id
#	my $unknown = minval( $$hit{subject_length} - $$hit{subject_coverage}, $$hit{query_length} - $$hit{query_coverage} ) * 0.50;
#	if ( $unknown > 0.0 ) {
#		$pros += 0.35 * $unknown;
#		$cons += 0.55 * $unknown;
#	}

	# save score
	$$hit{pros} = $pros;
	$$hit{cons} = $cons;
	$$hit{confidence} = calculate_confidence( $hit );
	
	# collect definitions
	my @deflines;
	my @rawdefs;
	if ( $$hit{job_name} =~ /PRIAM/ ) {
		my $profile = $$hit{subject_id};
		if ( defined $ecProfs{$profile} ) {
			for my $ec ( keys %{ $ecProfs{$profile} } ) {
				if ( exists $ecDefs{$ec} ) {
					push @rawdefs, "$profile $ecDefs{$ec}";
				}
			}
		}
		if ( ! @rawdefs ) {
			push @rawdefs, "$profile uncharacterized enzyme";
		}
	}
	else {
		@rawdefs = split /; >/, $$hit{subject_definition};
	}

	# parse definitions
	for my $rawdef ( @rawdefs ) {
		my %defline;
		my ( $subject_id ) = split /  */, $rawdef;
		$defline{id} = $subject_id;
		$rawdef =~ s/^[^ ]*  *//;

		# check taxonomy
		$defline{taxon_id} = 131567; # cellular organism
		if ( $rawdef =~ /  *\[([^]]+)\] *$/ ) {
			my $taxname = $1;
			$rawdef =~ s/  *\[([^]]+)\] *$//;
			if ( defined $$taxonomy_lookup{$taxname} ) {
				$defline{taxon_id} = $$taxonomy_lookup{$taxname};
				$defline{taxon_name} = $taxname;
			}
#print "NR: taxonomy: $taxname  id: $defline{taxon_id}\n";
		} elsif ( $rawdef =~ /  *n=.* Tax=(.*) RepID=/) {
			my $taxname = $1;
			$rawdef =~ s/  *n=.* Tax=(.*) RepID=.*$//;
			if ( defined $$taxonomy_lookup{$taxname} ) {
				$defline{taxon_id} = $$taxonomy_lookup{$taxname};
				$defline{taxon_name} = $taxname;
			}
#print "UR: taxonomy: $taxname  id: $defline{taxon_id}\n";
		} elsif ( $rawdef =~ /  *OS=(.*) GN=/) {
			my $taxname = $1;
			$rawdef =~ s/  *OS=.* GN=.*$//;
			if ( defined $$taxonomy_lookup{$taxname} ) {
				$defline{taxon_id} = $$taxonomy_lookup{$taxname};
				$defline{taxon_name} = $taxname;
			}
#print "Tr: taxonomy: $taxname  id: $defline{taxon_id}\n";
		}

#		if ( defined $target_taxon_id ) {
#			$defline{taxon_distance} = taxonomy_distance($defline{taxon_id}, $target_taxon_id);
#		}


# clean-up definition
		if ( $$hit{job_name} =~ /^CDD/ ) {
			$defline{definition} = cdd_name_parser( $rawdef );
			my $id = $rawdef;
			$id =~ s/[ ,].*//;
			if ( $id =~ /^pfam/i ) { next }		# prefer pfam from HMM hits
			$defline{id} = $id;
		}
		elsif ( $$hit{job_name} eq "TAIR" ) {
			$defline{definition} = tair_name_parser( $rawdef );
		}
		elsif ( $$hit{job_name} eq "CUSTOMDB" ) {
			$defline{definition} = simple_name_parser( $rawdef );
		}
		else {
			$defline{definition} = unipro_name_parser( $rawdef );
		}
		$defline{original} = $defline{definition};

# save blast hit
		push @deflines, \%defline;
	}
	
	$$hit{deflines} = \@deflines;
	return $hit;
}

sub sumHSPs {
	my ( @hsps ) = sort { $$a{evalue} <=> $$b{evalue} } @_;
	
	my $dbg = 0;
	#if ( @hsps > 1 ) { $dbg = 1 }
	
	# sum the HSPs
	my $sum = shift @hsps;
	my %qid;
	my %qsim;
	my %sid;
	my %ssim;
	$$sum{num_hsps} = 1;
	recordBase( \%sid, $$sum{subject_left}, $$sum{subject_right}, $$sum{pct_identity} );
	recordBase( \%ssim, $$sum{subject_left}, $$sum{subject_right}, $$sum{pct_similarity} );
	recordBase( \%qid, $$sum{query_left}, $$sum{query_right}, $$sum{pct_identity} );
	recordBase( \%qsim, $$sum{query_left}, $$sum{query_right}, $$sum{pct_similarity} );

	for my $hsp ( @hsps ) {
		$$sum{num_hsps}++;
		recordBase( \%sid, $$hsp{subject_left}, $$hsp{subject_right}, $$hsp{pct_identity} );
		recordBase( \%ssim, $$hsp{subject_left}, $$hsp{subject_right}, $$hsp{pct_similarity} );
		recordBase( \%qid, $$hsp{query_left}, $$hsp{query_right}, $$hsp{pct_identity} );
		recordBase( \%qsim, $$hsp{query_left}, $$hsp{query_right}, $$hsp{pct_similarity} );

		if ( $$hsp{subject_left} < $$sum{subject_left} ) { $$sum{subject_left} = $$hsp{subject_left} }
		if ( $$hsp{subject_right} > $$sum{subject_right} ) { $$sum{subject_right} = $$hsp{subject_right} }
		if ( $$hsp{query_left} < $$sum{query_left} ) { $$sum{query_left} = $$hsp{query_left} }
		if ( $$hsp{query_right} > $$sum{query_right} ) { $$sum{query_right} = $$hsp{query_right} }

		for my $attr ( "alignment_length" ) {
			$$sum{$attr} += $$hsp{$attr};
		}
	}

	# calculate coverages
	$$sum{subject_coverage} = minval( countBases( %sid ), countBases( %qid ) );
	$$sum{query_coverage} = $$sum{subject_coverage};
	
	# estimate alignment length
	my $alen = $$sum{subject_coverage};
	my $scale = $alen / $$sum{alignment_length};
	if ( $dbg ) {
		print "merged: QL $$sum{query_length}  SL $$sum{subject_length}\n";
		print "merged: QR $$sum{query_left} - $$sum{query_right}\n";
		print "merged: SR $$sum{subject_left} - $$sum{subject_right}\n";
		print "merged: Qcov $$sum{query_coverage} Scov: $$sum{subject_coverage}\n";
		print "merged: align est $alen  align len $$sum{alignment_length}  scale $scale\n";
	}
	$$sum{alignment_length} = int( $$sum{alignment_length} * $scale + 0.5 );
	if ( $dbg ) {
		print "merged: adjusted align len: $$sum{alignment_length}\n"; 
	}
	# estimate %id / %sim
	my $pctid = ( averageBases( %sid ) + averageBases( %qid ) ) / 2.0;
	my $pctsim = ( averageBases( %ssim ) + averageBases( %qsim ) ) / 2.0;
	if ( $pctsim < $pctid ) { $pctsim = $pctid }

	# estimate gaps, adjust estimated alignment length
	my $gapest = int( ( 1.0 - $pctsim / 100.0 ) * $$sum{alignment_length} / 50.0 + 0.5 );
	$$sum{alignment_length} += $gapest;
	if ( $dbg ) {
		print "merged: estimated gaps: $gapest\n"; 
	}

	# estimate number of identical / similar bases
	$$sum{num_identical} = int( $pctid / 100.0 * $$sum{alignment_length} + 0.5 );
	$$sum{num_similar} = int( $pctsim / 100.0 * $$sum{alignment_length} + 0.5 );

	# calculate percentages based on estimates
	$$sum{pct_identity} = int( 1000.0 * $$sum{num_identical} / $$sum{alignment_length} + 0.5 ) / 10.0;
	$$sum{pct_similarity} = int( 1000.0 * $$sum{num_similar} / $$sum{alignment_length} + 0.5 ) / 10.0;
	$$sum{pct_scoverage} = int( 1000.0 * $$sum{subject_coverage} / $$sum{subject_length} + 0.5 ) / 10.0;
	$$sum{pct_qcoverage} = int( 1000.0 * $$sum{query_coverage} / $$sum{query_length} + 0.5 ) / 10.0;
	$$sum{pct_coverage} = maxval( $$sum{pct_scoverage}, $$sum{pct_qcoverage} );
	
	return $sum;
}

sub recordBase {
	my ( $hash, $from, $to, $val ) = @_;
	
	for my $base ( $from..$to ) {
		if ( ! defined $$hash{$base} || $val > $$hash{$base} ) { $$hash{$base} = $val }
	}
}

sub averageBases {
	my ( %hash ) = @_;
	
	my $total = 0;
	my $count = 0;
	for my $base ( keys %hash ) {
		$total += $hash{$base};
		$count++;
	}
	
	if ( $count < 1 ) { return undef }
	return $total / $count;
}

sub countBases {
	my ( %hash ) = @_;
	
	my $count = keys %hash;
	
	return $count;
}

sub sumDomains {
	my ( @domains ) = @_;

	# merge domain hits into total hit
	my $hmm = shift @domains;
	$$hmm{domain_number} = 0;
	$$hmm{num_hsps} = 1 + @domains;

	my %cov;
	for my $b ( $$hmm{hmm_begin}..$$hmm{hmm_end} ) {
		$cov{$b} = 1;
	}

	for my $domain ( @domains ) {
		for my $b ( $$domain{hmm_begin}..$$domain{hmm_end} ) {
			$cov{$b} = 1;
		}
					
		if ( $$domain{hmm_begin} < $$hmm{hmm_begin} ) { $$hmm{hmm_begin} = $$domain{hmm_begin} }
		if ( $$domain{hmm_end} > $$hmm{hmm_end} ) { $$hmm{hmm_end} = $$domain{hmm_end} }
		if ( $$domain{query_begin} < $$hmm{query_begin} ) { $$hmm{query_begin} = $$domain{query_begin} }
		if ( $$domain{query_end} > $$hmm{query_end} ) { $$hmm{query_end} = $$domain{query_end} }
	}

	my $cov = int( 1000.0 * ( keys %cov ) / $$hmm{hmm_length} + 0.5 ) / 10.0;
	if ( $cov !~ /\./ ) { $cov .= ".0" }
	$$hmm{pct_scoverage} = $cov;
	$$hmm{pct_coverage} = $$hmm{pct_scoverage};
	
	return $hmm;
}

sub printHit {
	my(  $label, $hit ) = @_;
	print "*** "
		. rpad($label,12)
		. rpad($$hit{subject_id},15)
		. " " . rpad("B:" . int($$hit{bit_score}), 8)
		. " " . rpad("E:" . format_evalue($$hit{evalue}), 10)
		. " " . rpad("Q:$$hit{query_left}-$$hit{query_right}",12)
		. " " . rpad("S:$$hit{subject_left}-$$hit{subject_right}",12)
		. " " . rpad("G:$$hit{query_gaps},$$hit{subject_gaps}",8)
		. " " . rpad("L:$$hit{alignment_length}",8)
		. " " . rpad("I:$$hit{num_identical}",8)
		. " " . rpad("S:$$hit{num_similar}",8)
		. "\n";	
}

sub compareSubjCoords {
	my ( $a, $b ) = @_;
	if ( $$a{subject_left} < $$b{subject_left} ) {
		return -1;
	} elsif ( $$b{subject_left} < $$a{subject_left} ) {
		return 1;
	} elsif ( $$a{subject_right} < $$b{subject_right} ) {
		return -1;
	} elsif ( $$b{subject_right} < $$a{subject_right} ) {
		return 1;
	} else {
		return 0;
	}
}

sub compareHMMCoords {
	my ( $a, $b ) = @_;
	if ( $$a{hmm_begin} < $$b{hmm_begin} ) {
		return -1;
	} elsif ( $$b{hmm_begin} < $$a{hmm_begin} ) {
		return 1;
	} elsif ( $$a{hmm_end} < $$b{hmm_end} ) {
		return -1;
	} elsif ( $$b{hmm_end} < $$a{hmm_end} ) {
		return 1;
	} else {
		return 0;
	}
}

sub compareQryCoords {
	my ( $a, $b ) = @_;
	if ( $$a{query_left} < $$b{query_left} ) {
		return -1;
	} elsif ( $$b{query_left} < $$a{query_left} ) {
		return 1;
	} elsif ( $$a{query_right} < $$b{query_right} ) {
		return -1;
	} elsif ( $$b{query_right} < $$a{query_right} ) {
		return 1;
	} else {
		return 0;
	}
}

sub rank_isotype {
	my ( $isotype ) = @_;
	if ( exists $isotype_rank{$isotype} ) { return $isotype_rank{$isotype} }
	return $no_isotype;
}


sub collect_TigrPfam_details {
	my ($sqlh) = @_;

	# clear old data from sqlite db
	my $delete = &executeSQL( $sqlh, "delete from hmm_go_link" );
	my $delete = &executeSQL( $sqlh, "delete from hmm3" );

	# connect to sybase
	my $sybh = connectSybase( "hmm", "access", "access" );
	if ( !defined $sybh ) { die "\nsybase connect: " . $DBI::errstr . "\n" }

	# copy hmm3 data
	my $data = $sybh->selectall_arrayref("select hmm_acc,iso_type from hmm3");
	if ( !defined $data ) { die "\nselect hmm3: " . $DBI::errstr . "\n" }

	foreach my $row (@$data) {
		my $insert =
		  $sqlh->do( "insert into hmm3(hmm_acc,iso_type) values(?,?)",
			undef, @$row );
		if ( !defined $insert ) { die "\ninsert hmm3: " . $DBI::errstr . "\n" }
	}

	# copy hmm_go_link data
	$data =
	  $sybh->selectall_arrayref(
		"select distinct hmm_acc, go_term from hmm_go_link");
	if ( !defined $data ) { die "\nselect hmm_go_link: " . $DBI::errstr . "\n" }

	foreach my $row (@$data) {
		my $insert =
		  $sqlh->do( "insert into hmm_go_link(hmm_acc,go_term) values(?,?)",
			undef, @$row );
		if ( !defined $insert ) {
			die "\ninsert hmm_go_link: " . $DBI::errstr . "\n";
		}
	}

	$sqlh->commit;

	# disconnect from sybase
	$sybh->disconnect;

	return;
}

sub fix_groupings {
	my ( $name ) = @_;
#print "fix_groupings: $name\n";	

	$name =~ s/^ +//;
	$name =~ s/ +$//;
	my @phrases = split /([\])};,.] )/, $name;
	my $newname = shift @phrases;
	while ( @phrases ) {
		my $phrase = shift @phrases;
		if ( $phrase =~ /^[\])};,.] $/ ) {
			$newname .= $phrase
		}
		elsif ( length( $newname ) < 72 ) {
			$newname .= $phrase;
		}
		else {
			@phrases = ();
		}
	}
	while ( $newname =~ /(\([^)(]{5,}) \(([^)(]{5,})\)/ ) {
		$newname =~ s/(\([^)(]{5,}) \(([^)(]{5,})\)/$1, $2,/;
	}
		
	while ( $newname =~ /\(([^)(]{5,})\) \(([^)(]{5,})\) *$/ ) {
		$newname =~ s/\(([^)(]{5,})\) \(([^)(]{5,})\) *$/, $1, $2 /;
#print "###name###=$newname\n";
	}
	while ( $newname =~ /^ *\(([^)(]{5,})\) \(([^)(]{5,})\)/ ) {
		$newname =~ s/^ *\(([^)(]{5,})\) \(([^)(]{5,})\)/$1, $2, /;
#print "###name###=$newname\n";
	}
	
	$newname =~ s/^ +//;
	$newname =~ s/ +$//;
	
	my @tmp;
	my $end;
	my $continue = 1;
	while( $continue ) {
		$continue = 0;
		@tmp = split /([\[\]{}()])/, $newname;
#print "tmp " . join( " | ", @tmp ) . "\n";
		$end = @tmp-1;
		if ( $end > 0 ) {
			for my $group ( "()", "{}", "[]" ) {
#print "group $group...";
				my $open = substr( $group, 0, 1 );
				my $close = substr( $group, 1 );
				my $depth = 0;
				my $tmpend = -1;
				for my $i ( 0..$end ) {
					my $string = $tmp[$i];
					if ( $string eq $open ) { $depth++ }
					elsif ( $string eq $close ) { $depth-- }
					if ( $depth < 0 ) {
						$tmp[$i] = "";
						$depth = 0;
					}
					if ( $depth == 0 ) { $tmpend = $i }
#print "$i|$tmp[$i]|$depth|$tmpend..."
				}
#print "\n";
				if ( $tmpend < $end ) { $end = $tmpend }
				if ( $end < 0 ) { last }
			}
			if ( $end < 0 ) {
				$newname =~ s/^ *[\[({] *//;
				$continue = 1;
#print "reset $newname\n";
			}
		}
	}
	while ( @tmp > $end+1 ) {
		pop @tmp;
	}
	$newname = join( "", @tmp );
	$newname =~ s/\([, ]+/(/g;
	$newname =~ s/\{[, ]+/{/g;
	$newname =~ s/\[[, ]+/[/g;
	$newname =~ s/[, ]+\)/)/g;
	$newname =~ s/[, ]+\}/}/g;
	$newname =~ s/[, ]+\]/]/g;
	$newname =~ s/\(\)//g;
	$newname =~ s/\[\]//g;
	$newname =~ s/\{\}//g;
	$newname =~ s/,[ ,]+,/,/g;
	if ( $newname =~ /^[, ]*\(([^()]*)\)[, ]*$/ ) {
		$newname = $1;
	}
	elsif ( $newname =~ /^[, ]*\{([^{}]*)\}[, ]*$/ ) {
		$newname = $1;
	}
	elsif ( $newname =~ /^[, ]*\[([^]\]]*)\][, ]*$/ ) {
		$newname = $1;
	}
	
#if ( $name ne $newname ) { print "\ngroupings\n  from $name\n    to $newname\n" }
	return $newname;
}

sub format_pct {
	my ( $pct ) = @_;
	
	if ( defined $pct && $pct ne "-" ) {
		$pct = int( 10. * $pct + 0.5 ) / 10.;
		if ( index( $pct, "." ) < 0 ) { $pct .= ".0" } 
	}
	
	return $pct;
}

sub format_evalue {
	my ( $evalue ) = @_;

	if ( defined $evalue ) {
		my ( $a, $b ) = split /[eE]\-/, $evalue;
		if ( !defined $b || !length($b) ) { $b = 0 }
		if ( $a < 0.0 ) { $a = 0.0 }
		if ( $a > 0 ) {
			while ( $a < 1.0 ) {
				$a = 10. * $a;
				$b++;
			}
			while ( $a >= 10.0 ) {
				$a = $a / 10.0;
				$b--;
			}
			$a = int( 10.0 * $a + 0.5 ) / 10.;
			if ( $a == 10.0 ) {
				$a = 1.0;
				$b++;
			}
			if ( $b >= 1 ) {
				$b =~ s/^0*//;
				$b = lpad( $b, 3, "0" );
			}
			else {
				$b = "";
			}
		}
		if ($b) {
			if ( index( $a, "." ) < 0 ) { $a .= ".0" }
			$evalue = "$a-e$b";
		}
		else {
			$evalue = $a;
		}
	}

	return $evalue;
}

sub tmhmm_name_parser {
	my ( $row ) = @_;
	return "transmembrane protein, putative";
}

sub get_hit_quality {
	my( $hit ) = @_;

	if ( defined $$hit{trusted_cutoff} ) {
		if ( $$hit{total_score} > $$hit{trusted_cutoff} ) {
			my $tr = "trusted";
			if ( defined $$hit{iso_type} ) {
				$tr .= " $$hit{iso_type} ";
			}
			return $tr;
		}
	}

	my @quality;
	if ( defined $$hit{total_evalue} ) {
		my $ev = format_evalue( $$hit{total_evalue} );
		push @quality, "eval: $ev";
	}
	elsif ( defined $$hit{evalue} ) {
		my $ev = format_evalue( $$hit{evalue} );
		push @quality, "eval: $ev";
	}
	if ( defined $$hit{pct_identity} ) {
		push @quality, "%id: $$hit{pct_identity}";
	}
	if ( defined $$hit{pct_scoverage} ) {
		push @quality, "%cov: $$hit{pct_coverage}";
	}
	elsif ( defined $$hit{pct_scoverage} ) {
		push @quality, "%covS: $$hit{pct_scoverage}";
	}
	elsif ( defined $$hit{pct_qcoverage} ) {
		push @quality, "%covQ: $$hit{pct_qcoverage}";
	}
	
	
	return join( ", ", @quality );
}

sub min {

	# return the smaller of two numbers

	my ( $num1, $num2 ) = @_;
	return ( $num1 < $num2 ) ? $num1 : $num2;

}

sub max {

    # return the larger of two numbers
    my ( $num1, $num2 ) = @_;
    return ($num1 > $num2) ? $num1 : $num2;

}

sub calculate_coverage {
	# calculate coverage as percentage of total length, to one decimal place
	my ( $beg, $end, $len ) = @_;
	if ( ! $len || $len < 1 ) { return undef }

	my $coverage = 100.0 * ( abs( $end - $beg ) + 1.0 ) / $len;
	if ( $coverage > 100.0 ) { $coverage = 100.0 }

	return $coverage;
}

#### Query Subs
sub get_query_seqs {
	my ( $dbh, $queryseq ) = @_;

	my $query;
	if ( defined $queryseq ) {
		$query = "select * from ("
			. "SELECT query_id, query_id FROM query_sequence where query_id='$queryseq'"
			. " UNION ALL"
			. " SELECT transcript_id, protein_id from transcript_protein where transcript_id='$queryseq') "
			. " ORDER BY 1";
	}
	else {
		$query = "select * from ("
			. "SELECT query_id, query_id FROM query_sequence"
			. " UNION ALL"
			. " SELECT transcript_id, protein_id from transcript_protein) "
			. " ORDER BY 1";
	}

	my $tmp = querySQLArrayArray( $dbh, $query );
	my $querySeqs;
	if ( defined $tmp ) {
		for my $seq ( @$tmp ) {
			$$seq[1] =~ s/'/'/g;
			if ( ! exists $$querySeqs{$$seq[0]} ) {
				$$querySeqs{$$seq[0]} = "'$$seq[1]'";
			} else {
				$$querySeqs{$$seq[0]} .= ",'$$seq[1]'";
			}
		}
	}

	return $querySeqs;
}

sub get_jobs {
	my $dbh = shift;

	# Did substr because without it query returns the job
	# id as a scientific number which is not useful
	my $query = "select * from"
		. "(SELECT distinct job_name, 'btab' as table_name from btab"
		. " UNION ALL"
		. " SELECT distinct job_name, 'htab' as table_name from htab"
		. " UNION ALL"
		. " SELECT 'TMHMM' as job_name, 'tmhmm' as table_name)"
		. " WHERE job_name != 'NR'"
		. " ORDER BY 1,2";

	my $jobs = querySQLHashHash($dbh,$query,"job_name");
	return $jobs;
}

sub compare_pros_and_cons {
	my ( $a, $b ) = @_;
	
	if ( $$a{pros} - $$a{cons} > $$b{pros} - $$b{cons} ) {
		return -1;
	}
	elsif ( $$a{pros} - $$a{cons} < $$b{pros} - $$b{cons} ) {
		return 1;
	}
	elsif ( $$a{cons} < $$b{cons} ) {
		return -1;
	}
	elsif ( $$a{cons} > $$b{cons} ) {
		return 1;
	}
	else {
		return 0;
	}
}	
		
sub printVerboseEvidenceHdr {
	my ( $jobname ) = @_;
	print "\n  "
	. lpad("EValue",10)
	. lpad("%CovS",6)
	. lpad("%CovQ",6)
	. lpad("%Id",6)
	. lpad("%Sim",6)
	. lpad("P-C", 7)
	. lpad("Conf",6)
	. lpad("HSP",4)
	. " Definition"
	. "\n";
}

sub printVerboseEvidenceItem {
	my ( $hit ) = @_;	

	my $pc = int( 10.0 * ( $$hit{pros} - $$hit{cons} ) + 0.5 ) / 10.0;
	if ( $pc !~ /\./ ) { $pc .= ".0" }

	my $hitline;	
	if ( $$hit{job_name} eq "TMHMM" ) {
		$hitline = "  "
			. lpad( "" ,10)
			. lpad( "" ,6)
			. lpad( "" ,6)
			. lpad( "" ,6)
			. lpad( "" ,6)
			. lpad( $pc, 7 )
			. lpad( $$hit{confidence}, 6)
			. lpad( "" ,4);
	}
	else {
		$hitline = "  "
			. lpad( format_evalue($$hit{evalue}), 10 )
			. lpad( format_pct($$hit{pct_scoverage}), 6 )
			. lpad( format_pct($$hit{pct_qcoverage}), 6 )
			. lpad( format_pct($$hit{pct_identity}), 6 )
			. lpad( format_pct($$hit{pct_similarity}), 6 )
			. lpad( $pc, 7 )
			. lpad( $$hit{confidence}, 6)
			. lpad( $$hit{num_hsps}, 4 );
	}
	for my $defline ( @{ $$hit{deflines} } ) {
		print $hitline . "  " . substr( "$$defline{id} | $$defline{definition}", 0, 100 ) . "\n";
		$hitline =~ s/./ /g;
	}	
}

sub create_workspace {
	my $me = `whoami`;
	chomp $me;
	
	my $rootspace = "/usr/local/scratch/EUK/$me";
	if ( !-e $rootspace ) { mkdir $rootspace }
	if ( ! -w $rootspace ) { die "\ncannot create workspace in /usr/local/scratch/EUK/$me\n"} 

	my $workspace = $rootspace . "/" . rand(1000000);
	while ( -e $workspace ) {
		$workspace = $rootspace . "/" . rand(1000000);
	}

	print "workspace=$workspace\n";
	mkdir $workspace;
	return $workspace;
}

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

sub open_filehandle {
# returns a filehandle in either gzip or normal binmode, based on the gzip
# option as specifed (or not) by the user

    my ($filename, $gzip, $direction) = @_;
    
    my $fh;
    my $fhdir = ($direction eq 'IN') ? '<' : '>'; 
    
    if ($gzip) {
        open($fh,"$fhdir:gzip","$filename.gz") || die "Can't open $filename: $!\n";
    } else {
        open($fh,"$fhdir"."$filename") || die "Can't open $filename: $!\n";
    }    
    
    return $fh;
}

sub cazy_acc_to_name {
	my ( $acc ) = @_;
	
	my ( undef, $id ) = split /_/, $acc;
	
	if ( $id =~ /CBM([0-9]+)/i ) {
		return "carbohydrate-binding module family $1 protein";
	}
	elsif ( $id =~ /GH([0-9]+)/i ) {
		return "glycoside hydrolase family $1 protein";
	}
	elsif ( $id =~ /GT([0-9]+)/i ) {
		return "glycosyltransferase family $1 protein";
	}
	elsif ( $id =~ /PL([0-9]+)/i ) {
		return "polysaccharide lyase family $1 protein";
	}
	elsif ( $id =~ /CE([0-9]+)/i ) {
		return "carbohydrate esterase family $1 protein";
	}
	else {
		return "$acc family protein";
	}
}

1;
