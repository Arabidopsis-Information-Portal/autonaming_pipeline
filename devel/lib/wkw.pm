#!/usr/local/bin/perl
use strict;
our $errorMessage;
our $myLib;
our ( $excludecompute, $consensus_threshold, $trusted_list, $exclude_taxon_id,
	$excludebranch_taxon_id, $excludedtaxons, $taxonomy_lookup, $queryseq );
our $verbose;
our %goNames;
our ( %ecDefs, %ecProfs );

our ( $greek, $roman, $kingdoms,
		$domains, $isoforms, $groups, $subunits,
		$homologs, $homologous, $strength, $enzymes,
		$gerunds, $gerund2noun,
		$goodends, $badends,
		$keeppros, $aminoacids,
		$unknowns );

sub cross_reference_taxonomy {
	my ( $dbh ) = @_;
	my $dbg = 0;

	print "constructing taxonomy lookup table\n";
	my $taxdbh = connectSQLite("/usr/local/devel/ANNOTATION/APIS/pipeline/data/v1/taxondb.db");
	my $tmp = querySQLArrayArray( $dbh, "select distinct subject_definition from btab" );
	for my $row (@$tmp) {
		my @defs = split /; >/, $$row[0];
		for my $def (@defs) {
			my $rawtax = "";
			if ( $def =~ /  *n=.* Tax=(.*) RepID=/ ) {
				$rawtax = $1;
			}
			elsif ( $def =~ /  *OS=(.*) GN=/ ) {
				$rawtax = $1;
			}
			elsif ( $def =~ /  *\[([^]]+)\] *$/ ) {
				$rawtax = $1;
			}

			#print "definition $def\ntaxonomy $rawtax\n";

			if ( $rawtax eq "" ) { next }
			if ( exists $$taxonomy_lookup{$rawtax} ) { next }
			if ($dbg) {
				print "searching for taxonid for taxonomy $rawtax\n";
			}
			my $tax = firstRowSQL(
				$taxdbh,
				"select taxon_id from taxonomy where taxon_id in"
				  . " (select taxon_id from taxonomy_synonym where lower_name=lower(?))"
				  . " order by is_obsolete, taxon_id",
				$rawtax
			);
			if ( !defined $tax ) {
				die " taxondb query failed: $errorMessage\n";
			}
			if ( @$tax && $$tax[0] > 0 ) {
				$$taxonomy_lookup{$rawtax} = $$tax[0];
				if ($dbg) {
					print "taxonomy $rawtax assigned taxon id $$tax[0]\n";
				}
				next;
			}
			my $taxname;
			my $taxonid = -1;
			for my $taxword ( split / +/, $rawtax ) {
				if ( defined $taxname ) { $taxname .= " " }
				$taxname .= $taxword;
				my $tax = firstRowSQL(
					$taxdbh,
					"select taxon_id from taxonomy where taxon_id in"
					  . " (select taxon_id from taxonomy_synonym where lower_name=lower(?))"
					  . " order by is_obsolete, taxon_id",
					$taxname
				);
				if ( !defined $tax ) {
					die " taxondb query failed: $errorMessage\n";
				}
				if ( @$tax && $$tax[0] > 0 ) {
					$taxonid = $$tax[0];
					if ($dbg) { print "  $taxname = $taxonid\n" }
				}
			}
			$$taxonomy_lookup{$rawtax} = $taxonid;
			if ($dbg) {
				print "taxonomy $rawtax assigned taxon id $taxonid\n";
			}
		}
	}
	
	$taxdbh->disconnect();
}

sub get_excluded_taxons {
	my ( $exclude_taxon_id, $excludebranch_taxon_id ) = @_;
	
	my %exclusions;
	if ( defined $exclude_taxon_id ) { $exclusions{$exclude_taxon_id} = 1 }
	
	if ( defined $excludebranch_taxon_id ) {
		my $taxdbh = connectSQLite("/usr/local/devel/ANNOTATION/APIS/pipeline/data/v1/taxondb.db");
		my $sql = "select distinct taxon_id from taxonomy_lineage where related_id in ($excludebranch_taxon_id)";
		my $results = querySQLArrayArray( $taxdbh, $sql );
		if ( $results ) {
			for my $row ( @$results ) {
				my $taxonid = $$row[0];
				$exclusions{$taxonid} = 1;
			}
		}
		$taxdbh->disconnect();
	}
	
	if ( $verbose && keys %exclusions ) {
		print "excluding taxons " . join( ", ", sort { $a <=> $b } keys %exclusions ) . "\n";
	}
	
	return \%exclusions;
}

sub collect_GO_definitions {
	my %tmp = %{ do "/usr/local/devel/ANNOTATION/APIS/pipeline/lib/goNames.dmp" };
	for my $go ( values %tmp ) {
		if ( $$go{type} =~ /^(exact|definition)$/i ) {
			$goNames{ $$go{goId} }{ $$go{name} } = 1;
		}
	}
}

sub collect_PriamEC_details {
	my @defs;
	for my $line ( split /\n/, `cat $myLib/../config/enzclass.txt` ) {
		if ( $line =~ /^([1-9].*\..*\..*\.[^ ]*) +(.*) *$/ ) {
			my $ec  = $1;
			my $def = $2;
			$def =~ s/\t/ /g;
			$def =~ s/\.$//;
			$ec  =~ s/ //g;
			my (@tmp) = split /\./, $ec;
			if ( $tmp[1] eq "-" ) {
				@defs = ($def);
			}
			elsif ( $tmp[2] eq "-" ) {
				while ( @defs > 1 ) { pop @defs }
				push @defs, $def;
			}
			elsif ( $tmp[3] eq "-" ) {
				while ( @defs > 2 ) { pop @defs }
				push @defs, $def;
			}
			$def = join( ", ", @defs );
			$def =~ s/ases(\W|$)/ase/g;
			$ecDefs{$ec} = $def;

			#print "$ec\t$def\n";
		}
	}

	# transferred EC numbers
	# and EC definitions
	my $id;
	my %ectrans;
	for my $line ( split /\n/,
		`grep -E "(^ID |^DE )" $myLib/../config/enzyme.dat` )
	{

		if ( $line =~ /^ID/ ) {
			( undef, $id ) = split / +/, $line;
		}
		else {
			my $def = $line;
			$def =~ s/^[^ ]* *//;
			$def =~ s/\. *$//;
			if ( $def =~ /Transferred entry: (.*)/ ) {
				my $def = $1;
				if ( $def =~ /(,| and )/ ) {
					$def =~ s/(,| and ).*$//;
					$def =~ s/\.[0-9]+$/.-/;
				}
				$ectrans{$id} = $def;

				#print "$id => $def\n";
			}
			elsif ( defined $id && $def !~ /Deleted entry/ ) {
				$ecDefs{$id} = $def;

				#print "$id\t$def\n";
			}
		}
	}

	# PRIAM profile-EC links
	for my $line (
		split /\n/,
		`grep "<PROFILE " /usr/local/db/priam/05-2011/priam_05_2011.rules.xml`
	  )
	{
		if ( $line =~ / ac="([^"]+)" .* ECs="([^"]+)"/ ) {
			my $profile = $1;
			my @ecs = split /;/, $2;
			for my $ec (@ecs) {
				if ( exists $ectrans{$ec} ) { $ec = $ectrans{$ec} }
				$ecProfs{$profile}{$ec} = 1;

				#print "$profile\t$ec\n";
			}
		}
	}
}

sub collect_query_evidence {
	my ( $dbh, $seq_list, $jobs ) = @_;

	my %evidence;
	my $besthit;

	for my $job_name ( keys %$jobs ) {
		my $hits = &extract_evidence( $dbh, $seq_list, $job_name, $$jobs{$job_name}{table_name} );
		my @tmphits;
#print "\n$job_name\n";
#printVerboseEvidenceHdr();
		for my $hit ( @$hits ) {
			my @tmpdefs;
			for my $def ( @{ $$hit{deflines} } ) {
				if (defined $$def{taxon_id} && exists $$excludedtaxons{  $$def{taxon_id} } ) {
					if ( $verbose ) { print "excluding taxonomy $$def{taxon_name}: $$def{id} | $$def{definition}\n" }
				}
				else {
					push @tmpdefs, $def;
				}
			}
			if ( @tmpdefs ) {
				$$hit{deflines} = \@tmpdefs;
				push @tmphits, $hit;
#printVerboseEvidenceItem($hit);

				if ( ! defined $besthit || compare_pros_and_cons( $besthit, $hit ) > 0 ) {
					$besthit = $hit;
				}
			}
		}

		if ( @tmphits ) {
			$evidence{$job_name} = \@tmphits;

			# extract GO hits from pfam/tigr hits
			if ( $job_name =~ /(PFAM|TIGR)/ ) {
				my @gohits;
				for my $hit ( @tmphits ) {
					my @tmp = formatGOhit( $dbh, $hit );
					if (@tmp) {
						push @gohits, @tmp;
					}
				}
				if (@gohits) {
					if ( defined $evidence{GO} ) {
						push @{ $evidence{GO} }, @gohits;
					}
					else {
						$evidence{GO} = \@gohits;
					}
				}
			}
		}
	}

	if ( ! defined $besthit ) { return undef, undef }
	return ( $besthit, \%evidence );
}

sub display_evidence {
	my ($evidence) = @_;

	if ( !defined $evidence ) {
		print "\nNo evidence.\n";
	}
	else {
		for my $job_name ( sort { $a cmp $b } keys %$evidence ) {
			print "\n$job_name\n";
			printVerboseEvidenceHdr();
			if ( defined $$evidence{$job_name} ) {
				for my $hit ( sort { compare_pros_and_cons( $a, $b ) }
					@{ $$evidence{$job_name} } )
				{
					printVerboseEvidenceItem($hit);
				}
			}
		}
	}
}

sub report_hypothetical_protein {
	my ( $afh, $seq_acc ) = @_;

	print $afh "$seq_acc\thypothetical protein\t\t\t\n";
	print "\n  $seq_acc\thypothetical protein\t\t\t\n";
}

sub report_conserved_hypothetical_protein {
	my ( $afh, $seq_acc, $besthit ) = @_;

	for my $defline ( @{ $$besthit{deflines} } ) {
		my $evidence = $$besthit{job_name};
		if ( $evidence ne "TMHMM" ) { $evidence .= "|$$defline{id}" }
		print $afh
"$seq_acc\thypothetical protein\t$evidence\t$$besthit{confidence}\t\n";
		print
"\n  $seq_acc\thypothetical protein\t$evidence\t$$besthit{confidence}\t\n";
		last;
	}
}

sub collect_evidence_names {
	my ($evidence) = @_;
	if ( !defined $evidence ) { return undef }

	my %rawnames;
	my $besthit;
	my $namecount = 0;
	for my $job_name ( keys %$evidence ) {
		if ( !defined $$evidence{$job_name} ) { next }
		for my $hit ( @{ $$evidence{$job_name} } ) {
			$$hit{cnt} = 0;
			$$hit{demoted} = 0;
			my $value = $$hit{confidence};
			if ( $value < 0.5 ) { $value = 0 }

			for my $defline ( @{ $$hit{deflines} } ) {
				my $name = $$defline{definition};
				if ( !defined $name || $name !~ /\w/ ) { next }

				$rawnames{$name}{text} = $name;
				if ( $$hit{job_name} eq "CUSTOMDB" ) { $rawnames{$name}{is_custom} = 1 }
				if ( !exists $rawnames{$name}{hitlist}{ $$hit{hit_id} } ) {
					$rawnames{$name}{hitlist}{ $$hit{hit_id} } = $hit;
					if ( $job_name =~ /^(GO)/ ) {
						#print "demoting $job_name: $$defline{id} | $$defline{definition}\n";
						$rawnames{$name}{demoted}++;
						$$hit{demoted}++;
					}
					else {
						$rawnames{$name}{cnt}++;
						$rawnames{$name}{cnt500} += $value;
						$$hit{cnt}++;
						$$hit{cnt500} += $value;
					}
					if ( $$hit{confidence} >= 0.700 ) {
						$rawnames{$name}{good} += sqr( $$hit{confidence} / 0.750 );
					}
					$namecount++;
				}
			}
			if ( $$hit{cnt} == 0  ) {
				$$hit{pros} = 0.75 * $$hit{pros};
				$$hit{cons} = 0.75 * $$hit{cons};
			}
		}
	}
	if ( $namecount == 0 ) { return undef }

	standardize_names( \%rawnames );

	my %names;
	$namecount = 0;
	for my $rawname ( keys %rawnames ) {
		my $name = $rawnames{$rawname}{text};
		my $orig = $rawnames{$rawname}{orig};
		if ( $name ne $rawname ) {
			for my $hit ( values %{ $rawnames{$rawname}{hitlist} } ) {
				for my $defline ( @{ $$hit{defline} } ) {
					if ( $$defline{definition} eq $rawname ) {
						$$defline{definition} = $name;
					}
				}
			}
		}

		my $namekeys = get_keywords($name, 2 );
		if ( !defined $namekeys ) { next }

		if ( !defined $rawnames{$rawname}{cnt} ) {
			$rawnames{$rawname}{cnt} = 0;
		}
		if ( !defined $rawnames{$rawname}{cnt500} ) {
			$rawnames{$rawname}{cnt500} = 0;
		}
		if ( !defined $rawnames{$rawname}{demoted} ) {
			$rawnames{$rawname}{demoted} = 0;
		}
		if ( !defined $rawnames{$rawname}{good} ) {
			$rawnames{$rawname}{good} = 0;
		}

		if ( !exists $names{$name} ) {
			$names{$name}{keywords} = $namekeys;
			$names{$name}{text}     = $name;
			$names{$name}{orig}     = $orig;
			$namecount++;
		}
		$names{$name}{cnt}   += $rawnames{$rawname}{cnt};
		$names{$name}{cnt500}   += $rawnames{$rawname}{cnt500};
		$names{$name}{demoted} += $rawnames{$rawname}{demoted};
		$names{$name}{good}  += $rawnames{$rawname}{good};
		for my $hit_id ( keys %{ $rawnames{$rawname}{hitlist} } ) {
			$names{$name}{hitlist}{$hit_id} =
			  $rawnames{$rawname}{hitlist}{$hit_id};
		}

#print "raw: $rawname  cnt/excluded/good: $rawnames{$rawname}{cnt}/$rawnames{$rawname}{demoted}/$rawnames{$rawname}{good}"
#	. "  std: $name  cnt/excluded/good: $names{$name}{cnt}/$names{$name}{demoted}/$names{$name}{good}\n";
	}
	if ( $namecount == 0 ) { return undef }
	return \%names;
}

sub standardize_names {
	my ($names) = @_;

	# clean-up names
	# (leave custom DB names as is - we assume they have been manually curated)

	my @tmp = keys %$names;
	my $standardCase = standardize_case( \@tmp );
	for my $name ( values %$names ) {
		$$name{orig} = $$name{text};

		# standardize capitaliztion	
		# make sure the name follows NCBI's rule
		if ( ! defined $$name{is_custom} || index( $trusted_list, "CUSTOMDB" ) < 0 ) {
			$$name{text} = $$standardCase{ $$name{text} };
#print "\n";
#print "orig: $$name{orig}\n";		
#print "case: $$name{text}\n";		

			$$name{text} = standardize_name( $$name{text} );
#print "stnd: $$name{text}\n";
		}
		
		# update the deflines for the changed names
		if ( $$name{orig} ne $$name{text} ) {
			for my $hit ( values %{ $$name{hitlist} } ) {
				for my $defline ( @{ $$hit{deflines} } ) {
					if ( $$defline{definition} eq $$name{orig} ) {
						$$defline{definition} = $$name{text};
					}
				}
			}
		}
	}
}

sub collect_name_keywords {
	my ($names) = @_;
	if ( !defined $names ) { return undef }

	my %keywords;
	for my $name ( values %$names ) {
		my $name_occurences = $$name{cnt} + $$name{demoted};

#print "\n$$name{text} occ: $name_occurences = $$name{cnt} + $$name{demoted}\n";
		for my $kw ( keys %{ $$name{keywords}{keywgt} } ) {

#print "  $kw: cnt: $$name{keywords}{keycnt}{$kw}  wgt: $$name{keywords}{keywgt}{$kw}\n";
			$keywords{keywgt}{$kw} += $name_occurences * $$name{keywords}{keywgt}{$kw};
			$keywords{keycnt}{$kw} += $name_occurences;

			for my $hit_id ( keys %{ $$name{hitlist} } ) {
				$keywords{hitlist}{$kw}{$hit_id} = $$name{hitlist}{$hit_id};
			}
		}
	}
	for my $kw ( keys %{ $keywords{keywgt} } ) {
		$keywords{keywgt}{$kw} = $keywords{keywgt}{$kw} / $keywords{keycnt}{$kw};
	}
	delete $keywords{keycnt};

	return \%keywords;
}

sub weight_keyword_evidence {
	my ( $keywords, $evidence ) = @_;
	my $dbg = 0;

	my $decay = sqrt( 0.5 );
	my $floor   = 0.400;

	my $evidence_count = 0;
	for my $job_name ( keys %$evidence ) {
		if ( defined $$evidence{$job_name} ) {
			$evidence_count += @{ $$evidence{$job_name} };
		}
	}

	my $named_evidence_count = 0;
	my $average_hit_pros     = 0;
	my $average_hit_cons     = 0;
	{
		my %named_evidence;
		for my $kw ( keys %{ $$keywords{hitlist} } ) {
			for my $hit_id ( keys %{ $$keywords{hitlist}{$kw} } ) {
				$named_evidence{$hit_id} = $$keywords{hitlist}{$kw}{$hit_id};
			}
		}
		$named_evidence_count = keys %named_evidence;
		for my $hit ( values %named_evidence ) {
			$average_hit_pros += $$hit{pros};
			$average_hit_cons += $$hit{cons};
		}
		$average_hit_pros =
		  format_decimal( $average_hit_pros / $named_evidence_count, 4, 1 );
		$average_hit_cons =
		  format_decimal( $average_hit_cons / $named_evidence_count, 4, 1 );
	}
	my $average_hit_confidence =
	  format_decimal(
		$average_hit_pros / ( $average_hit_pros + $average_hit_cons ),
		1, 3 );

	if ($dbg) {
		print
"\nweighted keywords: total hits $evidence_count  named hits $named_evidence_count  "
		  . "average: $average_hit_pros - $average_hit_cons ($average_hit_confidence)\n";
	}

	my $minweights = 3;
	for my $keyword ( sort { $a cmp $b } keys %{ $$keywords{hitlist} } ) {
		my $wordwgt = $$keywords{keywgt}{$keyword};
		if ( $dbg ) {
			print "keyword=$keyword  wiordwgt=$wordwgt\n";
		}
		my @weights;
		if ( $dbg ) {
			print "HITS\n";
			printVerboseEvidenceHdr();
		}
		for my $hit ( values %{ $$keywords{hitlist}{$keyword} } ) {
			my %weight;
			$weight{hit}        = $hit;
			$weight{pros}       = $$hit{pros};
			$weight{cons}       = $$hit{cons};
			$weight{confidence} = $$hit{confidence};
			$weight{extended}   = "";
			push @weights, \%weight;
			if ( $dbg ) {
				printVerboseEvidenceItem($hit);
				print "HIT pros $weight{pros}  cons $weight{cons}\n";
			}
		}
		my $keyhits = @weights;

		# award bonus hits to prevent poor hit from overcoming trusted hit
		my @bonuses;
		if ( $dbg ) {
			print "TRUSTED\n";
			printVerboseEvidenceHdr();
		}
		for my $wgt (@weights) {
			my $hit = $$wgt{hit};
			if ( ( defined $$hit{trusted_cutoff} && $$hit{total_score} >= $$hit{trusted_cutoff} ) ||
					( index( $trusted_list, ",$$hit{job_name}," ) >= 0 && $$hit{pros} >= $$hit{cons} ) ||
					$$hit{job_name} eq "TMHMM" ) {
				my $pros = $$hit{pros};
				my $cons = $$hit{cons};
				for my $i ( 2 .. $minweights ) {
					my $bonus;
					$$bonus{pros}       = $pros;
					$$bonus{cons}       = $cons;
					$$bonus{confidence} = $$hit{confidence};
					$$bonus{extended}   = "+";
					push @bonuses, $bonus;
					if ( $dbg ) {
						printVerboseEvidenceItem($hit);
						print "TRUSTED pros $$bonus{pros}  cons $$bonus{cons}\n";
					}
				}
			}
		}
		push @weights, @bonuses;

		# bring to minimum number of hits with filler hits
		# (filler hit = last hit x penalty );
		@weights = sort { compare_pros_and_cons( $a, $b ) } @weights;
		while ( @weights < $minweights ) {
			my $new;
			my $pct = 0.8 * $weights[ @weights - 1 ]{confidence};
			my $games = 0.625 * ( $weights[ @weights - 1 ]{pros} +
				  $weights[ @weights - 1 ]{cons} );
			$$new{pros}       = $pct * $games;
			$$new{cons}       = $games - $$new{pros};
			$$new{confidence} = $$new{pros} / ( $$new{pros} + $$new{cons} );
			$$new{extended}   = "-";
			push @weights, $new;
			if ( $dbg ) {
				print "FILLER pros $$new{pros}  cons $$new{cons}\n";
			}
		}

		# add bonus hit for common keywords
		my $freq = ( $keyhits + 3.5 ) / ( $named_evidence_count + 9 );
		if ( $freq >= $floor ) {
			my $new;
			my $games = 20.0;
			$$new{pros}       = $freq * $games;
			$$new{cons}       = $games - $$new{pros};
			$$new{confidence} = $$new{pros} / ( $$new{pros} + $$new{cons} );
			$$new{extended}   = "*";
			push @weights, $new;
			if ( $dbg ) {
				print "FREQUENT pros $$new{pros}  cons $$new{cons}\n";
			}
		}

		# don't allow scores below baseline
		for my $i ( 0 .. @weights - 1 ) {
			my $pros    = $weights[$i]{pros};
			my $cons    = $weights[$i]{cons};
			my $maxcons = $pros / $floor - $pros;
			if ( $cons > $maxcons ) {
				$weights[$i]{cons}       = $maxcons;
				$weights[$i]{confidence} = $weights[$i]{pros} /
				  ( $weights[$i]{pros} + $weights[$i]{cons} );
				if ( $dbg ) {
					print "FLOOR $pros - $cons =>  $weights[$i]{pros} -  $weights[$i]{cons}\n";
				}
			}
		}

		# score keyword
		if ($dbg) {
			my $w = format_decimal( $wordwgt, 1, 2 );
			my $f = int( 100.0 * $freq + 0.5 );
			print "  $keyword ($w W) in $keyhits of $evidence_count ($named_evidence_count named, $f%) hits:";
		}

		@weights = sort { compare_pros_and_cons( $a, $b ) } @weights;
		my $pros     = 0;
		my $cons     = 0;
		my $scale    = 1.0;
		my $totscale = 0;
		for my $i ( 0 .. $minweights - 1 ) {
			if ($dbg) {
				my $w = int( 10.0 * $weights[$i]{pros} + 0.5 ) / 10.0;
				my $l = int( 10.0 * $weights[$i]{cons} + 0.5 ) / 10.0;
				print "  $i. $w-$l$weights[$i]{extended}";
			}
			my $w = $scale * sqrt( $weights[$i]{pros} );
			my $l = $scale * sqrt( $weights[$i]{cons} );
#			if ( $w < $l ) {
#				$w = 0.5 * $w;
#				$l = 0.5 * $l;
#			}
			$pros += $w;
			$cons += $l;
			$totscale += $scale;
			$scale = $decay * $scale;
		}
		$pros = sqr( $pros / $totscale );
		$cons = sqr( $cons / $totscale );

		# save score
		$$keywords{wordwgt}{$keyword}    = $wordwgt;
		$$keywords{pros}{$keyword}       = $pros;
		$$keywords{cons}{$keyword}       = $cons;
		$$keywords{confidence}{$keyword} = $pros / ( $pros + $cons );
		if ($dbg) {
			my $p = int( 10.0 * $$keywords{pros}{$keyword} + 0.5 ) / 10.0;
			if ( $p !~ /\./ ) { $p .= ".0" }
			my $c = int( 10.0 * $$keywords{cons}{$keyword} + 0.5 ) / 10.0;
			if ( $c !~ /\./ ) { $c .= ".0" }
			print " = $p-$c ($$keywords{confidence}{$keyword})\n";
		}
	}
	if ($dbg) {
		print "\n";
	}
}

sub score_names {
	my ( $names, $keyweights ) = @_;

	for my $name ( values %$names ) {
		score_name( $name, $keyweights );

		#print "\nname: $$name{text}\n";
	}

}

sub score_name {
	my ( $name, $keyweights ) = @_;
	my $dbg = 0;
	my $method  = "method1";
	my $pros    = 0.001;
	my $cons    = 0.001;
	my $namewgt = 0.001;
	if ( $dbg ) { print "name=$$name{text}\n" }
	{

		# sum keyword scores
		my %used;
		my $totwgt = 0.0;
		for my $pos ( sort { $a <=> $b } keys %{ $$name{keywords}{position} } )
		{
			my $keyword = $$name{keywords}{position}{$pos};

			# skip redundant keywords
			if ( exists $used{$keyword} ) { next }
				
			if ( exists $$keyweights{pros}{$keyword} ) {
				$pros += $$keyweights{pros}{$keyword} *
				  $$keyweights{wordwgt}{$keyword};
				$cons += $$keyweights{cons}{$keyword} *
				  $$keyweights{wordwgt}{$keyword};
				$namewgt += $$keyweights{wordwgt}{$keyword};
			}
			$used{$keyword} = $pos;
			if ( $dbg ) {
				my $p = format_decimal( $$keyweights{pros}{$keyword}, 4, 1 );
				my $c = format_decimal( $$keyweights{cons}{$keyword}, 4, 1 );
				my $w = format_decimal( $$keyweights{wordwgt}{$keyword}, 2, 1 );
				my $pr = format_decimal( $pros, 4, 1 );
				my $co = format_decimal( $cons, 4, 1 );
				print "  $keyword $w x $p-$c = $pr-$co\n";
			}
		}
	}

	# convert to average per keyword and calculate confidence;
#	if ( $namewgt > 1.0 ) {
#		$pros = $pros / $namewgt;
#		$cons = $cons / $namewgt;
#		if ( $dbg ) {
#			my $pr = format_decimal( $pros, 4, 1 );
#			my $co = format_decimal( $cons, 4, 1 );
#			print "  adjusted: $pr-$co\n";
#		}
#	}
	if ( $namewgt > 0.0 ) {
		my $nw = maxval( 0.75, $namewgt );
		$nw = sqrt( $nw );
		$pros = $pros / $nw;
		$cons = $cons / $nw;
		if ( $dbg ) {
			my $pr = format_decimal( $pros, 4, 1 );
			my $co = format_decimal( $cons, 4, 1 );
			print "  adjusted: $pr-$co\n";
		}
	}
	my $confidence = $pros / ( $pros + $cons );

	# initialize level of detail
	my $details = $namewgt;
	if ( $details <= 1.0 ) {
		$details = 0;
	}
	else {
		$details = sqrt($details) - 1.0;
	}

	# assess penalties for undesirable features in name
	# penalize redundancy
	my $penalty = 1.0;
	{
		my $unqwgt = 0.0;
		my $totwgt = 0.001;
		my %used;
		for my $pos ( sort { $a <=> $b } keys %{ $$name{keywords}{position} } )
		{
			my $keyword  = $$name{keywords}{position}{$pos};
			if ( ! exists $$keyweights{pros}{$keyword} ) { next }
			my $unqscale = 1;
			if ( exists $used{$keyword} ) {
				for my $i ( 1 .. $used{$keyword} ) {
					$unqscale = 0.9 * $unqscale;
				}
			}
			$used{$keyword}++;
			$unqwgt += $unqscale * $$keyweights{wordwgt}{$keyword};
			$totwgt += $$keyweights{wordwgt}{$keyword};
		}
		my $redundancy = sqrt( $unqwgt / $totwgt );
		$penalty = $penalty * $redundancy;

		if ( $dbg ) { print "  redundancy: $redundancy\n" }
	}

	# penalize weak names
	my $testtext = $$name{text};
	my $testnorm = normalize_name( $testtext, 2 );
	$testnorm =~ s/\b.FAM//gi;
	if ( $dbg ) {
		print "name $testtext\n";
		print "norm $testnorm\n";
	}

    # desirable words
    if ( $testtext =~ /\b(genes*|cDNA|ESTs*|predicted|conserved|$unknowns)\b/i ) {
		$penalty = 0.01 * $penalty;
		$details = 0;
		if ( $verbose ) { print "penalizing $testtext 99% (\"$1\")\n" }
	}
	
	# long names
	elsif ( length( $testtext ) > 80 ) {
		my $factor = 40.0 / ( length( $testtext ) - 40.0 );
		$penalty = $factor * $penalty;
		$factor = int( 100.0 - 100.0 * $factor );
		if ( $verbose ) { print "penalizing $testtext $factor% (too long)\n" }
	}

	# short names
	elsif ( length( $testnorm ) < 6 ) {
		my $factor = ( length( $testnorm ) + 10.0 ) / 18.0;
		$penalty = $factor * $penalty;
		$factor = int( 100.0 - 100.0 * $factor );
		if ( $verbose ) { print "penalizing $testtext $factor% (too short)\n" }
	}

	# low content
	elsif ( $testtext =~ /\b(DUF|UPF)[0-9]+\b/i ) {
		$penalty = 0.25 * $penalty;
		if ( $verbose ) { print "penalizing $testtext 75% (DUF/UPF)\n" }
	}
	elsif ( $testtext =~ /^[^ ]+([- ]*(repeat|rich))+([-, ]*(protein|like|related|putative))*$/i ) {
		$penalty = 0.50 * $penalty;
		if ( $verbose ) { print "penalizing $testtext 50% (low content)\n" }
	}
	elsif ( $testnorm !~ /[a-z]{3}/ && $testnorm !~ /[-a-z0-9]{4}/ && length( $testnorm ) < 6 ) {
		$penalty = 0.75 * $penalty;
		if ( $verbose ) { print "penalizing $testtext 25% (low content)\n" }
	}
	elsif ( $testnorm !~ /[a-z]{4,}/ && $testnorm !~ /[-a-z0-9]{5}/ && length( $testnorm ) < 8 ) {
		$penalty = 0.85 * $penalty;
		if ( $verbose ) { print "penalizing $testtext 15% (low content)\n" }
	}
	# artificial word
	if ( $testtext =~ /_/i ) {
		$penalty = 0.95 * $penalty;
		if ( $dbg ) { print "  artificial: $penalty\n" }
	}
	# prefer without "containing"
	if ( $testtext =~ /containing/i ) {
		$penalty = 0.995 * $penalty;
		if ( $dbg ) { print "  containing: $penalty\n" }
	}
	# prefer without "expressed"
	if ( $testtext =~ /expressed/i ) {
		$penalty = 0.995 * $penalty;
		if ( $dbg ) { print "  expressed: $penalty\n" }
	}
	# prefer without "putative"
	if ( $testtext =~ /putative/i ) {
		$penalty = 0.995 * $penalty;
		if ( $dbg ) { print "  putative: $penalty\n" }
	}
	# prefer mixed-case
	if ( $testtext eq uc( $testtext ) || $testtext eq lc( $testtext ) ) {
		$penalty = 0.999 * $penalty;
		if ( $dbg ) { print "  mixedcase: $penalty\n" }
	}
	# prefer without "like" or "related""
	if ( $testtext =~ /\b(related|like) protein$/i ) {
		$penalty = 0.999 * $penalty;
		if ( $dbg ) { print "  like: $penalty\n" }
	}
	# prefer without "domain" or "family""
	if  ( $testtext =~ /\b($domains|[a-z]*family)\b/i ) {
		$penalty = 0.999 * $penalty;
		$details -= 0.15;
		if ( $dbg ) { print "  family: $penalty\n" }
	}

	# apply penalties
	if ( $pros >= $cons ) {
		$pros = $penalty * $pros;
		$cons = $penalty * $cons;
	}

	# calculate detail level and cost
	# (extra details require higher confidence)
	if ( $details < 0 ) { $details = 0 }
	my $points = 1;
	my $cost   = 0.600;
	my $d      = 0.0;
	while ( $d + 0.1 <= $details ) {
		$cost += 0.600 * exp( 0.15 * ( $d + 0.5 ) );
		$d += 0.1;
		$points++;
	}
	if ( $d < $details ) {
		$cost += 0.600 * exp( 0.15 * ( $details - $d ) );
		$points++;
	}
	$cost = $cost / $points;

	if ( $cost > $confidence ) {
		my $discount = sqrt( $confidence / $cost );
		$pros = $pros * $discount;
		$cons = $cons * $discount;
	}

	# save data
	$$name{method}       = $method;
	$$name{pros}         = $pros;
	$$name{cons}         = $cons;
	$$name{wordwgt}      = $namewgt;
	$$name{detail_level} = $details;
	$$name{detail_cost}  = $cost;
	$$name{penalty}      = $penalty;
	$$name{confidence}   = $confidence;

}

sub find_consensus_name {
	my ( $names, $keyweights, $consensus_threshold ) = @_;
	my $dbg = 0;

	# determine threshold pros-cons for considering a name
	# (top score minus discount)
	my @candidates;
	my %passed;
	{
		my @tmp = sort { $$b{pros}-$$b{cons} <=> $$a{pros}-$$a{cons} } values %$names;
		my $threshold;
		my $allow_weak = 0;
		while ( ! defined $threshold && ! $allow_weak ) {
			for my $name ( @tmp ) {
				if ( ! $allow_weak && flag_weak_name( $$name{text} ) ) { next }
				if ( ! defined $threshold && $$name{cnt} > 0 && $$name{pros} >= $$name{cons} ) {
					$threshold = $$name{pros} - $$name{cons};
					last;
				}
			}
			if ( ! defined $threshold ) { $allow_weak = 1 }
		}
		if ( ! defined $threshold ) {
			@candidates = sort { compare_consensus( $a, $b ) } values %$names;
			return \@candidates;
		}

		$threshold = int( 10.0 * $threshold * $consensus_threshold ) / 10.0;
		if ( $threshold < 20 ) {
			my $threshold2 = maxval( 0, $threshold - 8 );
			if ( $threshold2 < $threshold ) { $threshold = $threshold2 }
		}
		if ($verbose) { print "\nconsensus threshold $threshold\n" }

		# collect names meeeting or exceeding threshold
		for my $name (@tmp) {
			my $flag = flag_weak_name( $$name{text} ) ;
			if ( ! $allow_weak && $flag) {
				if ( $verbose ) { print "skipping weak name: $$name{text} ($flag)\n" }
				next;
			}
			
			if ( $$name{cnt} > 0 && $$name{pros} - $$name{cons} >= $threshold ) {
				$passed{$$name{text}} = $name;

				# generate less specific permutations of name by trimming end
				my $child = $$name{text};
				my $parent = parent_protein_name( $child );
#print " child: $child\nparent: $parent\n";
				while ( $child ne $parent ) {
					if ( ! exists $passed{$parent} ) {
						my %name2 = %$name;
						$name2{original} = $child;
						$name2{text}     = $parent;
						$name2{keywords} = get_keywords( $parent, 1 );
						$name2{pros} = 0.99 * $name2{pros};
						$name2{cons} = 0.99 * $name2{cons};
						$name2{cnt}      = 0;
						$name2{cnt500}   = 0;
						$name2{good}     = 0;
						$name2{demoted}  = 0;

if ( $dbg ) { print "      score $parent\n" }
						score_name( \%name2, $keyweights );

						$passed{$parent} = \%name2;
						for my $hit_id ( keys %{ $$name{hitlist} } ) {
							$passed{$parent}{hitlist}{$hit_id} = $$name{hitlist}{$hit_id};
						}
					}
					$child = $parent;
					$parent = parent_protein_name( $child );
#print " child: $child\nparent: $parent\n";
				}
			}
		}
if ( $dbg ) { print "\n" }
	
		@candidates = values %passed;
	}

	# weight names based on number of occurences and number of good hits
	my $candiwgt = 0;
	my $candicnt = 0;
	my %candikeys;
	for my $name ( @candidates) {
		$$name{weight} = sqrt( ( $$name{cnt} + $$name{cnt500} + $$name{good} ) / 3.0 );

		$candiwgt += $$name{weight} * ( 16 + $$name{pros} - $$name{cons} );
		$candicnt += $$name{weight};

		if ($verbose) {
			my $ns = format_decimal( $$name{pros} - $$name{cons}, 4, 1 );
			my $weight = format_decimal( $$name{weight}, 2, 2 );
			print "  $$name{text}  $ns  weighted $weight\n";
		}
	}
	if ( $candicnt == 0 ) {
		@candidates = sort { compare_consensus( $a, $b ) } values %$names;
		return \@candidates;
		
	}

	# calculate break-even point for keyword scores
	my $breakeven;
	if ( $candicnt >= 20.0 ) {
		$breakeven = 2.0/7.0 * $candiwgt + 0.01;

		if ( $dbg ) { print "\nCNT: $candicnt  breakeven: $breakeven (2/7)\n" }
	}
	elsif ( $candicnt >= 10.0 ) {
		$breakeven = 2.0/6.0 * $candiwgt + 0.01;

		if ( $dbg ) { print "\nCNT: $candicnt  breakeven: $breakeven (2/6)\n" }
	}
	elsif ( $candicnt >= 5.0 ) {
		$breakeven = 2.0/5.0 * $candiwgt + 0.01;

		if ( $dbg ) { print "\nCNT: $candicnt  breakeven: $breakeven (2/5)\n" }
	}
	else {
		$breakeven = 2.0/4.0 * $candiwgt + 0.01;

		if ( $dbg ) { print "\nCNT: $candicnt  breakeven: $breakeven (2/4)\n" }
	}
	if ( $verbose ) {
		my $tw = int( 10.0 * $candicnt + 0.5 ) / 10.0;
		my $be = int( 10.0 * $candicnt * $breakeven / $candiwgt + 0.5 ) / 10.0;
		print "\n  total weight: $tw, break-even point: ~$be\n";
	}

	# calculate marginal values of keywords
	# (value above/below break-even point)
	for my $name (@candidates) {
		my $namescore = $$name{weight} * ( 16 + $$name{pros} - $$name{cons} );
		my $keywords = get_keywords( $$name{text}, 1 );
if ( $dbg ) { print "\n$$name{text}  $namescore = $$name{weight} * ( $$name{pros} - $$name{cons} )\n" }
		for my $kw ( keys %{ $$keywords{keywgt} } ) {
			$candikeys{$kw}{rawscore} += $namescore;
if ( $dbg ) { print "  $kw + $namescore = $candikeys{$kw}{rawscore}\n" }
		}
	}

	for my $kw ( sort { $a cmp $b } keys %candikeys ) {
		my $kwgt = 0.5;
		if ( exists $$keyweights{wordwgt}{$kw} ) { $kwgt = $$keyweights{wordwgt}{$kw} }
		$candikeys{$kw}{score} =
		  ( $candikeys{$kw}{rawscore} - $breakeven ) * $kwgt;

if ( $dbg ) { print "$kw $candikeys{$kw}{score} = ( $candikeys{$kw}{rawscore} - $breakeven ) * $$keyweights{wordwgt}{$kw}\n" }
	}

	# calculate consensus score for name as sum of marginal values of keywords
	for my $name (@candidates) {
if ( $dbg ) { print "\n$$name{text}\n" }
		my $consensus = 0;
		my $keywords = get_keywords( $$name{text}, 1 );
		for my $kw ( sort { $a cmp $b } keys %{ $$keywords{keywgt} } ) {
			if ( exists $candikeys{$kw} ) {
				$consensus += $candikeys{$kw}{score};
if ( $dbg ) { print "  $kw  $candikeys{$kw}{score} = $consensus\n" }
			}
		}
		$$name{consensus} = $consensus;
if ( $dbg ) { print "  final consensus = $$name{consensus} = $consensus\n" }
	}

	@candidates = sort { compare_consensus( $a, $b ) } @candidates;
	if ( $candidates[0]{consensus} < 0 ) {
		@candidates = sort { compare_pros_and_cons( $a, $b ) } @candidates;
	}
	for my $name ( sort { compare_pros_and_cons( $a, $b ) } values %$names ) {
		if ( $$name{cnt} > 0 && ! exists $passed{ $$name{text} } ) {
			$passed{$$name{text}} = $name;
			push @candidates, $name;
		}
	}
	return \@candidates;
}

sub compare_consensus {
	my ( $a, $b ) = @_;

	if ( defined $$a{consensus} && ! defined $$b{consensus} ) {
		return -1;
	}
	elsif ( ! defined $$a{consensus} && defined $$b{consensus} ) {
		return 1;
	}
	elsif ( defined $$a{consensus} && defined $$b{consensus} ) {
		if ( $$a{consensus} > $$b{consensus} ) {
			return -1;
		}
		elsif ( $$a{consensus} < $$b{consensus} ) {
			return 1;
		}
	}

	if ( defined $$a{weight} && ! defined $$b{weight} ) {
		return -1;
	}
	elsif ( ! defined $$a{weight} && defined $$b{weight} ) {
		return 1;
	}
	elsif ( defined $$a{weight} && defined $$b{weight} ) {
		if ( $$a{weight} > $$b{weight} ) {
			return -1;
		}
		elsif ( $$a{weight} < $$b{weight} ) {
			return 1;
		}
	}

	if ( $$a{pros}-$$a{cons} > $$b{pros}-$$b{cons} ) {
		return -1;
	}
	elsif ( $$a{pros}-$$a{cons} < $$b{pros}-$$b{cons} ) {
		return 1;
	}

	if ( $$a{penalty} > $$b{penalty} ) {
		return -1;
	}
	elsif ( $$a{penalty} < $$b{penalty} ) {
		return 1;
	}

	if ( length( $$a{text} ) < length( $$b{text} ) ) {
		return -1;
	}
	elsif ( length( $$a{text} ) > length( $$b{text} ) ) {
		return 1;
	}

	if ( reverse $$a{text} lt reverse $$b{text} ) {
		return -1;
	}
	elsif ( reverse $$a{text} gt reverse $$b{text} ) {
		return 1;
	}

	return 0;
}

sub display_names {
	my ($list) = @_;

	print "  "
	  . lpad( "pros",    6 ) . " "
	  . lpad( "cons",    6 ) . " "
	  . lpad( "net",     6 ) . " "
	  . lpad( "conf",    6 ) . " "
	  . lpad( "penalty", 7 ) . " "
	  . lpad( "Words",   5 ) . " "
	  . lpad( "Detl",    4 ) . " "
	  . lpad( "Dcost",   6 ) . " "
	  . lpad( "weight",  6 ) . " "
	  . lpad( "score",   7 ) . " "
	  . lpad( "cnt",     3 ) . " "
	  . lpad( "dem",     3 ) . " "
	  . " name\n";

	if ( !defined $list ) { return }

	for my $name (@$list) {
		my $pros    = format_decimal( $$name{pros},                4, 1 );
		my $cons    = format_decimal( $$name{cons},                4, 1 );
		my $net     = format_decimal( $$name{pros} - $$name{cons}, 4, 1 );
		my $conf    = format_decimal( $$name{confidence},          2, 3 );
		my $penalty = format_decimal( $$name{penalty},             3, 3 );
		my $words   = format_decimal( $$name{wordwgt},             3, 1 );
		my $detl    = format_decimal( $$name{detail_level},        2, 1 );
		my $dcost   = format_decimal( $$name{detail_cost},         2, 3 );

		my $weight = lpad( "- ", 6 );
		if ( defined $$name{weight} ) {
			$weight = format_decimal( $$name{weight}, 4, 1 );
		}

		my $score = lpad( "- ", 7 );
		if ( defined $$name{consensus} ) {
			$score = format_decimal( $$name{consensus}, 5, 1 );
		}
		
		my $cnt = lpad( $$name{cnt}, 3 );
		my $dem = lpad( $$name{demoted}, 3 );

		print "  $pros $cons $net $conf $penalty $words $detl $dcost $weight $score $cnt $dem $$name{text}\n";
		if ( lc( $$name{text} ) ne lc( $$name{orig} ) ) {
			print lpad( "(", 80 ) . $$name{orig} . ")\n";
		} 
	}
}

sub output_best_name {
	my ( $afh, $seq_acc, $consensus, $besthit ) = @_;

	my @evidences;
	{
		my %evidences;
		for my $name (@$consensus) {
			for my $hit ( values %{ $$name{hitlist} } ) {

				for my $defline ( @{ $$hit{deflines} } ) {
					my $evidence_id = $$hit{job_name} ;
					if ( $evidence_id ne "TMHMM" ) { $evidence_id .= "|$$defline{id}" }
					my $evidence;
					$$evidence{id} = $evidence_id;
					$$evidence{defline} = $defline;
					$$evidence{hit} = $hit;
					$evidences{$evidence_id} = $evidence;
				}
			}
		}
		@evidences = sort { compare_pros_and_cons( $$a{hit}, $$b{hit} ) } values %evidences;
	}

	# first pass - exclude GO
	# second pass - allow GO
	my $common_name;
	my $ref_evidence;
	for my $pass ( 1..2 ) {
#print "pass $pass\n";
		for my $name ( @$consensus ) {
#print "  name: $$name{text} ($$name{pros}-$$name{cons})\n";
			if ( $$name{pros} < $$name{cons} ) { next }
			$common_name = $name;
			for my $evidence ( sort { order_supporting_evidence( $a, $b ) } @evidences ) {
				if ( $pass < 2 && $$evidence{hit}{job_name} =~ /GO$/  ) { next }
#print "    $$evidence{hit}{job_name}: $$evidence{defline}{definition}\n";
				my $name1 = $$common_name{text};
				if ( defined $$common_name{original} ) { $name1 = $$common_name{original} }
				if ( does_name2_imply_name1( $name1, $$evidence{defline}{definition} ) > 0 ) {
					$ref_evidence = $evidence;
					last;
				}
			}
			if ( defined $ref_evidence ) { last }
		}
		if ( defined $ref_evidence ) { last }
	}

	if ( defined $common_name ) {
		my $confidence = $$common_name{confidence};
		my $cost       = $$common_name{detail_cost};

		$$common_name{text} =
		  check_details_versus_cost( $confidence, $cost, $$common_name{text} );

		$confidence = format_decimal( $confidence, 1, 3 );
		print $afh "$seq_acc\t$$common_name{text}\t$$ref_evidence{id}\t$confidence\t$$ref_evidence{defline}{original}\n";
		print "\n$seq_acc\t$$common_name{text}\t$$ref_evidence{id}\t$confidence\t$$ref_evidence{defline}{original}\n";
	}
	else {
		report_conserved_hypothetical_protein( $afh, $seq_acc, $besthit );
	}
}

sub order_supporting_evidence {
	my ( $a, $b ) = @_;

	my $ascore =  int ( $$a{pros} - $$a{cons} / 1.01 + 0.5 );
	my $bscore =  int ( $$b{pros} - $$b{cons} / 1.01 + 0.5 );
	
	if ( $ascore > $bscore ) { return -1 }
	if ( $ascore < $bscore ) { return 1 }
	
	$ascore = rank_job( $$a{hit}{job_name} );
	$bscore = rank_job( $$b{hit}{job_name} );

	if ( $ascore > $bscore ) { return -1 }
	if ( $ascore < $bscore ) { return 1 }
	return 0;
}

sub rank_job {
	my ( $job_name ) = @_;
	
	if ( index( $trusted_list, ",$job_name," ) >= 0 ) {
		return 4;
	}
	elsif ( $job_name eq "PRIAMRPS" ) {
		return 2;
	}
	elsif ( $job_name eq "TMHMM" ) {
		return 1;
	}
	elsif ( $job_name eq "GO" ) {
		return 0;
	}
	else {
		return 3;
	}
}

sub check_details_versus_cost {

	my ( $confidence, $cost, $name ) = @_;

	if ( $confidence < $cost ) {
		if ( $name !~
			/(putative|related|(para|ortho|homo)log[ousy]*|similar[ity]*)$/i )
		{
			$name .= ", putative";
		}
	}

	return $name;
}

sub formatGOhit {
	my ( $dbh, $row ) = @_;

	my %new = %$row;
	$new{job_name} = "HMMGO";
	$new{hit_id} = "$new{job_name}|$new{hmm_acc}";
	$new{trusted_cutoff} = undef;
	$new{trusted_score} = undef;
	$new{iso_type} = undef;
	$new{pros} = 0.5 * $new{pros};
	$new{cons} = 0.5 * $new{cons};
	
	my $go = querySQLArrayArray( $dbh, "select distinct go_term from hmm_go_link where hmm_acc=?", $$row{hmm_acc} );
	if ( defined $go && @$go ) {
		my @deflines;
		for my $gorow ( @$go ) {
			for my $name ( keys %{$goNames{$$gorow[0]}} ) {
				my %defline;
				$defline{id} = "$new{hmm_acc}|$$gorow[0]";
				$name =~ s/[;,: ]+(process|activity) *$//i;
				$defline{definition} = $name;
				$defline{original} = $defline{definition};
				push @deflines, \%defline;
			} 
		}

		$new{deflines} = \@deflines;
		return \%new;
	}
	else {
		return ();
	}
}
1;
