#!/usr/local/bin/perl

use strict;

my $file = $ARGV[0];
my $map = $ARGV[1];

my %MAP;
my %seen;

open (MAP, $map) || die "Cannot open $map. $!";
while (<MAP>) {
    chomp $_;
    
    my @line = split /\t/, $_;
    
    if ($seen{$line[1]}) {
        $seen{$line[1]} ++;
        #$MAP{$line[0]} = $line[1];
        $MAP{$line[0]} = "${line[1]}_$seen{$line[1]}";
    } else {
        $seen{$line[1]} ++;    
        $MAP{$line[0]} = $line[1];
    }
    #print "$line[0] => $line[1]\n";
}
close MAP;

open (IN, $file) || die "Cannot open $file. $!\n";


while (<IN>) {
    chomp $_;
    if ($_ =~ /^([0-9a-zA-z.]*)\t/ ){
    	my $match = $1;
        if ($MAP{$match}) {
        	my $line = $_;
        	$line =~ s/$match/$MAP{$match}/;
           	print "$line\n";
           	#print "1=$match\tMAP=$MAP{$match}\n";
        } else {
            print "$_\n";
        }
    } else {
        print "$_\n";
    }
}
close IN;