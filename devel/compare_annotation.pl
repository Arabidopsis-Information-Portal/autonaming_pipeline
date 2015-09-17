#!/usr/local/bin/perl

use strict;

my $file1 = $ARGV[0];
my $file2 = $ARGV[1];
my $sym_loci_file = $ARGV[2];
my $incon_file = $ARGV[3];
my $overide = $ARGV[4];

my %names_data;

open (FILE1, $file1) || die "Cannot open $file1. $!";

my %loci_seen;

while (<FILE1>) {
	chomp $_;

	my @line = split /\t/, $_;
	
	if ($line[1]) {
		$names_data{$line[0]}->{file1_name} = $line[1];
	} else {
		$names_data{$line[0]}->{file1_name} = "IN ARAPORT, NO ANNOTATION";
	}
	$names_data{$line[0]}->{provenance} = $line[2];
}
close FILE1;

open (FILE2, $file2) || die "Cannot open $file2. $!";

while (<FILE2>) {
	chomp $_;
	
	my @line = split /\t/, $_;
	if ($line[2]) {
		$names_data{$line[0]}->{file2_name} = $line[2];
	#} elsif ($line[4]) {
	#	my @compdesc = split /;/, $line[4]; #//
	#	# print "$compdesc[0]\n";
	#	$names_data{$line[0]}->{file2_name} = $compdesc[0];
	} else {
		$names_data{$line[0]}->{file2_name} = "IN TAIR, NO ANNOTATION";
	}
	if ($line[4]) {
		my @compdesc = split /;/, $line[4]; #//
		# print "$compdesc[0]\n";
		$names_data{$line[0]}->{comp_desc} = $compdesc[0];
	}
	if ($line[3]) {
		$names_data{$line[0]}->{cur_sum} = $line[3];
	}
	my $loci = &extract_loci($line[0]);
	$loci_seen{$loci} ++;
}
close FILE2;

my %syms;
open (FILE3, $sym_loci_file) || die "Cannot open $sym_loci_file. $!";
while (<FILE3>) {
	chomp $_;

	my @line = split /\t/, $_;

	push @{$syms{$line[0]}}, $line[1];
}
close FILE3;

my %incon;
open (FILE4, $incon_file) || die "Cannot open $incon_file. $!";
while (<FILE4>) {
	chomp $_;
	
	$incon{$_} ++;
}
close FILE4;

my %overide;
open (FILE5, $overide) || die "Cannot open $overide. $!";
while (<FILE5>) {
	chomp $_;
	
	my @line = split /\t/, $_;
	
	$overide{$line[0]}->{provenance} = $line[1];
	$overide{$line[0]}->{name} = $line[2];
}
close FILE5;

my %compare;

foreach my $id (sort keys %names_data) {
	my ($col1, $col2, $col3, $col4, $col5, $col6);
	$col1 = $id;
	if ($names_data{$id}->{file1_name}) {
		$col2 = $names_data{$id}->{file1_name};
		$col4 = $names_data{$id}->{provenance};
	}  else {
		$col2 = "NOT IN ARAPORT";
	}
	if ($names_data{$id}->{file2_name}) {
		$col3 = $names_data{$id}->{file2_name};
	}  else {
		$col3 = "NOT IN TAIR";
	}
	if ($names_data{$id}->{comp_desc}) {
		$col5 = $names_data{$id}->{comp_desc};
	}
	if ($names_data{$id}->{cur_sum}) {
		$col6 = $names_data{$id}->{cur_sum};
	}
	
	$compare{$col1}->{ARAPORT} = $col2;
	$compare{$col1}->{TAIR} = $col3;
	$compare{$col1}->{provenance} = $col4;
	$compare{$col1}->{comp_desc} = $col5;
	$compare{$col1}->{cur_sum} = $col6;
}

my @order = ("ISOFORM_NOT_IN_ARAPORT","LOCI_NOT_IN_TAIR","ISOFORM_NOT_IN_TAIR","ISOFORM_INCONSISTENT_NAMES","ISOFORM_MATCH","TAIR_DUF_PROTEIN","TAIR_GENE_SYM_PRESENT","COMP_DESC_EQUIVALENT","CURATOR_SUMMARY","ISOFORM_ANNOTATION_MISMATCH","HYPO_EQUIVALENT","TAIR_UNKNOWN_TO_ARAPORT_NAME","ARAPORT_HYPO_TAIR_KNOWN","IN_TAIR_NO_ANNOTATION","IN_ARAPORT_NO_ANNOTATION");
my %fh;
foreach my $stat (@order) {
	my $file = "$stat.tsv";
	open ($fh{$stat}, ">$file") || die "cannot open $file. $!\n";
}

my $header = "ID\tJCVI Name\tTAIR10 Name\tCOMP DESC\tGene Symbols\tProvenance\t" .join ("\t",@order);

my %stats;
my %seen;
my %loci_comp;

my $comp_file = "ISOFORM_ANNOTATION_COMPARISON.tsv";
open (COMP, ">$comp_file") || die "Cannot open $comp_file. $!\n";
print COMP "$header\n";

foreach my $id (sort keys %compare) {
	my $loci = &extract_loci($id);
	
	my $category = &assign_category($id);

	my $cats_text;
	my $syms_text;
	foreach my $cat (@order) {
		my $fh = $fh{$cat};
		if ($$category{$cat}) {
			print $fh "$id\t$compare{$id}->{ARAPORT}\t$compare{$id}->{TAIR}\t$compare{$id}->{provenance}\n";
		}
		$cats_text .= "\t$$category{$cat}";
		if ($$category{$cat} eq "TAIR_GENE_SYM_PRESENT") {
			$syms_text = join(",",@{$syms{$loci}});
		}
	}
	if (!$$category{"ISOFORM_NOT_IN_ARAPORT"}) {
		print COMP "$id\t$compare{$id}->{ARAPORT}\t$compare{$id}->{TAIR}\t$compare{$id}->{comp_desc}\t$syms_text\t$compare{$id}->{provenance}$cats_text\n";
		foreach my $cat (@order) {
			$loci_comp{$loci}->{$$category{$cat}} = $$category{$cat};
		}
		unless ($compare{$id}->{ARAPORT} eq "NOT IN ARAPORT") {
			$loci_comp{$loci}->{ARAPORT} = $compare{$id}->{ARAPORT};
			$loci_comp{$loci}->{araport_count} ++;
		}
		if (!($compare{$id}->{TAIR} eq "IN TAIR, NO ANNOTATION" || $compare{$id}->{TAIR} eq "NOT IN TAIR")) {
			$loci_comp{$loci}->{TAIR} = $compare{$id}->{TAIR};
			$loci_comp{$loci}->{tair_count} ++;
		}
		if ($compare{$id}->{TAIR} eq "IN TAIR, NO ANNOTATION") {
			$loci_comp{$loci}->{tair_count} ++;
		}
		if ($compare{$id}->{comp_desc}) {
			$loci_comp{$loci}->{COMP_DESC} = "COMP_DESC";
		}
		$loci_comp{$loci}->{loci_syms} = $syms_text;

		push @{$loci_comp{$loci}->{provenance}}, $compare{$id}->{provenance};
		$stats{ISOFORM_TOTAL} ++;
	}	
}
close COMP;

my $header = "ID\tJCVI Name\tTAIR10 Name\tCOMP DESC\tGene Symbols\tProvenance\tARAPORT ISO COUNT\tTAIR ISO COUNT\tCOMP ASSIGNMENT\tFINAL ASSIGNMENT\tRULE\t" .join ("\t",@order);

my $comp_file = "LOCI_ANNOTATION_COMPARISON.tsv";
open (COMP, ">$comp_file") || die "Cannot open $comp_file. $!\n";
print COMP "$header\n";

my %rule_count;

foreach my $loci (sort keys %loci_comp) {
	my $cats_text;
	my $pro_text;
	&auto_assign($loci);
	foreach my $cat (@order) {
		$cats_text .= "\t$loci_comp{$loci}->{$cat}";
	}
	if ($loci_comp{$loci}->{provenance}) {
		$pro_text = join(",",@{$loci_comp{$loci}->{provenance}});
	}
	print COMP "$loci\t$loci_comp{$loci}->{ARAPORT}\t$loci_comp{$loci}->{TAIR}\t$loci_comp{$loci}->{COMP_DESC}\t$loci_comp{$loci}->{loci_syms}\t$pro_text\t$loci_comp{$loci}->{araport_count}\t$loci_comp{$loci}->{tair_count}\t$loci_comp{$loci}->{AUTO_ASSIGN}\t$loci_comp{$loci}->{FINAL}\t$loci_comp{$loci}->{RULE}$cats_text\n";
	$stats{LOCI_TOTAL} ++;
}

close COMP;

my $total;
foreach my $stat (@order) {
	print "$stat => $stats{$stat}\n";
	
	$total += $stats{$stat};
}
print "ISOFORM TOTAL => $stats{ISOFORM_TOTAL}\n";
print "LOCI TOTAL => $stats{LOCI_TOTAL}\n";
print "AUTO ASSIGNED: JCVI => $stats{assigned_jcvi}\n";
foreach my $rule ("NO_TAIR_RULE","DUF_RULE","OVERRIDE_TO_JCVI_RULE","TAIR_UNKNOWN_RULE","NEW_LOCI_RULE") {
	print "               	$rule => $rule_count{$rule}\n";
}
print "               TAIR => $stats{assigned_tair}\n";
foreach my $rule ("MATCH_RULE","MISMATCH_RULE","HYPOTHETICAL_RULE","OVERRIDE_TO_TAIR_RULE","GENE_SYM_CURATOR_RULE","JCVI_HYPOTHETICAL_RULE") {
	print "               	$rule => $rule_count{$rule}\n";
}
print "               NONE => $stats{assigned_none}\n";
foreach my $rule ("BEST_PRO_RULE","DEFAULT_RULE") {
	print "               	$rule => $rule_count{$rule}\n";
}


sub assign_category {
	my $id = shift;	
	my $loci = &extract_loci($id);
	
	my %category;
	
	if ($compare{$id}->{ARAPORT} eq "NOT IN ARAPORT") {
		$category{"ISOFORM_NOT_IN_ARAPORT"} = "ISOFORM_NOT_IN_ARAPORT";
	}
	if ($incon{$loci}) {
		$category{"ISOFORM_INCONSISTENT_NAMES"} = "ISOFORM_INCONSISTENT_NAMES";
	}
	if ($compare{$id}->{TAIR} eq "NOT IN TAIR" && !$loci_seen{$loci}) {
		 $category{"LOCI_NOT_IN_TAIR"} = "LOCI_NOT_IN_TAIR";
	}
	if ($compare{$id}->{TAIR} eq "NOT IN TAIR") {
		 $category{"ISOFORM_NOT_IN_TAIR"} = "ISOFORM_NOT_IN_TAIR";
	}
	if (lc $compare{$id}->{ARAPORT} eq lc $compare{$id}->{TAIR}) {
		$category{"ISOFORM_MATCH"} = "ISOFORM_MATCH";
	}
	if ($syms{$loci}) {
		$category{"TAIR_GENE_SYM_PRESENT"} = "TAIR_GENE_SYM_PRESENT";
	}
	if (!($compare{$id}->{TAIR} =~ /conserved peptide upstream open reading frame/i || $compare{$id}->{TAIR} =~ /unknown protein/i || $compare{$id}->{TAIR} =~ /of unknown function/i || $compare{$id}->{TAIR} =~ /function unknown/i || $compare{$id}->{TAIR} =~ /Uncharacteri[zs]ed conserved protein/i) && $compare{$id}->{ARAPORT} !~ /hypothetical protein/i && $compare{$id}->{TAIR} !~ /IN TAIR/ && $compare{$id}->{ARAPORT} !~ /IN ARAPORT,/ && lc $compare{$id}->{TAIR} ne lc $compare{$id}->{ARAPORT} ) {
		$category{"ISOFORM_ANNOTATION_MISMATCH"} = "ISOFORM_ANNOTATION_MISMATCH";
	}
	if (($compare{$id}->{TAIR} =~ /conserved peptide upstream open reading frame/i || $compare{$id}->{TAIR} =~ /unknown protein/i || $compare{$id}->{TAIR} =~ /of unknown function/i || $compare{$id}->{TAIR} =~ /function unknown/i || $compare{$id}->{TAIR} =~ /Uncharacteri[zs]ed conserved protein/i) && $compare{$id}->{ARAPORT} =~ /hypothetical protein/) {
		$category{"HYPO_EQUIVALENT"} = "HYPO_EQUIVALENT";
	}
	if (($compare{$id}->{TAIR} =~ /conserved peptide upstream open reading frame/i || $compare{$id}->{TAIR} =~ /unknown protein/i || $compare{$id}->{TAIR} =~ /of unknown function/i || $compare{$id}->{TAIR} =~ /function unknown/i || $compare{$id}->{TAIR} =~ /Uncharacteri[zs]ed conserved protein/i || $compare{$id}->{comp_desc} =~ /unknown/i) && $compare{$id}->{ARAPORT} !~ /hypothetical protein/) {
		$category{"TAIR_UNKNOWN_TO_ARAPORT_NAME"} = "TAIR_UNKNOWN_TO_ARAPORT_NAME";
	}
	if (!($compare{$id}->{TAIR} =~ /conserved peptide upstream open reading frame/i || $compare{$id}->{TAIR} =~ /unknown protein/i || $compare{$id}->{TAIR} =~ /of unknown function/i || $compare{$id}->{TAIR} =~ /function unknown/i || $compare{$id}->{TAIR} =~ /Uncharacteri[zs]ed conserved protein/i || $compare{$id}->{TAIR} =~ /NOT IN TAIR/ || $compare{$id}->{TAIR} =~ /IN TAIR, NO ANNOTATION/) && $compare{$id}->{ARAPORT} =~ /hypothetical protein/) {
		$category{"ARAPORT_HYPO_TAIR_KNOWN"} = "ARAPORT_HYPO_TAIR_KNOWN";
	}
	if ($compare{$id}->{TAIR} eq "IN TAIR, NO ANNOTATION") { ## this set was contained in NOT IN ARAPORT set
		$category{"IN_TAIR_NO_ANNOTATION"} = "IN_TAIR_NO_ANNOTATION";
	}
	if ($compare{$id}->{ARAPORT} eq "IN ARAPORT, NO ANNOTATION") {
		$category{"IN_ARAPORT_NO_ANNOTATION"} = "IN_ARAPORT_NO_ANNOTATION";
	}
	if ($compare{$id}->{TAIR} =~ /duf[0-9]*/i || $compare{$id}->{TAIR} =~ /DOMAIN OF UNKNOWN FUNCTION/i) {
		$category{"TAIR_DUF_PROTEIN"} = "TAIR_DUF_PROTEIN";
	}
	if ($compare{$id}->{cur_sum}) {
		$category{"CURATOR_SUMMARY"} = "CURATOR_SUMMARY";
	}
	if ($compare{$id}->{TAIR} eq $compare{$id}->{comp_desc}) {
		$category{"COMP_DESC_EQUIVALENT"} = "COMP_DESC_EQUIVALENT";
	}
	foreach my $cat (keys %category) {
		unless ($category{"ISO_NOT_IN_ARAPORT"}) {
			$stats{$cat} ++;
		}
	}
	
	return \%category;	
}

sub auto_assign {
	my $loci = shift;
	
	if ($loci_comp{$loci}->{ISOFORM_MATCH}) { ## 1
		$loci_comp{$loci}->{AUTO_ASSIGN} = "TAIR";
		$loci_comp{$loci}->{FINAL} = $loci_comp{$loci}->{TAIR};
		$stats{assigned_tair} ++;
		$rule_count{MATCH_RULE} ++;
		$loci_comp{$loci}->{RULE} = "MATCH_RULE";
	} elsif ($overide{$loci}) { ## 2
		$loci_comp{$loci}->{AUTO_ASSIGN} = $overide{$loci}->{provenance};
		$loci_comp{$loci}->{FINAL} = $overide{$loci}->{name};
		if ($overide{$loci}->{provenance} eq "JCVI") {
			$stats{assigned_jcvi} ++;	
			$rule_count{OVERRIDE_TO_JCVI_RULE} ++;
			$loci_comp{$loci}->{RULE} = "OVERRIDE_TO_JCVI_RULE";
		} else {
			$stats{assigned_tair} ++;
			$rule_count{OVERRIDE_TO_TAIR_RULE} ++;
			$loci_comp{$loci}->{RULE} = "OVERRIDE_TO_TAIR_RULE";
		}
	} elsif ($loci_comp{$loci}->{ARAPORT} =~ /best protein/i) { ## 3
		$loci_comp{$loci}->{AUTO_ASSIGN} = "NONE";
		$stats{assigned_none} ++;
		$rule_count{BEST_PRO_RULE} ++;
		$loci_comp{$loci}->{RULE} = "BEST_PRO_RULE";
	} elsif ($loci_comp{$loci}->{TAIR_DUF_PROTEIN}) { ## 4
		$loci_comp{$loci}->{AUTO_ASSIGN} = "JCVI";
		my $name = $loci_comp{$loci}->{ARAPORT};
		my $duf = $loci_comp{$loci}->{TAIR};
		$duf =~ s/.*\(//;
		$duf =~ s/\).*//;
		$name .= " ($duf)";
		$loci_comp{$loci}->{FINAL} = $name;
		$stats{assigned_jcvi} ++;
		$rule_count{DUF_RULE} ++;
		$loci_comp{$loci}->{RULE} = "DUF_RULE";
	} elsif ($loci_comp{$loci}->{LOCI_NOT_IN_TAIR}) { ## 5
		$loci_comp{$loci}->{AUTO_ASSIGN} = "JCVI";
		$loci_comp{$loci}->{FINAL} = $loci_comp{$loci}->{ARAPORT};
		$stats{assigned_jcvi} ++;
		$rule_count{NEW_LOCI_RULE} ++;
		$loci_comp{$loci}->{RULE} = "NEW_LOCI_RULE";
	} elsif (!$loci_comp{$loci}->{TAIR}) { ## 6
		$loci_comp{$loci}->{AUTO_ASSIGN} = "JCVI";
		$loci_comp{$loci}->{FINAL} = $loci_comp{$loci}->{ARAPORT};
		$stats{assigned_jcvi} ++;
		$rule_count{NO_TAIR_RULE} ++;
		$loci_comp{$loci}->{RULE} = "NO_TAIR_RULE";
	} elsif ($loci_comp{$loci}->{TAIR_GENE_SYM_PRESENT} || $loci_comp{$loci}->{CURATOR_SUMMARY}) { ## 7
		$loci_comp{$loci}->{AUTO_ASSIGN} = "TAIR";
		$loci_comp{$loci}->{FINAL} = $loci_comp{$loci}->{TAIR};
		$stats{assigned_tair} ++;
		$rule_count{GENE_SYM_CURATOR_RULE} ++;
		$loci_comp{$loci}->{RULE} = "GENE_SYM_CURATOR_RULE";
	} elsif ($loci_comp{$loci}->{TAIR_UNKNOWN_TO_ARAPORT_NAME}) { ## 8
		$loci_comp{$loci}->{AUTO_ASSIGN} = "JCVI";
		$loci_comp{$loci}->{FINAL} = $loci_comp{$loci}->{ARAPORT};
		$stats{assigned_jcvi} ++;
		$rule_count{TAIR_UNKNOWN_RULE} ++;
		$loci_comp{$loci}->{RULE} = "TAIR_UNKNOWN_RULE";
	}  elsif ($loci_comp{$loci}->{ARAPORT_HYPO_TAIR_KNOWN}) { ## 9
		$loci_comp{$loci}->{AUTO_ASSIGN} = "TAIR";
		$loci_comp{$loci}->{FINAL} = $loci_comp{$loci}->{TAIR};
		$stats{assigned_tair} ++;
		$rule_count{JCVI_HYPOTHETICAL_RULE} ++;
		$loci_comp{$loci}->{RULE} = "JCVI_HYPOTHETICAL_RULE";
	} elsif ($loci_comp{$loci}->{ISOFORM_ANNOTATION_MISMATCH}) { ## 10
		$loci_comp{$loci}->{AUTO_ASSIGN} = "TAIR";
		$loci_comp{$loci}->{FINAL} = $loci_comp{$loci}->{TAIR};
		$stats{assigned_tair} ++;
		$rule_count{MISMATCH_RULE} ++;
		$loci_comp{$loci}->{RULE} = "MISMATCH_RULE";
	} elsif ($loci_comp{$loci}->{HYPO_EQUIVALENT}) { ## 11
		$loci_comp{$loci}->{AUTO_ASSIGN} = "TAIR";
		$loci_comp{$loci}->{FINAL} = $loci_comp{$loci}->{TAIR};
		$stats{assigned_tair} ++;
		$rule_count{HYPOTHETICAL_RULE} ++;
		$loci_comp{$loci}->{RULE} = "HYPOTHETICAL_RULE";
	} else {
		$loci_comp{$loci}->{AUTO_ASSIGN} = "NONE"; ## 12
		$stats{assigned_none} ++;
		$rule_count{DEFAULT_ASSIGNMENT_RULE} ++;
		$loci_comp{$loci}->{RULE} = "DEFAULT_ASSIGNMENT_RULE";
	}
}

sub extract_loci {
	my $id = shift;
	
	if ($id =~ /^AT.G/) {
		my @parts = split /\./, $id; #//
		my $loci = $parts[0];
	
		return $loci;
	} else {
		return $id;
	}
}