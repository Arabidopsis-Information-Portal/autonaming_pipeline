#!/usr/local/bin/perl

use strict;

my $file = $ARGV[0];

open (IN, $file) || die "cannot open $file. $!\n";
open (OUT, ">tmp") || die "cannot open tmp. $!\n";

while (<IN>) {
	chomp $_;
	
	my @line = split /\t/, $_;
	
#	print "$line[15]\n";
	
	$line[15] =~ s/.* \| //;
	
	my $line = join("\t",@line);
	
#	print "$line[15]\n";
	print OUT "$line\n";
}

system ("mv tmp $file");