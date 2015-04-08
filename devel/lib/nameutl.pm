#!/usr/local/bin/perl
#use warnings;
use strict;
require "/usr/local/devel/ANNOTATION/APIS/pipeline/lib/com2GOutl.pm";
our $verbose;

my $greek = "alpha|beta|gamma|delta|eta|epsilon|iota|mu|omega|omnicron|pi|theta|tau|zeta";
my $roman = "i|ii|iii|iv|v|vi|vii|viii|ix|x";
my $kingdoms = "plant|animal|insect|eukar[a-z]+|prokar[a-z]+|bacteri[umal]+|archa[a-z]+|viral|virus|fung[usali]+";
my $simpledomains = "domain|repeat|motif|signature";
my $domains = "$simpledomains|lrr|coil|hfold|fold|ploop|loop|helix|[a-z]box|box|knuckle|zipper|finger|hand|site";
my $isoforms = "isoform|isozyme|splice *form|splice *variant|variant";
my $groups = "subgroup|subtype|subclass|supergroup|supertype|superclass|group|type|class";
my $homologs = "paralog|ortholog|homolog|paralogue|orthologue|homologue";
my $homologous = "paralogous|homologous|orthologous|paralogy|orthology|homology|similar[ityies]*";
my $strength = "poor[ly]*|wea[ly]*|low|minor|some|moderate|medium|good|very|strong[ly]*|high[ly]*|major|significant";
my $enzymes = "[a-z]{3,}ase|lyase|rnase|dnase";
my $gerunds = "activating|regulating|transporting|inhibiting|promoting|sup{1,2}ressing|activation|regulation|transportation|inhibition|promotion|sup{1,2}ression";
my %gerund2noun = (
	"activating" => "activator",
	"regulating" => "regulator",
	"transporting" => "transporter",
	"inhibiting" => "inhibitor",
	"promoting" => "promotor",
	"supressing" => "suppressor",
	"suppressing" => "suppressor",
	"activation" => "activator",
	"regulation" => "regulator",
	"transportation" => "transporter",
	"inhibition" => "inhibitor",
	"promotion" => "promotor",
	"supression" => "suppressor",
	"suppression" => "suppressor" );
my $subunits = "component|subunit|chain";
my $aminoacids = "amino *acid|histidine|alanine|iso-*leucine|arginine|leucine|asparagine|lysine|aspartic *acid|methionine|"
	. "cysteine|phenylalanine|glutamic *acid|threonine|glutamine|tryptophan|glycine|valine|ornithine|proline|serine|"
	. "tyrosine|his|ala|arg|leu|lys|met|cys|glu|thr|gly|val|orn|pro|ser";
my $keeppros = "[a-z]{3,}ing|[a-z]{3,}ion|[a-z]*porter|regulat[a-z]+|inter[a-z]+|protein|coupled|linked|disul[phf]+ide";
my $simpleprotypes = "protein|isoform|isoenzyme|isozyme|protein|enzyme|poly[- ]*peptide|retro-*transposon|retro-*element|transposon|poly-*protein";
my $protypes = "$simpleprotypes|[a-z]+-*protein";
my $goodends = "$protypes|$enzymes|$subunits|antigen|chaperone|histone|[a-z]{3,}or|[a-z]{3,}er|[a-z]{3,}in";
my $badends = "carrier|two[- ]*component|tumor|cancer|bladder|confer|[a-z]*ory|[a-z]*ine|[a-z]*ing|like|related|copper|cluster|mer|transfer|other|[a-z]*family|[a-z]membrane|secreted|coenzyme|$aminoacids|$domains|$groups|$kingdoms"; 
my $unknowns = "unknown|uncharacteri[sz]ed|hypothetical|unidentified|unnamed|undetermined|indeterminate|unclas+if[ie]+d";
my $minorwords = "analog[a-z]*|alleles*|acids*|dual|rich|cataly[stic]*|enzymes*|regions*|complex[es]*|[1-9][0-9.]*kD"
	. "|direct[edsiong]+|instruct[edsiong]|independent|dependent|"
	. "|specific[ity]*|insensitive|sensitive"
	. "|associat[iongsed]+|complement[ingsed]*|interact[iongsed]+"
	. "|inactive|active|activit[yies]+"
	. "|trans|cis"
	. "|$isoforms|$strength|$subunits|$groups|$kingdoms|cell|cellular";
my %elements = (
		'Ag' => 'Silver',
		'Al' => 'Aluminum',
		'As' => 'Arsenic',
		'Au' => 'Gold',
		'Br' => 'Bromine',
		'Ca' => 'Calcium',
		'Cd' => 'Cadmium',
		'Cl' => 'Chlorine',
		'Co' => 'Cobalt',
		'Cr' => 'Chromium',
		'Cu' => 'Copper',
		'Fe' => 'Iron',
		'Hg' => 'Mercury',
		'Li' => 'Lithium',
		'Mg' => 'Magnesium',
		'Mn' => 'Manganese',
		'Mo' => 'Molybdenum',
		'Na' => 'Sodium',
		'Ni' => 'Nickel',
		'Pb' => 'Lead',
		'Sb' => 'Antimony',
		'Se' => 'Selenium',
		'Si' => 'Silicon',
		'Sn' => 'Tin',
		'Ti' => 'Titanium',
		'Tl' => 'Thallium',
		'Tm' => 'Thulium',
		'Zn' => 'Zinc',
		'Zr' => 'Zirconium'
	);
my $elementsyms = join( "|", keys %elements );
my $elementnames = join( "|", values %elements );
sub special_words {
	return ( $greek, $roman, $kingdoms,
		$domains, $isoforms, $groups, $subunits,
		$homologs, $homologous, $strength, $enzymes,
		$gerunds, \%gerund2noun,
		$goodends, $badends,
		$keeppros, $aminoacids,
		$unknowns );
}

sub cazy_name_parser {
	my ( $id ) = @_;

	my $name = cazy_acc_to_name( $id );
	$name =~ s/  +/ /g;
	
	return $name;
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

sub simple_name_parser {
	my ( $defline ) = @_;

	my $name = $defline;
	$name =~ s/\t/ /g;
	
	return $name;	
}

sub unipro_name_parser {
	my ( $defline ) = @_;
	
	my $name = $defline;
	$name =~ s/ +OS=.*//;	
	$name =~ s/ +Tax=.*//;	
	$name =~ s/ +n=[1-9][0-9]* *$//;	
	$name =~ s/ +clone *$//;
	$name =~ s/ +clone .*$//;
	
	if ( ! $name ) { return "" }

	return $name;
}

sub tair_name_parser {
	my ( $defline ) = @_;
	
	my @fields = split /\|/, $defline;
	my $symbol = $fields[1];
	$symbol =~ s/^.*://;
	$symbol =~ s/ //g;
	$symbol =~ s/,.*//;
	
	my $name = $fields[2];
	$name =~ s/^ +//;
	$name =~ s/ +$//;
	
	if ( $symbol gt "" && $name =~ /^ *(from|of) /  ) {
		$name = "$symbol, $name";
	}
	
	if ( length( $name ) > 120 ) { $name = "" }
	if ( $name =~ /^(.*) +([a-z]*family|$enzymes|enzyme|protein)s* +with +(.*)$/i ) {
		my $prot = "$1 $2";
		my $detail = $3;
		if ( $detail =~ /\b(domains*|repeats*)\b/i ) {
			$name = "$detail $prot";			
		}
	}
	
	return $name;
}

sub tigrfam_name_parser {
	my ( $id, $definition, $iso_type ) = @_;
	if ( ! defined $iso_type ) { $iso_type = "other" }
	my $name = $definition;
	
	if ( $name =~ /\b(DUF[0-9]+)\b/ ) {
		my $dom = $1;
		if ( $name =~ /family/i ) {
			$name = "$dom family protein";
		}
		else {
			$name = "$dom domain protein";
		}

		return $name;
	}
	
	if ( $name =~ /^(.*\b($domains)\b) +(for|of) +(.*)$/i ) {
		my $dom = $1;
		my $desc = $4;
		if ( $dom !~ /,;\// ) {
			$name = "$desc $dom";
		}
	}

	if ( $name =~ /\W(protein|$enzymes|enzyme|chain|subunit|component|\w{3,}or|\w{3,}er)[- ]+([^ ]+)$/i ) {
		my $type = $1;
		if ( $type =~ /finger$/i ) {
			$name .= " protein";
		}
		else {
			my $detail = $2;
			if ( $detail =~ /^[([]/ ) { $detail =~ s/^.// }
			if ( $detail =~ /[)\]]$/ ) { $detail =~ s/.$// }
			$detail =~ s/^ +//;
			$detail =~ s/ +$//;
			if ( $detail !~ /[0-9]/ && length( $detail ) > 6 ) {
				$name .= " protein";
			}
		}
	}
	elsif ( $name !~ /\W(protein|$enzymes|enzyme|chain|subunit|component|\w{3,}or|\w{3,}er)$/i ) {
		$name .= " protein";
	}
	elsif ( $name =~ /finger$/i ) {
		$name .= " protein";
	}
	
	$name =~ s/\b(PF|TIGR)[0-9]+\b//gi;
	$name =~ s/[- ]+(binding|directed|depend[ae]nt)/-$1/gi;
	$name =~ s/^ +//;
	$name =~ s/  +/ /g;
	$name =~ s/ +$//;

	return $name ;
}

sub nr_name_parser {
	my ( $defline ) = @_;
	
	my $name = $defline;
	$name =~ s/; *altname[:=].*//i;
	$name =~ s/; *short[:=].*//i;
	$name =~ s/; *flags[:=].*//i;
	$name =~ s/^.*recname[:=] *//i;
	$name =~ s/^.*full[:=] *//i;
	
	# remove/truncate at these phrases
	if ( $name =~ / [Tt]itle:/) {
		$name =~ s/^.* [Tt]itle: *//;
		my @tmp = split( "-", $name );
		pop @tmp;
		$name = join( "-", @tmp );
	}

	if ( ! $name ) { return "" }
	
	return $name;
}

sub cdd_name_parser {
	my ( $defline ) = @_;
	my $dbg = 0;
	if ( $dbg ) { print "\nCDD0: $defline\n" }	

	my $name = $defline;
	if ( $name =~ /Uncharacterized conserved protein/i ) { return "" }
	if ( $name =~ /(protein|doimain) of unknown function/i ) { return "" }
	if ( $name =~ /hypothetical protein/i ) { return "" }

	$name =~ s/\t/ /g;
	$name =~ s/^gnl[^ ]*  *//;
	$name =~ s/ *$//;
	$name =~ s/^[^,]*, *//;
	$name =~ s/, +(domain|repeat|motif).*//i;
	$name =~ s/\b(nucleo[st]ide|peptide)s+\b/$1/gi;
	$name =~ s/\b($enzymes|[a-z]*porter|[a-z]*enzyme|[a-z]*protein|domain|repeat|system)s\b/$1 family/gi;
	$name =~ s/\bfamily +([a-z]*family)/$1/gi;
	$name =~ s/\bCD\b/domain/g;
	$name =~ s/\b(component)s+\b/$1/gi;
	$name =~ s/families/family/gi;
	$name =~ s/\b($enzymes)s\b/$1/gi;
	$name =~ s/($enzymes|protein|domain|repeat|family) +in .*/$1/gi;
	$name =~ s/\. +([a-z])/. $1/g;
	$name =~ s/Arabidopsis/plant/gi;
	$name =~ s/\bAt[0-9]+g[0-9]+\b/(plant)/gi;
	$name =~ s/[Rr]esistant to [A-Z]\..*/resistance/g;
	$name =~ s/[-:;, ]+$//;
	$name =~ s/\b(members of )(the )*//gi;
	$name =~ s/[;.] .*//;
	$name =~ s/ +and +(related|associated|similar).*/-like/gi;
	$name =~ s/ +(proteins* +)*containing +(.*\b($domains))/ $2/i;
	$name =~ s/\bprotein +([a-z]*famil[yies]+|domains*|repeats*)\b/$1/gi;
	$name =~ s/\blike +family\b/like/gi;
	$name =~ s/\bSDRs\b/SDR family/g;
	$name =~ s/catalytic *\(c\)/catalytic/gi;
	$name =~ s/classical *\(c\)/classical/gi;
	$name =~ s/extended *\(e\)/extended/gi;
	$name =~ s/atypical *\(a\)/atypical/gi;
	$name =~ s/(classical|extended|atypical) *SDR\b/$1-SDR family/g;
	$name =~ s/\bSDR *family *(domains|domain|[a-z]*family|[a-z]*families)/SDR family/g;
	if ( $dbg ) { print "CDD0z: $defline\n" }	

	while ( $name =~ / +[({\[]*(are an{0,1} |is an{0,1} |found in |from |proteins* in |named for |belongs |exhibits* various |associated |duplicated |similar to |related to |play|contain|includ|involv|consist|catalyze|participat|confirm)/i ) {
		if ( $dbg ) { print "CDD1a.1: $name\n" }
		$name =~ s/ +[({\[]*(are an{0,1} |is an{0,1} |found in |from |proteins* in |named for |belongs |exhibits* |various |associated |duplicated |similar to |related to |play|contain|includ|involv|consist|catalyze|participat|confirm).*$//i;
		if ( $dbg ) { print "CDD1a.2: $name\n" }
#print "while1: $name\n";
	}
	$name =~ s/, *(domains*|proteins*|[a-z]*famil[yies]+) *$//i;
	$name =~ s/[ ,]+$//;
	if ( $dbg ) { print "CDD1a: $name\n" }

	$name = fix_cdd_phrases( $name );
	if ( $dbg ) { print "CDD1b: $name\n" }

	while ( $name =~ / +[({\[]*(with |where |when |while |which |that |this |these |those |the |found |is |are |having |have |has  )/i ) {
		$name =~ s/ +[({\[]*(with |where |when |while |which |that |this |these |those |the |found |is |are |having |have |has  ).*//i;
#print "while2: $name\n";
	}
	$name =~ s/(family.{0,20}) of .*/$1/i;
	$name =~ s/ +(and|or|is|are) *$//;
	if ( $dbg ) { print "CDD1c: $name\n" }

	if ( $name =~ /^[^:, ]{1,20}: *[^, ]{1,30}, *(.{1,100})$/ ) {
		$name = $1;
		if ( $dbg ) { print "CDD2a: $name\n" }
		return final_cdd_adjustment( $name );
	}
	if ( $name =~ /^[^:, ]{1,20}, *[^, ]{1,30}: *(.{1,100})$/ ) {
		$name = $1;
		if ( $dbg ) { print "CDD2b: $name\n" }
		return final_cdd_adjustment( $name );
	}
	if ( $name =~ /^[^:, ]{1,20}: *(.{1,100})$/ ) {
		$name = $1;
		if ( $dbg ) { print "CDD2c: $name\n" }
		return final_cdd_adjustment( $name );
	}
	if ( $name =~ /^[^,: ]{1,30}, *(.{1,100}?)$/ ) {
		$name = $1;
		if ( $dbg ) { print "CDD2d: $name\n" }
		return final_cdd_adjustment( $name );
	}

	$name =~ s/_/-/g;
	if ( $name =~ /^([^,: ]{1,30}), *(.*)/ ) {
		my $abbr = $1;
		my $detail = $2;
		if ( $abbr =~ / / || $abbr =~ /($enzymes)$/ ) {
			if ( length( $detail ) < 40 ) {
				if ( $dbg ) { print "CDD3a: $name\n" }
				return final_cdd_adjustment( $name );
			}
		}
		if ( $abbr !~ /\b($domains|[a-z]*family|like|related)$/i ) {
			$abbr .= " domain";
		}
		if ( length( $detail ) < 40 ) {
			$name = "$abbr ($detail)";
			if ( $dbg ) { print "CDD3b: $name\n" }
			return final_cdd_adjustment( $name );
		}
		else {
			$name = $abbr;
			if ( $dbg ) { print "CDD3c: $name\n" }
			return final_cdd_adjustment( $name );
		}
	}
	else {
		if ( $dbg ) { print "CDD3c: $name\n" }
		return final_cdd_adjustment( $name );
	}
}

sub fix_cdd_phrases {
	my ( $name ) = @_;
	my $dbg = 0;
	if ( $dbg ) { print "  phrin: $name\n" }
	
	if ( $name =~ /provisional/i ) { return "" }
	
	$name =~ s/^[,;. ]+//;
	$name =~ s/[,;. ]+$//;
	$name =~ s/^ *(a|an|the) +//i;
	$name =~ s/ +\[[^[\]]*\]$//g;
	$name =~ s/ +\([^()]*\)$//g;
	$name =~ s/ +\{[^{}]*\}$//g;
			
	my @phrases = split /([;.,] +)/, $name;
	for my $i ( 0..@phrases - 1 ) {
		if ( $phrases[$i] =~ /^(a|an|this|the|these|related|play[edings]*|confirm[a-z]*|involv[edings]*|[a-z]{3,}ing|associated with|related to|with|similar[ity]*) /i ||
				 $phrases[$i] =~ /\b($unknowns)\b/i ) {
			$phrases[$i] = undef;
			$phrases[$i+1] = undef;
		}
	}
	
	my $has_domain = 0;
	for my $i ( 0..@phrases - 1 ) {
		if ( $has_domain ) { $phrases[$i] = undef }
		my $phrasei = $phrases[$i];
		if ( ! defined $phrasei || $phrasei !~ /\w/ ) { next }
		if ( $dbg ) { print "  phr$i: $phrasei\n" }

		$phrasei =~ s/ +\[[^[\]]*\]$//g;
		$phrasei =~ s/ +\([^()]*\)$//g;
		$phrasei =~ s/ +\{[^{}]*\}$//g;
		if ( $phrasei =~ /^(a|the|related) /i ) {
			$phrasei =~ s/^(a|the|related) +//i;
			if ( $dbg ) { print "  phr$i.a: $phrasei\n" }
		}
		if ( $phrasei =~ /^(.*\b($domains|$enzymes))s* *(of|in|from|to) +(.*)/i ) {
			$phrasei = "$4 $1";
			$phrasei =~ s/^(the|a|an) +//i;
			if ( $dbg ) { print "  phr$i.b: $phrasei\n" }
		}
		elsif ( $phrasei =~ /^(.*) +of +(.*)/ ) {
			$phrasei = "$2 $1";
			$phrasei =~ s/^(the|a|an) +//i;
			if ( $dbg ) { print "  phr$i.c: $phrasei\n" }
		}
		$phrases[$i] = $phrasei;
		my $testi = lc( $phrasei );
		$testi =~ s/[_\W]//g;
		for my $j ( $i+1..@phrases-1 ) {
			my $phrasej = $phrases[$j];
			if ( defined $phrasej ) {
				my $testj = lc( $phrasej );
				$testj =~ s/[_\W]//g;
				if ( index( $testj, $testi ) >= 0 ) {
					$phrasei = undef;
					$phrases[$i] = undef;
					$phrases[$i+1] = undef;
					last;
				}
			}
		}
		if ( $i > 0 && defined $phrasei &&
				$phrasei =~ /\b($domains)\b/ &&
				$phrasei !~ /^\W*(domain|repeat|motif)/i ) {
			$has_domain = 1;
		}		
	}
	@phrases = remove_undefs( @phrases );
	while ( @phrases && $phrases[@phrases-1] !~ /\w/ ) {
#print "while3: " . @phrases . "\n";
		if ( $dbg ) { print "  phrcln: $phrases[@phrases-1]\n" }
		pop @phrases;
	}

	$name = join( "", @phrases );
	if ( $dbg ) { print "  phrjoin: $name\n" }
	$name =~ s/[.;, ]+$//;
	$name =~ s/^[.;, ]+//;
	if ( $dbg ) { print "  phrout: $name\n" }
	return $name;
}

sub final_cdd_adjustment {
	my ( $name ) = @_;
	
	# remove parenthetical expression at end
	$name =~ s/ +\[[^[\]]*\]\W*$//g;
	$name =~ s/ +\([^()]*\)\W*$//g;
	$name =~ s/ +\{[^{}]*\}\W*$//g;
	$name =~ s/ +\[[^[\]]*$//g;
	$name =~ s/ +\([^()]*$//g;
	$name =~ s/ +\{[^{}]*$//g;

	# remove empty parenthetical expression
	$name =~ s/\(\W*\)//;
	$name =~ s/\[\W*\]//;
	$name =~ s/\{\W*\}//;
	
	# remove leading trailing punctaution
	$name =~ s/^[-,;:. ]+//;
	$name =~ s/[-,;:. ]+$//;
	
	# remove leading minor words
	$name =~ s/^ *(an|a|these|the|this|of) +//i;

	# family and...family
	$name =~ s/ +[a-z]*family +and +(.{3,25}) +[a-z]*family/$1 family/i;

	# catalytic domain	
	$name =~ s/ \(c\)//gi;
	$name =~ s/Catalytic/catalytic/gi;
	$name =~ s/, (catalytic domain)/ $1/gi;

	# add missing "domain"	
	if ( length( $name ) < 15 && $name !~ /\b($domains|[a-z]*family)\b/i ) {
		if ( $name !~ /(protein|enzyme|$enzymes)$/i ) {
			$name .= " domain";
		}
	}

	return $name;
}

sub standardize_case {
	my ($names) = @_;
	my $dbg = 0;

	# compile list of words and their various capitalizations
	my %cases;
	for my $name ( @$names ) {
		if ( $dbg ) { print " standardize_case: $name\n" }
		$name =~ s/\bCO-/co-/g;
		my $mixed = 0;
		if ( $name =~ /[a-z]/ && $name =~ /[A-Z]/ ) { $mixed = 1 }
		
		for my $word ( split /\W+/, $name ) {
			if ( $dbg ) { print " 0. $word\n" } 
			my $lower = lc($word);
			my $upper = uc( $word );

			# leave single letters as is
			if ( length( $word ) == 1 ) {
				if ( $dbg ) { print " 1. $word\n" }
			}
			# XXXase
			elsif ( $lower =~ /^([a-z]tp|[rd]n)ases*$/ ) {
				$word = uc( $1 ) . "ase";
				if ( $dbg ) { print " 2 $word\n" }
			}
			# convert mix of numbers and lowercase letters to uppercase
			elsif ( $word =~ /^[a-z]+[0-9]+[-\.0-9]*$/i && $word eq $lower ) {
				$word = uc( $word );
				if ( $dbg ) { print " 3 $word\n" }
			}
			# Rieske
			elsif ( $lower =~ /^rieske$/ ) {
				$word = "Rieske";
				if ( $dbg ) { print " 4 $word\n" }
			}
			# xxDNA/RNA
			elsif ( $lower =~ /^(r|t|ds|ss|sno|sn|s)*(dna|rna)$/ ) {
				$word = lc( $1 ) . uc( $2 );
				if ( $dbg ) { print " 5 $word\n" }
			}
			# AMP/GMP/IMP/UDP/ATP/ABC/NAD/etc.
			elsif ( $lower =~ /^(amp|gmp|imp|udp|utp|atp|abc|nad|nadh|nadp|nadph|sam|la|$roman|lrr|nbs|cc|fbd|rni)$/ ) {
				$word = uc( $word );
				if ( $dbg ) { print " 6 $word\n" }
			}
			# some short known words
			elsif ( $word =~ /^(non|pre|locus|like|related|[a-z]*family|one|two|three|four|five|six|seven|eight|nine|ten|$domains|$isoforms|$groups|$subunits|$homologs|$greek|$aminoacids|$kingdoms)$/i ) {
				$word = $lower;
				if ( $dbg ) { print " 7 $word\n" }
			}
			# assume longish word should be lowercase
			elsif ( ! $mixed && length( $word ) >= 6 && $word !~ /[0-9]/
					&& $word !~ /[A-Z]{2,}[a-z]/ && $word !~ /[a-z][A-Z]/ ) {
				$word = $lower;
				if ( $dbg ) { print " 8 $word\n" }
			}
			# treat initcap as lowercase
			elsif ( length( $word ) > 3 && $word =~ /^[A-Z][a-z]*$/ ) {
				$word = $lower;
				if ( $dbg ) { print " 9 $word\n" }
			}
			else {
				if ( $dbg ) { print " 10 $word\n" }
			}

			# increment occurences of this capitalization
			$cases{$lower}{$word}++;
			if ( $word =~ /[a-z]/ && $word =~ /[A-Z]/ ) { $cases{$lower}{$word} += 1.5 }
			if ( $word eq $lower ) { $cases{$lower}{$word} += 0.001 }
		}
	}

	# determine most frequent capitalization for each word
	for my $lower ( sort { $a cmp $b } keys %cases ) {
		my @forms = sort { $cases{$lower}{$b} <=> $cases{$lower}{$a} } keys %{ $cases{$lower} };
		if ( $dbg ) {
			for my $form ( @forms ) {
				print "$lower : $form : $cases{$lower}{$form}\n";
			}
		}
		$cases{$lower} = $forms[0];
	}

	# replace words with their most frequent capitalization
	my %results;
	for my $name ( @$names ) {
		my $text = "";
		for my $word ( split /(\W+)/, $name ) {
			my $lower = lc($word);
			if ( exists $cases{$lower} ) {
				$text .= $cases{$lower};
			}
			else {
				$text .= $word;
			}
		}
		$text =~ s/\ba\.{0,1} *k\.{0,1} *a\.{0,1}\b/a.k.a./gi;
		
		# uppercase some single letters
		$text =~ s/ i\b/ I/g;
		$text =~ s/\bb-*zip\b/bZIP/gi;
		$text =~ s/\ba[-\/\\\| ]*b[- ]+barrel/alpha\/beta-barrel/gi;
		$text =~ s/\ba[- ]+barrel/alpha-barrel/gi;
		$text =~ s/\bb[- ]+barrel/beta-barrel/gi;
		$text =~ s/\ba\/b\b/A\/B/g;
		while ( $text =~ /(class|group|type|component|enzyme|[a-z]{3,}ine|[a-z]{3,}one|[a-z]{3,}in|[a-z]{3,}on|[a-z]{3,}er|[a-z]{3,}or|$subunits|ase|cytochrome)([- ]+)([a-z])\b/ ) {
			my $grp = $1;
			my $sep = $2;
			my $low = $3;
			my $up = uc( $low );
			my $pre = $text;
			$text =~ s/$grp$sep$low/$grp$sep$up/;
print "change $pre to $text\n";
		}

		$results{$name} = $text;
	}
	
	return \%results;
}

sub flag_weak_name {
	my ( $name ) = @_;
	my $text = $name;
	
    # undesirable words
    if ( $text =~ /\b(DUF[0-9]+|genes*|cDNA|ESTs*|predicted|conserved|$unknowns)\b/i ) {
#print "weak1 $text\n";
		return 1;
	}

	# low content
	if ( $text =~ /^([^ ]+)(\b($aminoacids|repeat|rich|binding))+([-, ]*(protein|like|related|putative))*$/i ) {
		my $pre = $1;
		$pre =~ s/\W//g;
		if ( length( $pre ) < 8 && $pre !~ /[a-z]{3,}/ ) {
			if ( $pre !~ /($goodends)$/i || $pre =~ /($badends)$/i ) {
#print "weak2 $name | $pre | $text\n";
				return 2;
			}
		}
	}
	
	if ( $text =~ /^([-, ]*(lrr|cytoplasm[a-z]*|transmembrane|membrane|nucleus|nuclear|$aminoacids|$strength|$kingdoms|$isoforms|$simpledomains|protein|enzyme|like|related|putative|[a-z]*family)s*)*$/i ) {
#print "weak3 $text\n";
		return 3;
	}
	
	# cancer/tumor
	if ( $text =~ /\b(tumor|carcinoma|cancer)\b/i ) {
#print "weak4 $text\n";
		return 4;
	}
	
	# too general
	$text =~ s/complex/cplx/gi;
	$text =~ s/\b(kDa|like|related|putative|protein|enzyme|$subunits|$isoforms|$kingdoms|$strength|$minorwords)\b//gi;
	$text =~ s/[\.0-9]+/1/gi;
	$text =~ s/\b($greek|$roman|[a-z]|$aminoacids|$groups|$elementsyms|$elementnames|cytoplasm[a-z]*|transmembrane|membrane|nucleus|nuclear|binding)\b/a/gi;
	$text =~ s/\b($domains|[a-z]*family)\b/xx/gi;
	$text =~ s/[^a-z0-9]+/ /gi;
	if ( $text =~ /^ *(monoxygenase|transferase|synthase) *$/i ) {
#print "weak9 $text\n";
		return 9;
	}
	$text =~ s/^ +//;
	$text =~ s/ +$//;
	if ( $text =~ / [^ ]+ / ) { $text =~ s/ // }

	# long names
	if ( length( $text ) > 75 ) {
#print "weak10 $text\n";
		return 10;
	}
	
	# short names
	if ( $name !~ /\b(enzymes)\b/i ) {
		if ( length( $text ) < 5 ) {
#print "weak11 $name = $text\n";
			return 11;
		}
		if ( length( $text ) < 10 && $text !~ /[a-z]/ ) {
#print "weak12 $text\n";
			return 12;
		}
	}
	
	return 0;
}
sub rejected_name {
	my ( $name ) = @_ ;

	# discard names with forbidden content
	if ( $name =~ /\b($unknowns)\b/i ) {
		return 1;
	} elsif ( $name =~ /crystal.*structure/i ) {
		return 2;
	} elsif ( $name =~ /\b(whole *genome|genomics*|genom(eic)* sequenc(eing)*|WGS project|shotgun.*assembly)\b/i ) {
		return 3;
	} elsif ( $name =~ /\b(WGS|shotgun|(complete|partial|draft)) *(sequence|genome|CDS)/i ) {
		return 3;
	} elsif ( $name !~ /genome[- ]*(instability|stability|repair|maintenance)/ && $name =~ /\bgenom[iecs]+\b/i ) {
		return 4;
	} elsif ( $name =~ /\b(scaffold|supercontig|clone|EST|contig)s*\b/i ) {
		return 4;
	} elsif ( $name =~ /\b(clone|EST|contig|contg|cntg|ctg|scaffold|scaf|scf)[-_0-9]{2,}\b/i ) {
		return 4;
	} elsif ( $name =~ /\b(encoded *by|encode|restricted to|based on|blast *hit|to form)s*\b/i ) {
		return 5;
	} elsif ( $name =~ /\b(gene|orf|cds|ps[eu]+dogene|\borphan *protein|frame[- ]*shift)s*\b/i ) {
		return 6;
	} elsif ( $name =~ /\bUPI/i && $name =~ /\bcluster/i ) {
		return 9;
	} elsif ( $name =~ /(conserved|hypothetical)/i || $name =~ /\b(DUF|UPF)\b/i ) {
		return 10;
	} elsif ( $name =~ /\bpatent\b/ ) {
		return 11;
	}
	elsif ( $name =~ /^locus\b/i ) { return 14 }
	elsif ( $name =~ /\b(splice *site|start *codon|stop *codon|intron|exon)s*\b/i ) { return 15 }
	elsif ( index( $name, "|" ) >= 0 || index( $name, "=" ) >= 0 ) { return 17 }
	elsif ( $name =~ /\bintegron[- ]*(protein|gene)[- ]*cassette\b/i ) {
		return 19;
	}
	elsif ( $name =~ /^([Cc]complex:|[Ii]s|[Aa]nd|[Tt]he|[Ff]rom|[Ff]or|[Ww]ith|[Hh]a[sd]|[Hh]av(e|ing)|[Th]is|[Tt]hese|[Ss]hows|[Ii]nvolv(es|ed|e|ing)) / ) {
		return 20;
	}
	elsif ( $name =~ /\b(acc\.* *(no\.*|number)|accession|identifier|seq *id)\b/i ) {
		return 21;
	}

	# do not reject known short domains/repeats/families
	if ( $name =~ /\b([A-Z]{2,}|[A-Z]{1,}-{0,1}[0-9A-Z]{1,2}|CAP160|La|Ig|Fz|Sm|DUF[0-9]+)\b/ &&
			$name =~/(domain|repeat|family|like|related|protein)/i ) {
	 	return 0;
	}
	elsif ( $name =~ /\b([1-9]Fe-[1-9]S|Fe-S|FK506)\b/ &&
			$name =~/binding/i ) {
	 	return 0;
	}
	elsif ( $name =~ /\b(P450|4F5|14-3-3)\b/ &&
			$name =~ /(family|-like\b|-related\b)/i ) {
		return 0;
	}

	# discard low/no-content names, very short acronyms, and accessions	
	my $test = $name;
	$test =~ s/\b(M|G)[- ]*(protein|family|domain|repeat)/GGGGGG $1/gi;
	$test =~ s/[,;:'"\[\](){}\/\\|?!@#\$\%^&*=+]//g;
	$test =~ s/^(orf|cdna|gene|gp)//i;
	$test =~ s/\b(duf|upf)[- ]+([0-9])/$1$2/gi;
	$test =~ s/\b(duf|upf)\b//gi;
	while ( $test =~ /\b($unknowns|$isoforms|$groups|$greek|$roman|$kingdoms|$strength|$subunits|$aminoacids|$simpleprotypes)\b/i ) {
		 $test =~ s/\b($unknowns|$isoforms|$groups|$greek|$roman|$kingdoms|$strength|$subunits|$aminoacids|$simpleprotypes)\b//gi;
	}
	while ( $test =~ /([a-z]*family|\blike\b|\bLRR\b|related +to|related|putative|cataly[a-z]*|rich|domain|region|repeat|motif|associat[a-z]*|with|binding)/i ) {
		$test =~ s/([a-z]*family|\blike\b|\bLRR\b|related +to|related|putative|cataly[a-z]*|rich|domain|region|repeat|motif|associat[a-z]*|with|binding)//i;
	}
	$test =~ s/^ +//;
	$test =~ s/ +$//;
	$test =~ s/  +/ /g;

	if ( $test !~ /\w/ ) {
		return 22;	# no content
	}
	elsif ( $test !~ /\w{2,}/ || ( $test !~ /[- ]/ && $test !~ /\w{3,}/ ) ) {
		return 23; # low content/short acronym
	}
	elsif ( $test !~ / / ) {
		if ( $test =~ /[0-9]{4,}/ ) { return 24 }
		if ( $test =~ /[0-9]\.[0-9]/ ) { return 25 }
		if ( $test !~ /[a-z]{3}/i ) { return 26 }
		if ( length( $test ) < 6 && $test =~ /[0-9]{3,}$/ ) { return 27 } 
	}
	
	return 0;
}


sub normalize_name {
	my ( $name, $normalization_method, $assumed_phrase ) = @_;
	my $dbg = 0;
	#if ( $name =~ /71.* family/ ) { $dbg = 1 }

	if ( ! defined $normalization_method ) { $normalization_method = 0 }

	my $norm = $name;
	if ( $dbg ) { print "\nnorm($normalization_method) in: $name\n" }

	my $assumed = "";
	my $assumed_norm;
	if ( defined $assumed_phrase ) {
		$assumed = $assumed_phrase;
		$assumed =~ s/[- ]*\b($simpledomains)s*\b//gi;
		$assumed =~ s/[- ]*\b(like|related|[a-z]*famil[yies]+|putative)\b//gi;
		$assumed_norm = normalize_name( $assumed, $normalization_method );
	}

	# case-sensitive normalizations
	# remove conjuctions/articles/prepositions/is
	# and/or/but/a/the/to/from/in/of/by/for/is/has/had/have/having
	$norm =~ s/ +(or|a|as|to|in|on|of|by|is)\b +/ /g;
	$norm =~ s/^(or|a|as|to|in|on|of|by|is)\b +/ /gi;
	$norm =~ s/ +(and|the|from|for|with|has|had|have|having|was|will)\b +/ /gi;
	$norm =~ s/^(and|the|from|for|with|has|had|have|having|was|will)\b +/ /gi;
	$norm =~ s/^ +//;
	$norm =~ s/ +$//;
	$norm =~ s/  +/ /g;
	if ( $dbg ) { print "  norm small words: $norm\n" }

	# H+ => proton
	$norm =~ s/\bH\(*\+\)*(\W)/proton /gi;
	$norm =~ s/\bhydrogens*\b/proton/gi;
	$norm =~ s/\bproton *ions*\b/proton/gi;
	if ( $dbg ) { print "  norm proton: $norm\n" }
	
	# RT -> reverse transcriptase
	$norm =~ s/\bRT\b/reverse transcriptase/g;
	if ( $dbg ) { print "  norm RT: $norm\n" }

	# standardize (two-character) element symbols
	my %elements = (
		'Ag' => 'Silver',
		'Al' => 'Aluminum',
		'As' => 'Arsenic',
		'Au' => 'Gold',
		'Br' => 'Bromine',
		'Ca' => 'Calcium',
		'Cd' => 'Cadmium',
		'Cl' => 'Chlorine',
		'Co' => 'Cobalt',
		'Cr' => 'Chromium',
		'Cu' => 'Copper',
		'Fe' => 'Iron',
		'Hg' => 'Mercury',
		'Li' => 'Lithium',
		'Mg' => 'Magnesium',
		'Mn' => 'Manganese',
		'Mo' => 'Molybdenum',
		'Na' => 'Sodium',
		'Ni' => 'Nickel',
		'Pb' => 'Lead',
		'Sb' => 'Antimony',
		'Se' => 'Selenium',
		'Si' => 'Silicon',
		'Sn' => 'Tin',
		'Ti' => 'Titanium',
		'Tl' => 'Thallium',
		'Tm' => 'Thulium',
		'Zn' => 'Zinc',
		'Zr' => 'Zirconium'
	);
	for my $sym ( keys %elements ) {
		while ( $norm =~ /\b$sym\b/ ) {
			$norm =~ s/\b$sym\b/$elements{$sym}/;
#print "while13: $norm\n";
#print "  $sym: $norm\n";
		}
	}
	if ( $dbg ) { print "  norm elem: $norm\n" }

	# ============================================================
	# ============================================================
	# ============================================================
	# from here on we can assume lowercase 
	# unless we are hilighting a special word
	$norm = lc( $norm );
	# ============================================================
	# ============================================================
	# ============================================================

	# clean up punctation
	$norm =~ s/ *-[- ]+/-/g;

	# reserve '#' for hiliting family IDs
	$norm =~ s/#/ /gi;
	if ( $dbg ) { print "  norm prepunct: $norm\n" }

	# kda (protein weight in kilo-daltons)
	while ( $norm =~ /\b([0-9.]+)[- ]*(kda|kd)\b/ ) {
		$norm =~ s/\b([0-9.]+)[- ]*(kda|kd)\b/$1kD/;
	}
	while ( $norm =~ /\b([0-9.]+)[- ]+(kda|kd|k)\b/ ) {
		$norm =~ s/\b([0-9.]+)[- ]+(kda|kd|k)\b/$1kD/;
	}
	if ( $dbg ) { print "  norm kDa: $norm\n" }

	# family identifiers
	$norm =~ s/ *$/,/;
	$norm =~ s/!//g;
	$norm =~ s/family[- ]*(like|related|$groups)/family/gi;
	while ( $norm =~ /(family|$groups|$simpledomains)[- ]*([^#!,;: ]+)[- ]+($protypes|$subunits|domain|repeat|motif|like|related|[,;:])(.*)$/i ) {
		my $famnum = $2;
		if ( $dbg ) { print "  norm famnum1: $famnum\n" }
		if ( $famnum !~ /[a-z]{2,}/ && $famnum !~ /kD/ && length( $famnum ) <= 8 ) { # $famnum =~ /[0-9]/ &&
			$famnum =~ s/[^a-z0-9]/#/gi;
			while ( $famnum =~ /([a-z])([0-9])/ ) {
				$famnum =~ s/([a-z])([0-9])/$1#$2/;
#print "while6: $famnum\n";
			}
			while ( $famnum =~ /([0-9])([a-z])/i ) {
				$famnum =~ s/([0-9])([a-z])/$1#$2/;
#print "while7: $famnum\n";
			}
			$famnum =~ s/##+/#/g;
			$famnum =~ s/^#+//;
			$famnum =~ s/#+$//;
			$famnum = "#$famnum#";
			$norm =~ s/(family|$groups|$simpledomains)[- ]*([^#!,;: ]+)[- ]+($protypes|$subunits|domain|repeat|motif|like|related|[,;:]|$)(.*)$/$1 $famnum $3$4/;
			$norm =~ s/ +$//;
			if ( $dbg ) { print "  norm famnum2a ($famnum): $norm\n" }
		}
		else {
			$norm =~ s/(family|$groups|$simpledomains)[- ]*([^#!,;: ]+)[- ]+($protypes|$subunits|domain|repeat|motif|like|related|[,;:]|$)(.*)$/$1 !$2! $3$4/;
			$norm =~ s/ +$//;
			if ( $dbg ) { print "  norm famnum2b ($famnum): $norm\n" }
		}
	}
	while ( $norm =~ /\b([^#!,;: ]+)[-, ]+([a-z]*family|$groups|$simpledomains)/i ) {
		my $famnum = $1;
		if ( $dbg ) { print "  norm famnum3: $famnum\n" }
		if ( $famnum !~ /[a-z]{2,}/ && $famnum !~ /kD/ && length( $famnum ) <= 8 ) { #$famnum =~ /[0-9]/ &&
			$famnum =~ s/[^a-z0-9]/#/gi;
			while ( $famnum =~ /([a-z])([0-9])/ ) {
				$famnum =~ s/([a-z])([0-9])/$1#$2/;
#print "while6: $famnum\n";
			}
			while ( $famnum =~ /([0-9])([a-z])/i ) {
				$famnum =~ s/([0-9])([a-z])/$1#$2/;
#print "while7: $famnum\n";
			}
			$famnum =~ s/##+/#/g;
			$famnum =~ s/^#+//;
			$famnum =~ s/#+$//;
			$famnum = "#$famnum#";
			$norm =~ s/\b([^#!,;: ]+)[-, ]+([a-z]*family|$groups|$simpledomains)/$famnum $2/;
			if ( $dbg ) { print "  norm famnum4a ($famnum): $norm\n" }
		}
		else {
			$norm =~ s/\b([^#!,;: ]+)[-, ]+([a-z]*family|$groups|$simpledomains)/!$1! $2/;
			if ( $dbg ) { print "  norm famnum4b ($famnum): $norm\n" }
		}
	}
	$norm =~ s/!//g;
	$norm =~ s/[ ,]+$//;

	# 14-3-3/P450
	$norm =~ s/\b14-([1-9])-([1-9])\b/#14#$1#$2#/g;	
	if ( $dbg ) { print "  norm 14-n-n: $norm\n" }
	
	# dimer/trimer/tetramer/(monomer?)
	$norm =~ s/mono-*mer([icszation])*\b/ $1MMr /gi;
	$norm =~ s/di-*mer([icszation])*\b/ $1DMr /gi;
	$norm =~ s/tri-*mer([icszation])\b/ $1TMr /gi;
	$norm =~ s/tetra-*mer([icszation])\b/ $1QMr /gi;

	# Kinases
	if ( "$norm $assumed" =~ /kinase/i ) {
		$norm =~ s/(map[2-4]) *kinase/$1k kinase/g;
		$norm =~ s/\bmek\b/mapk/g;
		$norm =~ s/\b(mekk|mkk)\b/map2k/g;
		$norm =~ s/\b(mekkk|mkkk)\b/map3k/g;
		$norm =~ s/\bste\b/#ste# mapk/g;
		$norm =~ s/\bste7\b/#ste#7# map2k/g;
		$norm =~ s/\bste11\b/#ste#11# map3k/g;
		$norm =~ s/\bste20\b/#ste#20# map4k/g;
		if ( $dbg ) { print "  norm map.1: $norm\n" }
	}
	if ( $norm =~ /(map([234])k)/i ) {
		my $old = $1;
		my $nk = $2;
		$norm =~ s/\bkinase\b//g;
		my $new = "mtomap";
		for my $k ( 1..$nk ) {
			$new .= " kinase";
		}
		$norm =~ s/$old/$new /;
		if ( $dbg ) { print "  norm map.2: $norm\n" }
	}
	elsif ( $norm =~ /(map(k+))/ ) {
		my $old = $1;
		my $nk = length ( $2 );
		$norm =~ s/\bkinase\b//g;
		my $new = "mtomap";
		for my $k ( 1..$nk ) {
			$new .= " kinase";
		}
		$norm =~ s/\b$old/$new /;
		if ( $dbg ) { print "  norm map.3: $norm\n" }
	}
	elsif ( $norm =~ /\bmap/i && "$norm $assumed" =~ /kinase/i ) {
		$norm =~ s/\bmap/mtomap/g;
		if ( $dbg ) { print "  norm map.4: $norm\n" }
	}
	if ( $dbg ) { print "  norm map final: $norm\n" }

	# kinase..kinase
	$norm =~ s/\bproteins*[- ]*kinase/kinase/g;
	if ( $norm =~ /\bkinase[- ]*kinase[- ]*kinase[- ]*kinase\b/ ) {
		$norm =~ s/\bkinase[- ]*kinase[- ]*kinase[- ]*kinase\b/KFOUR kinase/;
		if ( $dbg ) { print "  norm KKKK: $norm\n" }
	}
	elsif ( $norm =~ /\bkinase[- ]*kinase[- ]*kinase\b/ ) {
		$norm =~ s/\bkinase[- ]*kinase[- ]*kinase\b/KTHREE kinase/;
		if ( $dbg ) { print "  norm KKK: $norm\n" }
	}
	elsif ( $norm =~ /\bkinase[- ]*kinase\b/ ) {
		$norm =~ s/\bkinase[- ]*kinase\b/KTWO kinase/;
		if ( $dbg ) { print "  norm KK: $norm\n" }
	}
	
	if ( $norm =~ /mtomap/ && $norm !~ /(KTWO|KTHREE|KFOUR)/ ) {
		$norm .= " KONE";
	}
	
	# AGC kinase
	if ( "$norm $assumed" =~ /kinase/ ) {
		$norm =~ s/\bagc([0-9]*)\b/AGCk $1/g;
	}
	
	# tyrosine or serine/threonin kinase or dual specificity
	if ( "$norm $assumed" =~ /kinase/ ) {
		$norm =~ s/\btyrosine\b/TYK/g;
		$norm =~ s/\bser[a-z]*[^a-z0-9]*thr[a-z]*\b/STK/g;
		$norm =~ s/\bdual\b/TYKSTK/g;

	# other kinase acronyms
		$norm =~ s/\bcdc([1-9]*)/cellcycle $1/g;
		$norm =~ s/\bcdk([1-9]*)/cellcycle cyclin dependent $1/g;
		$norm =~ s/\bcdpk([1-9]*)/calcium dependent $1/g;
		$norm =~ s/\brlk/receptor like $1/g;
	}
	$norm =~ s/  +/ /g;
	if ( $dbg ) { print "  norm kinase: $norm\n" }
#$dbg = 0;

	# auxins
	$norm =~ s/\bindole.{0,5}acetic( *acids*)*/iaa/gi; 
	$norm =~ s/\biaa/auxiniaa/g;
	$norm =~ s/\bauxiniaa([^ ])/auxiniaa $1/g;

	# protein mnemoninc
	while ( $norm =~ /($protypes|$enzymes) *([^#!;, ]+)([\/;,]|$)/i ) {
		my $protid = $2;
		if ( $protid =~ /[a-z]/i && $protid =~ /[0-9]/ && $protid !~ /kDa/ && length( $protid ) <= 8 ) {
			$protid =~ s/[^a-z0-9]/#/gi;
			$protid =~ s/([a-z])([0-9])/$1#$2/gi;
			$protid =~ s/([0-9])([a-z])/$1#$2/gi;
			$protid = "#$protid#";
			$protid =~ s/##+/#/g;
			$norm =~ s/($protypes|$enzymes) *([^#!;, ]+)([\/;,]|$)/$1 $protid$3/i;
		}
		else {
			$norm =~ s/($protypes|$enzymes) *([^#!;, ]+)([\/;,]|$)/$1 !$2$3/i;
		}
		if ( $dbg ) { print "  norm isoform#: $norm\n" }
	}
	$norm =~ s/!//g;
	$norm =~ s/,+$//;
	
	# non-, make sure non-XYZ does not match XYZ
	while ( $norm =~ /\bnon-([a-zA-Z0-9]+)\b/ ) {
		my $new = "NON" . uc( $1 );
		$new =~ s/RECEPTOR/receptor/;
		$norm =~ s/\bnon-([a-zA-Z0-9]+)\b/$new/;
	}
	$norm =~ s/non-/non/g;
	$norm =~ s/\bindependent\b/inDEPENDENT/gi;
	if ( $dbg ) { print "  norm non-: $norm\n" }
	
	# poly- retro- co- anti- sub- super- pro- con- counter- multi- iso-
	$norm =~ s/\b(poly|retro|co|anti|sub|super|pro|con|counter|multi|iso)-/$1/g;
#print "  xxx-: $norm\n";
	if ( $dbg ) { print "  norm co-: $norm\n" }

	# 5'-3', 3'-5'
	$norm =~ s/5'3/5,3/g;
	$norm =~ s/3'5/3,5/g;
	$norm =~ s/5'/5/g;
	$norm =~ s/3'/3/g;
	$norm =~ s/\b5-3\b/ #5-#-3# /g;
	$norm =~ s/\b3-5\b/ #3-#-5# /g;
	$norm =~ s/^ +//;
	$norm =~ s/ +$//;
	$norm =~ s/  +/ /g;
	if ( $dbg ) { print "  norm 5-3: $norm\n" }

	# coenzymes	
	$norm =~ s/\bcoa\b/COa/g;
	$norm =~ s/\bcoq10/COq/g;
	$norm =~ s/\bcoenzyme *([a-z])\b/CO$1/g;
	$norm =~ s/\bcoenzyme *q-*10\b/COq/gi;
	if ( $dbg ) { print "  norm coenz: $norm\n" }
	
	# -like/related
	$norm =~ s/-(like|related)/ $1/g;
	if ( $dbg ) { print "  norm -like: $norm\n" }

	# B-5 (etc)
	$norm =~ s/^([a-z])-([0-9]) /$1$2 /;
	$norm =~ s/ ([a-z])-([0-9])$/ $1$2/;
	$norm =~ s/ ([a-z])-([0-9]) / $1$2 /g;
	if ( $dbg ) { print "  norm A-9: $norm\n" }

	# NAD(P)
	$norm =~ s/\bnad\((p|h|ph)\)/nad$1/g;
	$norm =~ s/\bnad\[(p|h|ph)\]/nad$1/g;
	
	# abscisic acid
	$norm =~ s/\babscisic[- ]acids*\b/abaacid/gi;
	
	# cell-cycle
	$norm =~ s/\bcell[- ]*cycle/cellcycle/gi;
	if ( $dbg ) { print "  norm NAD/ABA/cell-cyc: $norm\n" }
	
	# replication factor
	$norm =~ s/replication[- ]*([a-z])[- ]*(factor|protein)[- ]*([1-9]*)\b/replication factor $1$3/g;
	$norm =~ s/replication[- ]*([a-z]-*[1-9]*)[- ]*(factor|protein)\b/replication factor $1/g;
	$norm =~ s/replication[- ]*(factor|protein)[- ]*([a-z]-*[1-9]*)*\b/replication factor $2/g;
	$norm =~ s/replication[- ]*protein/replication factor/g;
	if ( $norm =~ /replication factor a *1\b/ ) { $norm .= " rpa1" }
	elsif ( $norm =~ /replication factor a\b/ ) { $norm .= " rpa" }
	else { $norm =~ s/\brp(a1*)\b/replication factor $1/g }
	if ( $dbg ) { print "  norm repli: $norm\n" }
	
	# disease resistance
	$norm =~ s/\bblight\b/blightdisease/g;
	$norm =~ s/disease[- ]*disease/disease/g;
	$norm =~ s/disease[- ]*resist/diseaseresist/g;
	if ( $dbg ) { print "  norm disease: $norm\n" }
	
	# receptor
	$norm =~ s/receptor/RECEPTOR/g;
	$norm =~ s/acceptor/ACCEPTOR/g;
	if ( $dbg ) { print "  norm rec: $norm\n" }

	# try to preserve features like (L)/3,4/1-/-3- in chemical names
	$norm =~ s/\(([a-z0-9])\)/-$1-/g;
	$norm =~ s/\[([a-z0-9])\]/-$1-/g;
	$norm =~ s/(-[a-z]-)/- $1 -/g;
	$norm =~ s/\b([a-z]-)/$1 -/g;
	$norm =~ s/(-[a-z])\b/- $1/g;
	$norm =~ s/(-[0-9])/- $1/g; 
	$norm =~ s/([0-9]-)/$1 -/g;
	$norm =~ s/([a-z][0-9]+)-/$1 /g;
	$norm =~ s/-([0-9]+[a-z])/ $1/g;
	$norm =~ s/([a-z]{2,})-/$1 /g;
	$norm =~ s/-([a-z]{2,})/ $1/g;
	if ( $dbg ) { print "  norm chem: $norm\n" }

	# special handling for specific gene symbols
	$norm =~ s/\b(dinA|DinA)\b/polB/g;
	if ( $dbg ) { print "  norm gsym: $norm\n" }

	# slashes
	while ( $norm =~ / +([|\/\\]) +/ ) {
		$norm =~ s/ +([|\/\\]) +/ /;
#print "  slashes: $norm\n";
	}
	if ( $dbg ) { print "  norm slash: $norm\n" }
	
	# VAMP/SNARE/Synaptobrevin
	$norm =~ s/synaptobrevin/VAMP synaptobrevin/;
	$norm =~ s/vesicle[- ]*associated[- ]*membrane/VAMP/gi;
	$norm =~ s/\bvamp([0-9]*)\b/VAMP$1/gi;
	$norm =~ s/VAMP/snare VAMP/g;
	
	# ============================================================
	# ============================================================
	# ============================================================
	# standardize punctuation to "-" (within words) and blank (between words)
	# (preserve special character #)
	# after we can assume blanks between words
	{
		if ( $dbg ) { print "    norm pre-punct: $norm\n" }
		$norm =~ s/[^#a-z0-9]([a-z]{2,})/ $1/gi;
		if ( $dbg ) { print "    norm spacing-punct: $norm\n" }
		my @words = split / +/, $norm;
		my $tmp = " ";
		for my $word ( @words ) {
			$word =~ s/,+$//;
			$word =~ s/^,+//;
			if ( $word !~ /[a-z0-9]/i ) { next }
			if ( $word =~ /\W*([0-9.]+kD)\W*/ ) {
				$word = "$1";
				$word = "#$word#";
				if ( $dbg ) { print "    norm punct kDa: $word\n" }
			}
			elsif ( $word =~ /#/ ) {
				$word =~ s/[^#a-z0-9]/#/gi;
				$word =~ s/##+/#/g;
				if ( $dbg ) { print "    norm punct #: $word\n" }
			}
			elsif ( $word =~ /(-[0-9]|[0-9]-|-[a-z0-9]-|[0-9],[0-9])/ ) {
				$word =~ s/,,+/,/g;
				$word =~ s/,+-/-/g;
				$word =~ s/-,+/-/g;
				if ( $word =~ /,/ ) {
					$word =~ s/-//g;
				}
				else {
					$word =~ s/--+/-/g;
				}
				if ( $dbg ) { print "    norm punct -/,: $word\n" }
			}
			elsif ( $word =~ /^[a-z]-$/ || $word =~ /^-[a-z]$/ ) {
			}
			elsif ( $word =~ /[0-9]/ && $word =~ /[a-z]/ && length( $word ) <= 8 ) {
				$word =~ s/\W+/#/g;
				$word =~ s/([a-z])([0-9])/$1#$2/g;
				$word =~ s/([0-9])([a-z])/$1#$2/g;
				$word =~ s/^#+//;
				$word =~ s/##+/#/g;
				$word =~ s/#+$//;
				$word = "#$word#";
				if ( $dbg ) { print "    norm punct 9A: $word\n" }
			}
			else {
				$word =~ s/\W+$//;
				$word =~ s/^\W+//;
				$word =~ s/\W+/ /g;
				$word =~ s/([a-z])([0-9])/$1 $2/g;
				$word =~ s/([0-9])([a-z])/$1 $2/g;
				if ( $dbg ) { print "    norm punct 9 A: $word\n" }
			}
			$tmp .= $word . " ";
		}
		$norm = $tmp;
	}	
	$norm =~ s/  +/ /g;
	$norm =~ s/^ +//;
	$norm =~ s/ +$//;
	if ( $dbg ) { print "  norm final punct: $norm\n" }

	# ============================================================
	# ============================================================
	# ============================================================

	# strip extraneous use of protein
	$norm = strip_protein( $norm );
	$norm =~ s/protein\b/ptn/g;
#print "  strip: $norm\n";
	$norm =~ s/  +/ /g;
	$norm =~ s/^ +//;
	$norm =~ s/ +$//;
	if ( $dbg ) { print "  norm strip pro: $norm\n" }
	
	# cell cycle
	$norm =~ s/\bcell *division *cycle/cellcycle/g;
	$norm =~ s/\bcell *division/cellcycle/g;
	$norm =~ s/\bcell *cycle/cellcycle/g;
	$norm =~ s/\bcellcycle *control/cellcycle CYCLIN/g;
	$norm =~ s/\bcyclin([0-9]*)\b/cellcycle CYCLIN $1/g;

	# transposable elements
	$norm =~ s/\bpol([0-9]*)\b/POL$1/i;
	if ( $norm =~ /\b(copia|ty3[-:.\/ ]*gypsy|pao[-:.\/ ]*bel|ltr)\b/ && ( $norm !~ /retro/ || $norm !~ /transponson/ ) ) {
		$norm =~ s/\b(copia|ty3[-:.\/ ]*gypsy|pao[-:.\/ ]*bel|ltr)\b/$1 retrotransposon/;
	}
	
	$norm =~ s/\bretro *tra*ns*pos[a-z]*[- ]*elem[a-z]*\b/rtrotrnposn/g;
	$norm =~ s/\bretro *elem[a-z]*b/rtrotrnposn/g;
	$norm =~ s/\bretro *tra*ns*pos[a-z]*\b/rtrotrnposn/g;
	$norm =~ s/\btra*ns*pos[a-z]* *elem[a-z]*\b/trnposn/g;
	$norm =~ s/\btra*ns*pos[a-z]*\b/trnposn/g;
	if ( $norm =~ /rtrotrnposn\b/ && $norm !~ /reverse[- ]*transcript/ ) {
		$norm .= " reverse transcriptase";
	}
	$norm =~ s/\bopie([0-9a-z]{0,2})\b/oPie$1/gi;
	if ( $dbg ) { print "  norm TE: $norm\n" }

	# serpins	
	$norm =~ s/\bserpins\b/serpin/g;
	$norm =~ s/inhibitors\b/inhibitor/g;
	$norm =~ s/serine protease inhibitor/serpin/g;
	
	# amino acids
	while ( $norm =~ /\b($aminoacids) *($aminoacids)\b/ ) {
		 $norm =~ s/\b($aminoacids) *($aminoacids)\b/$1ptn$2ptn/;
#print "while12: $norm\n";
#print "  aminoacid1: $norm\n";
	}
	while ( $norm =~ /\b($aminoacids)\b/ ) {
		 $norm =~ s/\b($aminoacids)\b/$1ptn/;
#print "while12: $norm\n";
#print "  aminoacid1: $norm\n";
	}
	$norm =~ s/ineptn\b/ptn/g;
	$norm =~ s/ *acidptn\b/ptn/g;
	$norm =~ s/ptn rich\b/ptnrich/g;
	if ( $dbg ) { print "  norm AA: $norm\n" }

	# C/N-termal/terminus
	$norm =~ s/\b(c|carboxy|carboxyl|cooh) *term[inalus]*/CTM/g;
	$norm =~ s/\b(n|amino|amine|nh2) *term[inalus]*/NTM/g;
	$norm =~ s/\b(CTM|NTM) *domain/$1/g;
	if ( $dbg ) { print "  norm term: $norm\n" }
	
	# some common synonyms
	$norm =~ s/\bsynthetase\b/ligase/g;
	$norm =~ s/\bsynthetase\b/ligase/g;

	$norm =~ s/\b(proteinase|protease|peptidase)\b/prtnase/g;
	
	$norm =~ s/\bsterile *alpha *motif\b/sam/g;
	
	$norm =~ s/\batp *binding *cassette\b/abc/g;
	if ( $dbg ) { print "  norm synonyms: $norm\n" }
	
	# DNA/RNA polymerase
	$norm =~ s/rna +polymerase/rnapolase/g;
	$norm =~ s/rna +replicase/rnapolREPLICase/g;
	$norm =~ s/reverse +transcriptase/dnapolREVTRNase/g;
	$norm =~ s/dna +polymerase/dnapolase/g;
	
	$norm =~ s/\b(rnap|rnapol)\b/rnapolase/g;
	$norm =~ s/\b(rnap|rnapol)([0-9]|$greek|$roman)\b/rnapolase $2/g;
	$norm =~ s/\bdna *(dependent|directed|instructed) *rna *polymerase/rnapolase/g;

	$norm =~ s/\b(rdrp|rdr)\b/rnapolREPLICase/g;
	$norm =~ s/\b(rdrp|rdr)([0-9])/rnapolREPLICase $2/g;
	$norm =~ s/\brna *(dependent|directed|instructed) *rna *polymerase/rnapolREPLICase/g;

	$norm =~ s/\brna *(dependent|directed|instructed) *dna *polymerase/dnapolREVTRNase/g;
	$norm =~ s/\brddp\b/dnapolREVTRNase/g;

	$norm =~ s/\bdna *(dependent|directed|instructed) *dna *polymerase/dnapolase/g;
	$norm =~ s/\bdddp\b/dnapolase/g;
	$norm =~ s/\bpol *(b|i|ii|iii|iv|v|[1-5]|greek|rev1)\b/dnapolase $1/g;
	if ( $dbg ) { print "  polymerase: $norm\n" }

	# expressed
	$norm =~ s/\b($strength) *expressed *protein\b//g;
	$norm =~ s/\bexpressed *protein\b//g;
	$norm =~ s/\b($strength) *expressed\b//g;
	$norm =~ s/\bexpressed\b//g;
	if ( $dbg ) { print "  norm express: $norm\n" }
	
	# regulators
	$norm =~ s/\b(react|induc|trigger+|trigg|stimulat*|elicit)(s|es|ed|er|e|ing|ive|ing|ion|or|[ai]ble)\b/RESPONSE/g;
	$norm =~ s/\brespon[ds][a-z]*\b/RESPONSEREGULAT/g;
	
	$norm =~ s/regulat[a-z]+\b/REGULAT/g;
	$norm =~ s/\bup *regulat\b/upREGULAT/g;
	$norm =~ s/\bactivat[a-z]+\b/upREGULAT/g;
	$norm =~ s/\bpromot[a-z]+\b/upREGULAT/g;
	$norm =~ s/\bdown *regulat\b/downREGULAT/g;
	$norm =~ s/\binhibit[a-z]*\b/downREGULAT/g;
	$norm =~ s/\brepress[a-z]*\b/downREGULAT/g;
	$norm =~ s/\bsup+res+[a-z]*\b/downREGULAT/g;
	if ( $dbg ) { print "  norm regulate: $norm\n" }

	# transcription factor
	$norm =~ s/transcrib[a-z]+/transcription/g;
	$norm =~ s/transcription[a-z]+/transcription/g;
	$norm =~ s/transcriptional/transcription/g;
	$norm =~ s/\bRESPONSEREGULAT *factor\b/RESPONSEREGULAT transcription factor/g;
	if ( $norm =~ /\bRESPONSEREGULAT/ ) {
		$norm =~ s/element *binding *factor/transcription factor/g;
		$norm =~ s/element *binding/transcription factor/g;
	}
	$norm =~ s/transcription *factor/transcription factor/g;
	if ( $norm =~ /transcription/  && $norm !~ /factor/ ) {
		if ( $norm =~ /\b[a-z]*REGULAT\b/ ) {
			$norm =~ s/transcription/transcription factor/;
		}
	}
	$norm =~ s/transcription/XSCRIPT/g;
	$norm =~ s/XSCRIPT factor/XSCRIPTREGULAT factorDNUCBINd/g;
	$norm =~ s/\bno[- ]*apical[- ]*meristem\b/nam/g;

	# ignore these words
	for my $ignore
		( "express[edsiong]*", "encoded *by", "containing", "putative",
			"proteins*", "genes*", "ests*", "cdnas*", "orfs*",
			"variants*", "isoforms*", "members*",
			"activit[yies]+|acting" ) {
		$norm =~ s/\b$ignore\b//g;
	}
	if ( $dbg ) { print "  norm ignore: $norm\n" }
	
	# standardized words that essentially mean "like"
	for my $homolog (
			"like", "related", "similar[a-z]*", "homolog[a-z]*", "ortholog[a-z]*", "paralog[a-z]*" ) {
		$norm =~ s/\b$homolog\b/lFAM/g;
	}
	
	# domains/families
	$norm =~ s/\blrr\b/leucptnrich repeat/g;
	$norm =~ s/($simpledomains)/ dFAM /g;
	$norm =~ s/subfamily/ pFAM /g;
	$norm =~ s/superfamily/ pFAM /g;
	$norm =~ s/family/ pFAM /g;
	$norm =~ s/\b($groups)/gFAM /g;
	$norm =~ s/  +/ /g;
	if ( $dbg ) { print "  norm FAM: $norm\n" }
	
	# f-box/k-box/s-box
	$norm =~ s/\bf[- ]*box/Fbox/g;
	$norm =~ s/\bk[- ]*box/Kbox/g;
	$norm =~ s/\bs[- ]*box/Sbox/g;
	while ( $norm =~ /\b([a-z]) *- *box\b/ ) {
		my $box = uc( $1 ) . "box";
		$norm =~ s/\b([a-z]) *- *box\b/$box/gi;
	}
	if ( $dbg ) { print "  norm box: $norm\n" }

#	# DNA/RNA/ATP/CAMP/AMP/FAD/SAM directed/dependent/instructed
#	while ( $norm =~ /\b(dna|rna|atp|camp|amp|fad|sam) *(depend|direct|instruct)[edionsng]+\b/ ) {
#		my $new = uc ( $1 );
#		$new =~ s/\W//g;
#		$norm =~ s /\b(dna|rna|atp|camp|amp|fad|sam) *(depend|direct|instruct)[edionsng]+\b/$new/;
##print "  XXX-depend: $norm\n";
##print "while15: $norm\n";
#	}
	
	# DNA/RNA implies nuclear acid
	$norm =~ s/\b(d|r|[a-z]{1,3}r)na\b/$1NUC/g;
	$norm =~ s/\bnucl[earic]{3,}[- ]*acid\b/NUC/g;
	if ( $dbg ) { print "  norm nuc: $norm\n" }
	
	# binding
	$norm =~ s/\bbinding/BIND/g;
	
	# transporters
	# co-transporter, symporter, antiporter, exchanger, carrier
	$norm =~ s/\bcotransport[a-z]*/COTport/g;
	$norm =~ s/\bsymport[a-z]*/COTPORT/g;
	$norm =~ s/\bcountertransport[a-z]*/ANTIPORT/g;
	$norm =~ s/\bexchange[a-z]*/ANTIPORT/g;
	$norm =~ s/\bcarry[a-z]*/CARPORT/g;
	$norm =~ s/\bcarrie[a-z]*/CARPORT/g;
	$norm =~ s/\bexport[a-z]*/EXPORT/g;
	$norm =~ s/\bimport[a-z]*/IMPORT/g;
	$norm =~ s/\bsecret[a-z]*/SECPORT/g;
	$norm =~ s/\btransport[a-z]*/TRANSPORT/g;
	$norm =~ s/\befflux/EFFPORT/g;
	if ( $norm =~ /\bmate/ && $norm =~ /PORT/ && $norm !~ /multidrug/ ) {
		$norm =~ s/\bmate/multidrug mate/g;
	}
	if ( $dbg ) { print "  norm porter: $norm\n" }

	# standardize sugars
	$norm =~ s/\b([a-z]{3,})ose\b/$1SUGR/gi;
	$norm =~ s/\b(monos|di)s*ac+har+ides*/$1SUGR/gi;
	$norm =~ s/\bsugars*/SUGR/g;
	if ( $dbg ) { print "  norm sugar: $norm\n" }

	# convert Roman numerals to numbers
	my $arabic = 0;
	$norm =~ s/viii/ #8# /g;
	$norm =~ s/iii/ #3# /g;
	$norm =~ s/vii/ #7# /g;
	$norm =~ s/xii/ #12# /g;
	for my $r ( "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix" ) {
		$arabic++;
		$norm =~ s/#$r#/#$arabic#/g;
		$norm =~ s/\b($r)\b/ #$arabic# /g;
	}
#	$norm =~ s/#([^\W#]+) /$1#/g;
#	$norm =~ s/ ([^\W#]+)#/#$1/g;
	$norm =~ s/  +/ /g;
	$norm =~ s/^ +//;
	$norm =~ s/ +$//;
	if ( $dbg ) { print "  norm roman: $norm\n" }

	# highlight greek letters
	if ( $norm =~ /($greek)/i ) {
		my $tmp = "";
		for my $word ( split / +/, $norm ) {
			for my $grk ( split /\|/, $greek ) {
				if ( length( $grk ) > 3 ) {
					$word =~ s/$grk/ $grk /g;
				}
				else {
					$word =~ s/([0-9])$grk/$1 $grk/g;
					$word =~ s/$grk([0-9])/$grk $1/g;
				}
			}
			$word =~ s/^ +//;
			$word =~ s/ +$//;
			$word =~ s/  +/ /g;
			if ( $word =~ /#/ ) {
				$word =~ s/ /#/g;
				$word =~ s/##+/#/g;
			}
			if ( $tmp gt "" ) { $tmp .= " " }
			$tmp .= $word;
		}
		if ( $dbg && $norm ne $tmp) { print "  norm greek: $norm => $tmp\n" }
		$norm = $tmp;
	}
	$norm =~ s/# #/#/g;
	if ( $dbg ) { print "  norm greek: $norm\n" }

#	# break at letter-number boundaries
#	while ( $norm =~ /([a-z])([0-9])/i ) {
#		$norm =~ s/([a-z])([0-9])/$1 $2/i;
##print "while17: $norm\n";
#	}
#	while ( $norm =~ /([0-9])([a-z])/i ) {
#		$norm =~ s/([0-9])([a-z])/$1 $2/i;
##print "while18: $norm\n";
#	}

	# remove low meaning words
	$norm =~ s/\b($subunits)\b//gi;
	$norm =~ s/\b($isoforms)\b//gi;
	$norm =~ s/\b($strength)\b//gi;
	if ( $dbg ) { print "  norm low meaning: $norm\n" }

	# special cases
	# no compound words
	$norm =~ s/# +#/#/g;
	if ( $normalization_method > 0 ) {
		$norm =~ s/>//gi;


		# exclude family (domain/related/family/homolog, etc)
		if ( $normalization_method > 1 ) {
			$norm =~ s/\b[a-z]FAM\b//g;
#print "while21: $norm\n";
#print "  special7: $norm\n";
		}
		$norm =~ s/^ +//;
		$norm =~ s/  +/ /g;
		$norm =~ s/ +$//;
	}

	# remove leading/trailing/consecutive blanks
	$norm =~ s/ +ptn *$//;
	$norm =~ s/^ +//;
	$norm =~ s/ +$//;
	$norm =~ s/  +/ /g;
	
	if ( defined $assumed_phrase && $assumed_norm gt "" ) {
		$norm .= " $assumed_norm";
		if ( $dbg ) { print "  norm assumed: $norm\n" }
	}

	my $tmp;
	my %used;
	for my $word ( sort { norm_compare_words( $a, $b ) } split / +/, $norm ) {
		if ( $word =~ /[a-z0-9]/i ) {
			if ( ! exists $used{$word} ) {
				if ( defined $tmp ) { $tmp .= " $word" }
				else { $tmp = $word }
				$used{$word} = 1;
			}
		}
	}
	$norm = $tmp;	
	if ( $dbg ) { print "  norm final: $norm\n" }

	return $norm;
}

sub norm_compare_words {
	my ( $a, $b ) = @_;
	
	my $wa = word_weight( $a );
	my $wb = word_weight( $b );
	
	if ( $wa > $wb ) { return -1 }
	if ( $wa < $wb ) { return 1 }
	
	if ( $a lt $b ) { return -1 }
	if ( $a gt $b ) { return 1 }
	
	return 0;
}


sub get_keywords {
	my ( $in, $normalization_method, $assumed_phrase ) = @_;
	if ( ! defined $normalization_method ) { $normalization_method = 0 }

	my $dbg = 0;

	if ( $dbg ) { print "getkw ($normalization_method): $in\n" }

	my $ksz = 3;	# algorithm needs to be completely rethought if key size is changed
	my $wsz = 4.0;

	my %keywords;

	# standardize name
	my $norm = normalize_name( $in, $normalization_method, $assumed_phrase );
	if ( $dbg ) { print "getkw   norm: $norm\n" }
	if ( $norm !~ /\w/ ) { return undef }

	# split name into words
	my @words = split / +/, $norm;

	# extract keywords from words
	my $pos = 0;

	for my $w ( 0..@words-1 ) {
		$pos = $w;
		my $word = $words[$w];

		# do NOT break numbers into fragments
		if ( $word =~ /kD$/ || $word =~ /^[-+]{0,1}[0-9.]+$/ ) {
			$word =~ s/^+//;
			my $wordwgt = word_weight( $word );
			if ( $dbg ) { print "getkw   $pos: $word  wgt: $wordwgt\n" }
			$keywords{position}{$pos} = $word;
			$keywords{keycnt}{$word}++;
			$keywords{keywgt}{$word} += $wordwgt;
			if ( $dbg ) { print "getkw kDa $pos $word  k: $word  c: $keywords{keycnt}{$word}  w: $keywords{keywgt}{$word}\n" }
		}
		elsif ( $word =~ /#/ ) {
			my $wordwgt = 0.75;
			if ( $word =~ /^##/ ) {
				$wordwgt = 0.33
			}
			if ( $dbg ) { print "getkw   $pos: $word  wgt: $wordwgt\n" }
			my %parts;
			my $totalshares = 0;
			my $sharescale = 1.0;
#print "#word: $word\n";
			for my $part ( split /#/, $word ) {
				if ( $part !~ /[a-z0-9]/i ) { next }
				if ( $part =~ /^($greek|$roman|[a-z])$/i ) {
					$parts{$part}{position}{$pos} = 1;
					my $shares = $sharescale * word_weight( $part );
					$parts{$part}{shares} += $shares;
					$totalshares += $shares;
#print "  scale: $sharescale  part: $part  shares: $shares\n";
				}
				elsif ( $part =~ /[a-z]/i ) {
					my $fragcnt = max( 1, length( $part ) - $ksz + 1 );
					my $shares = $sharescale * word_weight( $part );
					$shares = $shares / $fragcnt;
#print "  scale: $sharescale  part: $part  shares: $shares\n";
					for my $c ( 0..$fragcnt-1 ) {
						my $kw = substr( $part, $c, $ksz );
						$parts{$kw}{position}{$pos} = 1;
						$parts{$kw}{shares} += $shares;
						$totalshares += $shares;
						$pos += 0.01;
					}
				}
				elsif ( $part =~ /^[-+0-9.]$/ ) {
					$part =~ s/^+//;
					$parts{$part}{position}{$pos} = 1;
					my $shares = $sharescale * word_weight( $part );
#print "  scale: $sharescale  part: $part  shares: $shares\n";
					$parts{$part}{shares} += $shares;
					$totalshares += $shares;
				}
				else {
					$parts{$part}{position}{$pos} = 1;
					my $shares = $sharescale * word_weight( $part );
#print "  scale: $sharescale  part: $part  shares: $shares\n";
					$parts{$part}{shares} += $shares;
					$totalshares += $shares;
				}
				$pos += 0.1;
				$sharescale = 0.5 * $sharescale;
			}
			for my $kw ( keys %parts ) {
				for my $pos ( keys %{ $parts{$kw}{position} } ) {
					$keywords{position}{$pos} = $kw
				}
				$keywords{keycnt}{$kw}++;
				my $wgt = $wordwgt * $parts{$kw}{shares} / $totalshares;
#print "  kw: $kw  shares: $parts{$kw}{shares} / $totalshares  wgt: $wgt\n";
				$keywords{keywgt}{$kw} += $wgt;
			if ( $dbg ) { print "getkw #   $pos $word  k: $kw  c: $keywords{keycnt}{$kw}  w: $keywords{keywgt}{$kw}\n" }
			}
		}
		elsif ( $word =~ /^($greek|$roman|$kingdoms)$/i ) {
			my $wordwgt = word_weight( $word );
			if ( $dbg ) { print "getkw   $pos: $word  wgt: $wordwgt\n" }

			$keywords{position}{$pos} = $word;
			$keywords{keycnt}{$word}++;
			$keywords{keywgt}{$word} += $wordwgt;
			if ( $dbg ) { print "getkw wd  $pos $word  k: $word  c: $keywords{keycnt}{$word}  w: $keywords{keywgt}{$word}\n" }
			
		}

		# weight non-numeric words by length
		# and break into fragments
		else {

			# full word requires 4 characters
			my $wordwgt = word_weight( $word );
			if ( $dbg ) { print "getkw   $pos: $word  wgt: $wordwgt\n" }
			
			# flag families
			if ( $word =~ /\b(...)fam\b/ ) { $keywords{family}{$1}++ }		

			# break word into fragments
			my $fragcnt = max( 1, length( $word ) - $ksz + 1 );
			my $wgt = $wordwgt / $fragcnt;
			for my $c ( 0..$fragcnt-1 ) {
				my $kw = substr( $word, $c, $ksz );
	
	#			if ( ! exists $keywords{keycnt}{$kw} ) { $keywords{position}{$pos} = $kw }
				$keywords{position}{$pos} = $kw;
	
				$keywords{keycnt}{$kw}++;
				$keywords{keywgt}{$kw} += $wgt;
				if ( $dbg ) { print "getkw wd  $pos $word  k: $kw  c: $keywords{keycnt}{$kw}  w: $keywords{keywgt}{$kw}\n" }
				$pos += 0.01;
			}
		}
	}
	$keywords{namewgt} = 0.0;
	for my $kw ( keys %{ $keywords{keywgt} } ) {
		$keywords{keywgt}{$kw} = $keywords{keywgt}{$kw} / $keywords{keycnt}{$kw};
		$keywords{namewgt} += $keywords{keywgt}{$kw};
	}
	delete $keywords{keycnt};
	$keywords{normalized} = $norm;

	return \%keywords;
}

sub word_weight {
	my ( $word ) = @_;

	my $wordwgt;

	if ( $word =~ /(kinase|RECEPTOR|PORT$)/i ) {
		$wordwgt = 1.25;
	}
	elsif ( $word eq "CTM" || $word eq "NTM" ) {
		$wordwgt = 1.15;
	}
	elsif ( $word =~ /^([dr]NUC|bind|membran[a-z]+)$/i ) {
		$wordwgt = 0.75;
	}
	elsif ( $word =~ /#/ ) {
		$wordwgt = 0.75;
	}
	elsif ( $word =~ /^(STK|TYK)$/ ) {
		$wordwgt = 0.5;
	}
	elsif ( $word =~ /ptn.*rich$/i ) {
		$wordwgt = 0.25;
	}
	elsif ( $word =~ /kD$/ ) {
		$wordwgt = 0.25;
	}
	elsif ( $word =~ /^($minorwords)$/i ) {
		$wordwgt = 0.20;
	}
	elsif ( $word =~ /^($greek|$roman|$kingdoms|$minorwords|[a-z])$/i ) {
		$wordwgt = 0.20;
	}
	elsif ( $word =~ /^[0-9.]+$/ ) {
		$wordwgt = 0.15;
	}
	elsif ( $word =~ /FAM/ ) {
		$wordwgt = 0.125;
	}
	else {

		# full word requires 4 characters
		my $wln = length( $word );
		$wordwgt = minval( 1, $wln / 4.0 );
		if ( $wordwgt >= 3.5 ) {
			$wordwgt = 1.5;
		}
		elsif ( $wordwgt > 2.5 ) {
			$wordwgt = 1.25;
		}
		elsif ( $wordwgt > 1 ) {
			$wordwgt = 1.0;
		}
	
		# reduce influence artificial words/accessions
		if ( $word =~ /[|_]/ ) { $wordwgt = 0.20 }
		
		# treat "non" as a full word 
		elsif ( $word =~ /^(non)$/ ) { $wordwgt = 1.0 }
	}
	
	return $wordwgt;
}

sub base_protein_name {
	my ( $name ) = @_;
	
	my $last = $name;
	my $next = parent_protein_name( $last );
	while ( $last ne $next ) {
#print "while22: $last|$next\n";
		$last = $next;
		$next = parent_protein_name( $last );
	}
	
	return $last;
}

sub parent_protein_name {
	my ( $name ) = @_;
	my $dbg = 0;
	#if ( $name =~ /general transcription factor/i ) { $dbg = 1 }
	
	my $separators = ",;: \\\|";
	my $proteins = "$protypes";
	
	my $text = $name;
	my $parent;
	my $is_putative = 0;
	if ( $text =~ /, putative$/ ) {
		$is_putative = 1;
		$text =~ s/, putative$//;
	}
	if ( $dbg ) { print "parent0: in $name  putative $is_putative  related: " }
	my $is_related;
	if ( $text =~ /, *\b(related|like)[- ]+($proteins)$/ ) {
		$is_related = $1;
		$text =~ s/, *\b(related|like)[- ]+($proteins)$/$2/;
		if ( $dbg ) { print "$is_related  modified: $text" }
	}
	if ( $dbg ) { print "\n" }

	if ( $text =~ /^(.+)\b($proteins) *([0-9a-z._\/-]+)$/i ) {
		$parent = $1;
		my $protein = $2;
		my $detail = $3;
		if ( $protein =~ /($subunits)/i ) { $protein = "protein" }
		if ( ! is_protein_detail( $detail ) ) {
			$parent = $name;
		}
		else {
			if ( defined $is_related ) {
				$parent .= ", $is_related $protein";
			}
			else {
				$parent .= "$protein";
			}
			if ( $is_putative ) {
				$parent .= ", putative";
			}
		}
		if ( $dbg ) { print "parent1: $name => $parent\n" }
	}
	elsif ( $text =~ /^(.+[, ]+(family|subfamily|superfamily) +[a-z0-9]+)[-.\/_:][0-9a-z]+ +($proteins)$/i ) {
		$parent = "$1 $3";
		my $detail = $2;
		if ( ! is_protein_detail( $detail ) ) {
			$parent = $name;
		}
		else {
			$parent =~ s/ ($subunits)$/ protein/i;
			if ( $is_putative ) {
				$parent .= ", putative";
			}
		}
		if ( $dbg ) { print "parent2: $name => $parent\n" }
	}
	elsif ( $text =~ /^(.+[, ]+(family|subfamily|superfamily) +[a-z]{0,3}[0-9]+)[a-z] +($proteins)$/i ) {
		$parent = "$1 $3";
		my $detail = $2;
		if ( ! is_protein_detail( $detail ) ) {
			$parent = $name;
		}
		else {
			$parent =~ s/ ($subunits)/ protein/i;
			if ( $is_putative ) {
				$parent .= ", putative";
			}		
		}
		if ( $dbg ) { print "parent3: $name => $parent\n" }
	}
	elsif ( $text =~ /^(.+)[- ]+($kingdoms) +($proteins)$/i ) {
		$parent = "$1";
		if ( defined $is_related ) {
			$parent .= ", $is_related $3";
		}
		else {
			$parent .= " $3";
		}
		if ( $is_putative ) {
			$parent .= ", putative";
		}		

	}
	elsif ( $text =~ /^(.*\w)[- ]+(($kingdoms)[- ]+(like|related))[- ]+($proteins)$/i ) {
		$parent = $1;
		my $protype = $5;
		if ( $parent !~ /\b($protypes)$/ ) { $parent .= " $protype" }
		if ( $is_putative ) {
			$parent .= ", putative";
		}		

	}
	elsif ( $text =~ /[- ]+[0-9a-z]{1,2}[- ]+($proteins)$/i ) {
		my $protype = $1;
		if ( $protype =~ /($subunits)/i ) { $protype = "protein" }
		$parent = $text;
		$parent =~ s/[- ]+[0-9a-z]{1,2}[- ]+($proteins)$//i;
		$parent =~ s/ *($groups) *$//i;
		if ( defined $is_related ) {
			$parent .= "-$is_related $protype";
		}
		else {
			$parent .= " $protype";
		}
		if ( $is_putative ) {
			$parent .= ", putative";
		}		
	}
	elsif ( $text =~ /^(.+)[, ]+($kingdoms)$/i ) {
		$parent = $1;
		if ( $is_putative ) {
			$parent .= ", putative";
		}		

	}
	elsif ( $text =~ /^(.+)[$separators]+\([^()]*\)$/ ) {
		$parent = $1;
		my $detail = $2;
		if ( $parent =~ /(family|$groups)$/i ) {
			$parent = $name;
		}
		elsif ( ! is_protein_detail( $detail ) ) {
			$parent = $name;
		}
		else {
			$parent =~ s/ *($groups) *$//i;
			$parent =~ s/[$separators]+$//;
			$parent =~ s/ ($subunits)$/ protein/i;
			if ( $parent =~ /[a-z]/i ) {
				if ( defined $is_related ) {
					$parent .= ", $is_related protein";
				}
				if ( $is_putative ) { $parent .= ", putative" } 
			}
			else {
				$parent = $name;			
			}
		}
		if ( $dbg ) { print "parent9: $name => $parent\n" }
	}
	elsif ( $text =~ /^(.+)[$separators]([-_\/.a-z0-9]+)$/i ) {
		$parent = $1;
		my $detail = $2;
		$parent =~ s/ ($subunits)$/ protein/i;
		if ( ! is_protein_detail( $detail ) ) {
			$parent = $name;
		}
		else {
			if ( $detail =~ /^kda$/i ) {
				$parent =~ s/[$separators]+[1-9][.0-9]*//;
			}
			$parent =~ s/ *($groups) *$//i;
			$parent =~ s/[$separators]+$//;
			$parent =~ s/ ($subunits)$/ protein/i;
			if ( defined $is_related ) {
				$parent .= ", $is_related protein";
			}
			if ( $is_putative ) { $parent .= ", putative" } 
		}
		if ( $dbg ) { print "parent10: $name => $parent\n" }
	}

	if ( $dbg ) { print "parent pre: $name => $parent\n" }
	if ( defined $parent && $parent ne $name ) {
		my $rej = rejected_name( $parent );
		if ( $rej ) {
			if ( $dbg ) { print "parent rej ($rej): $parent\n" }
		}
		else {
			$name = $parent;			
		}
	}
	if ( $dbg ) { print "parent11: $name => $name\n" }
	return $name;	
}

sub trimable_protein_detail {
	my ( $detail ) = @_;
	
	if ( $detail =~ /\// ) {
		for my $det ( split /\//, $detail ) {
			if ( ! trimable_protein_detail( $det ) ) { return 0 }
		}
		return 1;
	}
	else {
		if ( $detail =~ /^[A-Za-z][a-z0-9]{2}[A-Z]$/ ) { return 1 }

		$detail =~ s/($kingdoms)/ /gi;
		if ( $detail !~ /[a-z0-9]/i ) { return 1 }

		$detail =~ s/($greek)/1/gi;
		$detail =~ s/\b($roman)\b/1/gi;

		if ( $detail =~ /[a-z]{4,}/ ) { return 0 }
		if ( $detail =~ /[a-z]{6,}/i ) { return 0 }

		if ( $detail =~ /^[A-Z]{1,3}$/ ) { return 1 }
		if ( $detail =~ /^($roman)[a-z]$/i ) { return 1 }
		if ( $detail =~ /[0-9]/ ) { return 1 }
		
		return 0;
	}
}

# return 1 if the text is a minor protein detail
# return 0 if the text is significantly descriptive
sub is_minor_detail {
	my ( $text ) = @_;
	my $dbg = 0;

	my $flag = is_protein_detail( $text );
	if ( $flag == 2 ) { return 1 }
	return 0;	
}

# returns
# 0 - not a detail (part of base name)
# 1 - major detail (don't trim, but skip when checking for valid ending)
# 2 - minor detail (trim and skip)
sub is_protein_detail {
	my ( $text ) = @_;
	my $dbg = 0;

	my $tmp = $text;
	$tmp =~ s/ //g;
	if ( $dbg ) { print "detail in: \"$tmp\"\n" }	

	# remove parens/brackets
	my $parens = 0;
	while ( $tmp =~ /^[\(\[\{](.*)[\)\]\}]$/ ) {
		$tmp = $1;
		$parens = 1;
		if ( $tmp =~ /\b(nadph|nadp|nad)\b/i ) {
			if ( $dbg ) { print "detailPar1 $tmp\n"}
			return 1;
		}
		elsif ( $tmp =~ /[0-9a-z_]/ ) {
			if ( $dbg ) { print "detailPar2 $tmp\n"}
			return 2;
		}
	}

	if ( $text =~ /\// ) {
		my @subtext = split /\/+/, $text; 
		for my $txt ( @subtext ) {
			if ( $txt =~ /\w/ ) {
				if ( $parens ) { $txt = "($txt)" }
				if ( ! is_protein_detail( $txt ) ) { 
					if ( $dbg ) { print "detailCmpd0 $tmp\n"}
					return 0;
				}
			}
		}
		if ( $dbg ) { print "detailCmpd2: $tmp\n" }	
		return 2;
	}
	
	# empty word
	if ( $tmp !~ /\w/ ) {
		if ( $dbg ) { print "detailEmpty $tmp\n"}
		return 2;
	}
	# short word NOT detail
	if ( $tmp =~ /\b($domains|$groups|$enzymes|[a-z]*family|like|related|cell|form|wall|core|cis|bis)\b/i ) {
		if ( $dbg ) { print "detailShrt0: $tmp\n" }	
		return 0;
	}
	# short word detail
	elsif ( $tmp =~ /^(NADPH|NADP|NAD)$/i ) {
		if ( $dbg ) { print "detailShrt1: $tmp\n" }	
		return 1;
	}
	elsif ( $tmp =~ /^($groups|isoforms)$/i ) {
		if ( $dbg ) { print "detailShrt2: $tmp\n" }
		return 2;	
	}
	# gene symbol
	elsif ( length( $tmp ) == 4 && $tmp =~ /[a-z][0-9A-Z]$/ ) {
		if ( $dbg ) { print "detailSym2: $tmp\n" }	
		return 2;
	}	
	# kingdom, eg plant
	elsif ( $tmp =~ /^($kingdoms)$/i ) {
		if ( $dbg ) { print "detailKng2: $tmp\n" }	
		return 2;
	}
	# isoform
	elsif ( $tmp =~ /^($isoforms)$/i ) {
		if ( $dbg ) { print "detailIso2: $tmp\n" }	
		return 2;
	}
	# protein size, e.g. 28.1 kDa
	elsif ( $tmp =~ /^[1-9][0-9.]+[-]*(k|kd|kda)$/ || $tmp =~ /^(kd|kda)$/i ) {
		if ( $dbg ) { print "detailKda2: $tmp\n" }	
		return 2;
	}
	# underscore
	elsif ( $tmp =~ /_/ ) {
		if ( $dbg ) { print "detailUnd2: $tmp\n" }	
		return 2;
	}
	# roman numerals/greek letters (and prime)
	elsif ( $tmp =~ /^($greek|$roman|prime)-*[a-z0-9]{0,1}$/i ) {
		if ( $dbg ) { print "detailRmnGrk1: $tmp\n" }	
		return 1;
	}
	elsif ( $tmp =~ /^[a-z0-9]-*($greek|$roman|prime)$/i ) {
		if ( $dbg ) { print "detailRmnGrk1: $tmp\n" }	
		return 1;
	}
	# family/protein number
	elsif ( $tmp =~ /^[0-9]{1,3}[-\.]*([a-z0-9]|$greek|$roman){0,1}$/i ) {
		if ( $dbg ) { print "detailNum2: $tmp\n" }	
		return 2;
	}
	# letter/acronym
	elsif( $tmp =~ /^[a-z]{1,4}$/i ) {
		if ( $dbg ) { print "detailLtr1: $tmp\n" }	
		return 1;
	}
	# decimal number
	elsif ( $tmp =~ /\.[0-9]/ ) {
		if ( $dbg ) { print "detailDec2: $tmp\n" }	
		return 2;
	}
	# shorter mnemonic
	elsif ( $tmp =~ /^[a-z][0-9]{1,2}[-\.]*[a-z0-9]{0,1}$/i ) {
		if ( $dbg ) { print "detailShMne1: $tmp\n" }	
		return 1;
	}
	# longer mnemomic
	elsif ( $tmp =~ /^[A-Z]{2,}-*[0-9]{1,3}[-\.]*([a-z0-9]|$greek|$roman){0,1}$/i ) {
		if ( length( $tmp ) > 3 ) {
			if ( $dbg ) { print "detailLgMne2: $tmp\n" }	
			return 2;
		}
		if ( $dbg ) { print "detailLgMne1: $tmp\n" }	
		return 1;
	}
	elsif ( $tmp =~ /^[A-Z]{2,}-*[0-9]{1,3}[-\.]*[A-Z0-9]{0,1}$/i ) {
		if ( $dbg ) { print "detailLgMnem2: $tmp\n" }	
		return 2;
	}
	# contains punctation
	elsif ( length( $tmp ) < 8 && $tmp =~ /\w\W+\w/ ) {
		$tmp =~ s/\W//g;
		if ( $tmp =~ /^(nadph|nadp|nad)$/i ) {
			if ( $dbg ) { print "detailPunc1a: $tmp\n" }
			return 1;
		}
		if ( $tmp !~ /[a-z]/ || length( $tmp ) >= 3 ) {
			if ( $dbg ) { print "detailPunc2: $tmp\n" }
			return 2;
		}
		else {
			if ( $dbg ) { print "detailPunc1b: $tmp\n" }
			return 1;
		}	
	}

	# not recognized as a detail
	if ( $dbg ) { print "detail none0 $tmp\n"}
	return 0;
}

sub is_protein_name {
	my ( $text ) = @_;
	
	
	my $test = $text;
	$test =~ s/\W*putative//i;
	$test =~ s/^\W+//;
	$test =~ s/\W+$//;
	
	# cytochrome P450 protein
	if ( $test =~ /^cyp[0-9]+[a-z][0-9]+$/i ) {
#print "is_protein_name 0a: 0, $text\n";
		return 1;
	}
	elsif ( $test =~ /^cyp[0-9]+[a-z]$/i ) {
#print "is_protein_name 0b: 0, $text\n";
		return 0;
	}

	# probably a family
	if ( $test =~ /\bfam/i ) { return 0 } 
	if ( $test =~ /^[a-z]{1,3}[0-9]{1,3}[-0-9a-z]{1,2}$/ ) {
#print "is_protein_name 1: 0, $text\n";
		return 0;
	}

	# punctuation (other than underscores/hyphens/periods) not expected in a specific protein name
	if ( $test =~ /[ ,:;+\/'"(){}\][]/ ) {
#print "is_protein_name 2: 0, $text\n";
		return 0;
	}

	# too general to be a specific protein name, probably a group name
	if ( length( $test ) < 5 && $test !~ /[0-9]/ && $test !~ /[a-z][A-Z]/ ) {
#print "is_protein_name 3: 0, $text\n";
		return 0;
	}

	# a long stretch of lowercase letters is probably a word, not a specific protein name
	if ( $test =~ /[a-z]{6,}/ ) {
#print "is_protein_name 4: 0, $text\n";
		return 0;		
	}

	# two stetches of lowercase letters is probably a phrase, not a specific protein name
	if ( $test =~ /[a-z]{3,}.*[^a-z].*[a-z]{3,}/ ) {
#print "is_protein_name 5: 0, $text\n";
		return 0
	}
	
	# long stretch of letters without any numbers is probably a word, not a specific protein name
	if ( $test =~ /[a-z]{6,}/i && $test !~ /[0-9]/ ) {
#print "is_protein_name 6: 0, $text\n";
		return 0;
	}

	# not a specific protein name if contains a descriptive word
	if ( $test =~ /($goodends)$/i ) {
#print "is_protein_name 7: 0, $text\n";
		return 0;
	}
	if ( $test =~ /\b($domains|$groups|$isoforms|$subunits|like|related|[a-z]*family)\b/i ) {
#print "is_protein_name 8: 0, $text\n";
		return 0;
	}
	if ( $test =~ /^($keeppros)/i ) {
#print "is_protein_name 9: 0, $text\n";
		return 0;
	}

	# passed all the tests, assume it's a specific protein name

#print "is_protein_name 10: 1, $text\n";
	return 1;
}

# remove extraneous use of the word "protein"
sub strip_protein {
	my ( $common_name ) = @_;
	
#print "strip in: $common_name\n";
	$common_name =~ s/\bmembers*\b/\bprotein/gi;
	$common_name =~ s/proteins\b/protein/gi;
	$common_name =~ s/\bprotein *($domains|[a-z]*family)/$1/gi;
	$common_name =~ s/\b([A-Z])[- ]+protein\b/$1-<PTN>/gi;

	my $new = "";
	my $keep = 0;
	for my $word ( reverse split /\b(protein)\b/i, $common_name ) {
#print "  strip tmp0: $word\n";
		if ( $word =~ /^protein$/i ) {
			if ( $keep ) {
				$new = "protein$new";
#print "    strip tmp1: $new\n";
			}
		}
		else {
			$new = "$word$new";
#print "    strip tmp2: $new\n";
		}
		if ( $word =~ /\b($keeppros)\b/i ) {
			$keep = 1;
		}
		elsif ( is_protein_detail( $word ) ) {
		}
		else {
			$keep = 0;
		}
	}
#print "strip tmp: $new\n";
	$new =~ s/-<PTN>/ protein/g;
	
#print "strip out: $new\n";
	return $new;
}

sub standardize_name {
	my ($common_name) = @_;
	my $dbg = 0;

	my $orig = $common_name;
	if ( $dbg ) { print "\nstd in: $common_name\n" }
	
	# quoted name
	if ( $common_name =~ /^ *' *([^']*)  *' *$/ ) {
		$common_name = $1;
	}
	elsif ( $common_name =~ /^ *" *([^"]*)  *" *$/ ) {
		$common_name = $1;
	}
	if ( $dbg ) { print "  std quotes: $common_name\n" }
	
	# unusable UNIREF tags
	if ( $common_name =~ /^ *Function:/i ) {
		if ( $common_name =~ / is +(an|a) +/ ) {
#print "1a \"$orig\" to \"$common_name\"\n";
			$common_name =~ s/^.* is +(an|a) +/putative /;
			$common_name =~ s/ of +the / of /g;
			if ( $common_name =~ /^(.+) +involved +in +(.+)$/ ) {
				$common_name = "$2 $1";
				$common_name =~ s/^ *the *//;
			}
			$common_name =~ s/ +(that +acts|mediating|involved) .*/, putative/;
			$common_name =~ s/ +(and|or) +/\//g;
#print "1b \"$orig\" to \"$common_name\"\n";
			if ( $common_name =~ /s *$/ ) {
				$common_name = "";
			}
			else {
				if ( $common_name =~ /^(.*) +(of|for) +(.*)/ ) {
					$common_name = "$3 $1";
				}
#print "1c \"$orig\" to \"$common_name\"\n";
				if ( $common_name =~ /domain *$/ ) { $common_name .= " protein" }
				if ( $common_name !~ /($goodends)$/i || $common_name =~ /($badends)$/i ) {
					$common_name = "";
				}
#print "1d \"$orig\" to \"$common_name\"\n";
			}
		}
		elsif ( $common_name =~ / is +involved +in / ) {
#print "2a \"$orig\" to \"$common_name\"\n";
			$common_name =~ s/^.* is +involved +in +/putative /;
			$common_name =~ s/^ *the *//;
			$common_name =~ s/ +(and|or) +in / and /g;
			$common_name =~ s/ +(and|or) +/\//g;
#print "2b \"$orig\" to \"$common_name\"\n";
			if ( $common_name =~ /^ *[a-z]+ing / || $common_name =~ /s *$/  ) {
				$common_name = "";
			}
			else {
				$common_name =~ s/ +(into|in|during|for) +.*/, putative/;
#print "2c \"$orig\" to \"$common_name\"\n";
				if ( $common_name =~ /^(.*) +of +(.*)/ ) {
					$common_name = "$2 $1";
				}
				elsif ( $common_name =~ /^ *(resistance|defen[sc]e|protection) +(to|from|against) +(.*)/ ) {
					$common_name = "$3 resistance";
				}
				$common_name .= " protein";
#print "2d \"$orig\" to \"$common_name\"\n";
			}
		}
		else {
			$common_name = "";
		}
#print "\"$orig\" to \"$common_name\"\n";
	}
	elsif ( $common_name =~ /^ *(Pathway|Complex|Similarity|Localization|Remark|Catalytic *Activity):/i ) {
		$common_name = "";
	}
	
	# clustered
	$common_name =~ s/^ *clustered[,:;	]*//i;
	
	# short=, long=, ref=, note=, remark=, common=, synonym=, alias=, product=
	$common_name =~ s/[, ]*(short|long|ref|note|remark|common|synonym|alias|product)=.*//i;

	# small words
	if ( $common_name =~ /kinase/i ) { $common_name =~ s/with[- ]*no[- ]*lysine/WNK/gi }
	if ( $common_name =~ /^ *(or|a|as|to|in|on|of|by|is) +/
			|| $common_name =~ /^ *([Aa]nd|[Tt]he|[Ff]rom|[Ff]or|[Ww]ith|[Hh]a[sd]|[Hh]av(e|ing)|[Ww]as|[Ww]ill|[Ww]ith|[Ss]how(s|ing)|[Ii]nvolv(ed|es|e|ing)) +/ ) {
		$common_name = "";		
	}
	
	# [source/taxonomy]
	$common_name =~ s/\[(source|taxon)[^\]]*\]//i;
	
	# of...origin
	$common_name =~ s/\bof\b.*\borigin\b/ /gi;
	if ( $dbg ) { print "  std of..origin: $common_name\n" }
	
	# plurals
	$common_name =~ s/\b([a-z]{5,})s and ([a-z]{5,})s\b/$1\/$2/g;
	$common_name =~ s/\band enzymes\b//gi;
	$common_name =~ s/families\b/family/gi;
	$common_name =~ s/transposons\b/transposon/gi;
	$common_name =~ s/complexes/complex/gi;
	if ( $dbg ) { print"  std plural0: $common_name\n" }
	while ( $common_name =~ /\b(transcript|antibiotic|flav.noid|saccharid|substance|link|chain|cluster|module|member|compound)s\b/i ) {
		$common_name =~ s/\b(transcript|antibiotic|flav.noid|saccharid|substance|link|chain|cluster|module|member|compound)s\b/$1/i;
		if ( $dbg ) { print"  std plural1: $common_name\n" }
	}
	while ( $common_name =~ /\b(ribosome|vesicle|microtubule|cation|anion|ion|system|[a-z]{3,}(ent|ine|ose|one)|[a-z]{5,}(er|or)|lyase)s\b/i ) {
		$common_name =~ s/\b(ribosome|vesicle|microtubule|cation|anion|ion|system|[a-z]{3,}(ent|ine|ose|one)|[a-z]{5,}(er|or|in)|lyase)s\b/$1/i;
		if ( $dbg ) { print"  std plural2: $common_name\n" }
	}
	while ( $common_name =~ /\b($domains|$groups|$subunits|$homologs|$enzymes|$protypes|$aminoacids|$isoforms)s\b/i) {
		$common_name =~ s/\b($domains|$groups|$subunits|$homologs|$enzymes|$protypes|$aminoacids|$isoforms)s\b/$1/i;
		if ( $dbg ) { print"  std plural3: $common_name\n" }
	}
	if ( $dbg ) { print"  std plural: $common_name\n" }

	# mis/alternate spellings
	$common_name =~ s/\baluminium\b/aluminum/gi;
	$common_name =~ s/\basparate\b/aspartate/gi; 
	$common_name =~ s/\bassembel/assemble/gi;
	$common_name =~ s/\b(biosynth|synth)[ethiscz]+\b/$1esis/gi;
	$common_name =~ s/\bcharacterisation\b/characteriz$1/gi;
	$common_name =~ s/\bcomlpex\b/complex/gi;
	$common_name =~ s/\bcomponenets*/\bcomponent/gi;
	$common_name =~ s/\bconvers\b/confer/gi;
	$common_name =~ s/\bytochrome\b/cytochrome/gi;
	$common_name =~ s/([a-z]{3,})dependent/$1 dependent/gi;
	$common_name =~ s/\bdimeris(ation|ing)\b/dimeriz$a/gi;
	$common_name =~ s/\bdisulph/disulf/gi;
	$common_name =~ s/\b(daomin|domian)s*\b/domain/gi;
	$common_name =~ s/\bendon uclease/endonuclease/gi;
	$common_name =~ s/\bfacors*\b/factor/gi;
	$common_name =~ s/families*\b/family/gi;
	$common_name =~ s/\bhaem\b/heme/gi;
	$common_name =~ s/\bhaem([aeiou])/hem$1/gi;
	if ( $common_name =~ /\b(HIN|NHL)/i && $common_name =~ /\bhairpin\b/ ) {
		$common_name =~ s/\bhairpin\b/harpin/gi;
	}
	$common_name =~ s/([a-z])independent/$1 independent/gi;
	$common_name =~ s/\bkinsaes*\b/kinase/gi;
	$common_name =~ s/\blocalis(ation|ing)\b/localiz$1/gi;
	$common_name =~ s/\bmicrotubles*/microtubule/gi;
	$common_name =~ s/\b([im]*)mobilis(ation|ing)\b/$1mobiliz$1/gi;
	$common_name =~ s/\b(monoxygenase|monooxigenase)s*\b/monooxygenase/gi;
	$common_name =~ s/\bpoly[- ]+proteins*\b/polyprotein/gi; 
	$common_name =~ s/(portein|prtein|protien|protine|proteni|protie|proten|protin|protien[ei]|protein[ei]|protiin|proteen)s*\b/protein/gi;
	$common_name =~ s/\b(puatative|putaitve|puative)/putative/gi;
	$common_name =~ s/\bserin(.)thr/serine$1thr/gi;
	$common_name =~ s/\bsignalling\b/signaling/gi;
	$common_name =~ s/\bsimiliar/similar/gi;
	$common_name =~ s/\bspecificities*\b/specificity/gi;
	$common_name =~ s/sreptomyces/streptomyces/gi;
	$common_name =~ s/\bsulph/sulf/gi;
	$common_name =~ s/\bthreonin\b/threonine/gi;
	$common_name =~ s/toxic +compounds*/toxin/gi;
	$common_name =~ s/\btumours*\b/tumor$1/gi;
	$common_name =~ s/\butilis(ation|ing)\b/utiliz$1/gi;
	if ( $dbg ) { print "  std spelling: $common_name\n" }
	
	# detail phrase
	$common_name =~ s/^ *protein *involved *in +(.*pathway) +for +/$1\//i;
	$common_name =~ s/ +associated with .*/, putative/i;
	$common_name =~ s/^ *protein *involved *in +//i;
	$common_name =~ s/\b[1-9][\.0-9]* *(k|kd|kda) *protein/protein/gi;
	$common_name =~ s/\b[1-9][\.0-9]* *(k|kd|kda) *($subunits)//gi;
	$common_name =~ s/^(component|subunit|enzyme) +of +the\b//gi;
	$common_name =~ s/^(component|subunit|enzyme) +of\b//gi;
	$common_name =~ s/\([^()]{20,}\)//g;
	$common_name =~ s/\[[^[\]]{20,}\]//g;
	$common_name =~ s/\{[^{}]{20,}\}//g;
	$common_name =~ s/\((a|an|or|and|subfamily|superfamily) [^()]+\)//g;
	$common_name =~ s/\[(a|an|or|and|subfamily|superfamily) [^[\]]+\]//g;
	$common_name =~ s/\{(a|an|or|and|subfamily|superfamily) [^{}]+\}//g;
	$common_name =~ s/ +(and|or) *others* .*$/-like/;
	$common_name =~ s/ +and +(related|similar) .*/-like/;
	$common_name =~ s/\b(could|might|may) +be\b.*/, putative/;
	$common_name =~ s/[(:;,.] *(a|to|in|of|by|is|the|from|for|with|has|had|have|having|this|these|that|which) .*$/, putative/;
	$common_name =~ s/^.* is (an|a) /putative /;
	$common_name =~ s/ is .*/, putative/;
	$common_name =~ s/, +(form|interacting|act|involv|mediat|confirm).*/, putative/;
	$common_name =~ s/ +(together|in conjunction|combined|combining|interacting) with .*/, putative/;
	$common_name =~ s/ (involv[edsing]+|mediates|interacts|forms|acts)\b.*/, putative/;
	$common_name =~ s/ (mediated *by|acting *(on|upon))\b.*/, putative/;
	$common_name =~ s/ase activity/ase/g;
	$common_name =~ s/ (mediated *by|interacting *with|involv(ed|ment) *in|acting *(on|upon))\b.*/, putative/;
	$common_name = trim_small_words( $common_name );
	if ( $dbg ) { print "  std detail phr: $common_name\n" }
	
	# kinases
	$common_name =~ s/^[^ ]*: +//;
	$common_name =~ s/\bhis[-]*kinase/histidine kinase/gi;
	$common_name =~ s/\bpkinase\b/kinase/gi;
	$common_name =~ s/\bprotein[- ]*(kinase|tyrosine|serine)/$1/gi;
	$common_name =~ s/\bmitogen[- ]*activated[- ]*kinase\b/MAP kinase/g;
	if ( $common_name =~ /kinase/i ) {
		$common_name =~ s/\bs(-|\/| )t/Serine\/Threonine/gi;
		$common_name =~ s/\bser(-|\/| )thr/Serine\/Threonine/gi;
		$common_name =~ s/\bserine(-|\/| )threonine/Serine\/Threonine/gi;
	}
	if ( $dbg ) { print "  std kinase: $common_name\n" }
	
	# remove domain/repeat copy count, e.g. "(20 copies)"
	$common_name =~ s/(domains*|repeats*) *[:;\.,\(\[] *\d+ copies *[:;\.,\)\]]/$1/gi;
	if ( $dbg ) { print "  std copies: $common_name\n" }
	
	# miscellaneous clean-ups retained from old code
	$common_name =~ s/proteins* *products*/protein/gi;
#	if ( $common_name =~ /\b($enzymes)\b/i ) {
#		$common_name =~ s/\bcataly[a-z]+ *(domain|protein|enzyme)/$1/gi;
#	}
	$common_name =~ s/ *, *($domains)/ $1/gi;
	$common_name =~ s/ expre*s+e*d prot[ei]+ns*/ /gi;
	$common_name =~ s/ +expre*s+e*d/ /gi;
	$common_name =~ s/\btransport[a-z]*[- ]*protein/transporter/gi;
	$common_name =~ s/\bcarrier[- ]*protein/carrier/gi;
	$common_name =~ s/(,|\(|-) *EC *[0-9]+\..*/ putative/i;
	$common_name =~ s/\b(genbank|refseq|fgenesh|genescan|genmark|glimmer)\b//gi;
	$common_name =~ s/\bof *unknown *(specificity|substrate)\b//gi;
	$common_name =~ s/\bunknown *(specificity|substrate)\b//gi;
	$common_name =~ s/^(TPA|FOG): *//i;
	if ( $dbg ) { print "  std misc: $common_name\n" }
	
	# acronyms
	$common_name =~ s/\b(DUF|UPF)[- ]+([0-9])/$1$2/gi;
	if ( $common_name =~ /\bbrain super conserved receptor/i ) {
		$common_name =~ s/\( *SREB *\)//gi;
		$common_name =~ s/\bbrain super conserved receptor/SREB family G-protein coupled receptor/gi;
	}
	$common_name =~ s/\bsreb\b/SREB/gi;
	if ( $common_name =~ /\bTransient[- ]*receptor[- ]*potential/i ) {
		$common_name =~ s/\( *TRP *\)//gi;
		$common_name =~ s/\bTransient[- ]*receptor[- ]*potential/TRP/gi;
	}
	$common_name =~ s/\btrp\b/TRP/gi;
	if ( $common_name =~ /\bpentatricopeptide[- \/]*(PPR|repeat)/i ) {
		$common_name =~ s/\( *PPR *\)//gi;
		$common_name =~ s/\( *PPR[- 0-9]*\)//gi;
		$common_name =~ s/\( *PPR][- ]*(like|related|protein|domain|[a-z]*family|repeat) *\)//gi;
		$common_name =~ s/\bpentatricopeptide[- \/]*(PPR|repeat)/PPR/gi;
	}
	$common_name =~ s/\bppr\b/PPR/gi;
	if ( $common_name =~ /\btetratricopeptide[- \/]*(TPR|repeat)/i ) {
		$common_name =~ s/\( *TPR *\)//gi;
		$common_name =~ s/\( *TPR[- 0-9]*\)//gi;
		$common_name =~ s/\( *TPR][- ]*(like|related|protein|domain|[a-z]*family|repeat) *\)//gi;
		$common_name =~ s/\btetratricopeptide[- \/]*(TPR|repeat)/TPR/gi;
	}
	$common_name =~ s/\btpr\b/TPR/gi;
	if ( $common_name =~ /\bATP[- ]*binding[- ]*cassette/i ) {
		$common_name =~ s/\( *ABC *\)//gi;
		$common_name =~ s/\bATP[- ]*binding[- ]*cassette/ABC/gi;
	}
	$common_name =~ s/\babc\b/ABC/gi;
	if ( $common_name =~ /\bmajor[- ]*facilitator[- ]*(family|super-*family)/i ) {
		$common_name =~ s/\( *MFS *\)//gi;
		$common_name =~ s/\bmajor[- ]*facilitator[- ]*(family|super-*family)/MFS/gi;
	}
	$common_name =~ s/\bMFS[- ]*(super-*family|family|$groups)/MFS/gi;
	$common_name =~ s/\bMFS\b([;:,).]|[- ]*protein)/MFS transporter/gi;
	$common_name =~ s/\bMFS$/MFS transporter/i;
	$common_name =~ s/\bmfs\b/MFS/gi;
	if ( $common_name =~ /multi([- ]*(drug|anti|microbial|(and[- ]*){0,1}(toxic[- ]*compound|toxin))s*){2,}[- ]*extrusion/i ) {
		$common_name =~ s/\( *MATE *\)//gi;
		$common_name =~ s/multi([- ]*(drug|anti|microbial|(and[- ]*){0,1}(toxic[- ]*compound|toxin))s*){2,}[- ]*extrusion/MATE/gi;
	}
	if ( $common_name =~ /(drug|efflux|port|mate domain|mate family)\b/i ) {
		$common_name =~ s/\bmate\b/MATE/gi;	
	}	
	$common_name =~ s/\blob\b/LOB/gi;
	if ( $common_name =~ /\blateral[- ]*organ[- ]*boundary/i ) {
		$common_name =~ s/\( *LOB *\)//gi;
		$common_name =~ s/\blateral[- ]*organ[- ]*boundary/MFS/gi;
	}
	if ( $dbg ) { print "  std acronyms: $common_name\n" }

	# underscores, hyphens, periods, quotes
	$common_name =~ s/\bco[- ]+enzyme/coenzyme/gi;
	$common_name =~ s/\b([A-Z])'\b/$1-prime/gi;
	if ( $common_name =~ /^ *"/ ) { $common_name =~ s/"//g }
	if ( $common_name =~ /^ *'/ ) { $common_name =~ s/'//g }
	if ( $common_name =~ /" *"/ ) { $common_name =~ s/"//g }
	if ( $common_name =~ /' *'/ ) { $common_name =~ s/'//g }
	if ( $common_name =~ /" *$/ ) { $common_name =~ s/"//g }
	if ( $common_name =~ /' *$/ ) { $common_name =~ s/'//g }
	$common_name =~ s/\.\W*$//;
	$common_name =~ s/\. +/ /g;
	$common_name =~ s/_/-/g;
	$common_name =~ s/--+/-/g;
	$common_name =~ s/"//g;
	$common_name =~ s/ +like\b/-like/gi;
	$common_name =~ s/($domains|famil[yie]+|$isoforms|protein)s*[- ]+/$1 /gi;
	if ( $dbg ) { print "  std hyph: $common_name\n" }
	
	# parens/brackets
	if ( $common_name =~ / \(([A-Za-z][a-z]{2}[A-Z0-9]|[A-Za-z]{1,3}[0-9]{1,2}[A-Za-z0-9]|[A-Za-z]{2,3}[0-9]{1,3})\)/ ) {
		my $tmp = $common_name;
		$common_name =~ s/ \(([A-Za-z][a-z]{2}[A-Z0-9]|[A-Za-z]{1,3}[0-9]{2,3}|[A-Za-z]{2,3}[0-9]{1,3})\)//g;
		$common_name =~ s/ +([;:,\.])/$1/g;
		$common_name =~ s/  +/ /g;
		print "removed menomic: $tmp => $common_name\n";
	}
	$common_name =~ s/^ *\(([^\)]{3,})/$1/;
	$common_name =~ s/^ *\[([^\]]{3,})/$1/;
	$common_name = balance_parens( $common_name );
	if ( $dbg ) { print "  std balance1: $common_name\n" }
	
	# number jammed into word
	$common_name =~ s/\b(($domains|$groups|$isoforms|$subunits|[a-z]{6,}|like)s*)([0-9])\b/$1 $3/gi;
	if ( $dbg ) { print "  std word9: $common_name\n" }

	# conserved/unknown/uncharacterized
	$common_name =~ s/uncha*re*[ct]+e*ri*[sz]e*d/uncharacterized/gi;
	$common_name =~ s/\bunk[no]+[ow]+[wn]+\b/unknown/gi;
	$common_name =~ s/($strength) *conserv/conserv/gi;
	$common_name =~ s/\bconserved +(site|region)s*\b/motif/gi;
	$common_name =~ s/\bconserved +(domain|repeat|motif)s\b/$1/gi;
	$common_name =~ s/\bconserved\b//gi;
	$common_name =~ s/\bprotein *protein\b/protein/gi;
	$common_name =~ s/\blow complexity\b//gi;
	$common_name =~ s/\b(small|short|large|long)[- ]*($protypes)/$1/gi;
	if ( $dbg ) { print"  std hypo: $common_name\n" }

	# active site (from interpro classification of peptidases)
	$common_name =~ s/\b($enzymes)s* *([-\w]+)\W*active *sites*\W*/$2 $1/gi;
	$common_name =~ s/\b($enzymes)s* *([-\w]+)\W*inactive *sites*\W*/$2 $1-like/gi;
	if ( $dbg ) { print"  std site: $common_name\n" }

	# remove putative (we'll put it back, later)
	my $is_putative = 0;
	my $oldname = $common_name;
	
	$common_name =~ s/putative/ /gi;
	$common_name =~ s/^ *the predicted */predicted /i;
	$common_name =~ s/novel protein/ /gi;
	$common_name =~ s/ab initio/ /gi;
	if ( $dbg ) { print"  std put1a: $common_name\n" }
	$common_name =~ s/(fragment[a-z]*|partials*|truncat[a-z]+)//gi;
	$common_name =~ s/predi*cte*d *prot[ei][ei]*n/ /gi;
	$common_name =~ s/predi*cte*d *CDS/ /gi;
	$common_name =~ s/predict[a-z]*\b*//gi;
	$common_name =~ s/unkn*ow*n prot[ei][ei]*ns*/ /gi;
	$common_name =~ s/unkn*ow*n [Cc][Dd][Ss]/ /gi;
	$common_name =~ s/unn*amm*e*d prot[ei][ei]*ns*/ /gi;
	$common_name =~ s/unn*amm*e*d [Cc][Dd][Ss]/ /gi;
	if ( $dbg ) { print"  std put1b: $common_name\n" }
	$common_name =~ s/ a probable/ /gi;
	$common_name =~ s/ is probable/ /gi;
	$common_name =~ s/ the probable/ /gi;
	$common_name =~ s/^a probable/ /gi;
	$common_name =~ s/^is probable/ /gi;
	$common_name =~ s/^the probable/ /gi;
	$common_name =~ s/probable*y*/ /gi;
	$common_name =~ s/possible*y*/ /gi;
	$common_name =~ s/questionable/ /gi;
	$common_name =~ s/likely/ /gi;
	$common_name =~ s/potential/ /gi;
	$common_name =~ s/candidates*/ /gi;
	if ( $dbg ) { print"  std put1c: $common_name\n" }
	$common_name =~ s/hypothetiocal/hypothetical/gi;
	$common_name =~ s/hypot[heti]*cal con[se]*rve*d prot[ei][ei]*ns*/ /gi;
	$common_name =~ s/hypot[heti]*cal con[se]*rve*d/ /gi;
	$common_name =~ s/hypot[heti]*cal prot[ei]+ns*/ /gi;
	$common_name =~ s/hypot[heti]*cal/ /gi;
	$common_name =~ s/con[se]*rve*d prot[ei]+ns*/ /gi;
	$common_name =~ s/con[se]*rve*d/ /gi;
	if ( $dbg ) { print"  std put1d: $common_name\n" }
	if ( $oldname ne $common_name ) { $is_putative = 1 }
	$common_name =~ s/\[\W*\]//g;
	$common_name =~ s/\(\W*\)//g;
	$common_name =~ s/[^\w)\]}]+$//;
	$common_name =~ s/^[^\w[({]+//;
	if ( $dbg ) { print"  std put1e($is_putative): $common_name\n" }

	# remove related (we'll put it back, later)
	$common_name =~ s/\b($strength) +quality/$1 similarity/i;
	$common_name =~ s/^.*?\b($strength) +($homologs|$homologous|related) +(to|of)\b/related to/i;
	my $is_related = 0;
	if ( $common_name =~ /\b(similar[a-z]*|related) *to[-, ]*\b/i ) {
		$common_name =~ s/\b(similar[a-z]*|related) *to[-, ]*\b/ /gi;
		$is_related = 1;
		if ( $dbg ) { print"  std rel1a: $common_name\n" }
	}
	if ( $common_name =~ /[-, ]+(similar[a-z]*|related) *proteins*[-, ]$/i ) {
		$common_name =~ s/[-, ]+(similar[a-z]*|related) *proteins*[-, ]*$/ /i;
		$is_related = 1;
		if ( $dbg ) { print"  std rel1b: $common_name\n" }
	}
	elsif ( $common_name =~ /[-, ]+(similar[a-z]*|related)/i ) {
		$common_name =~ s/[-, ]+(similar[a-z]*|related)[-, ]*/ /i;
		$is_related = 1;
		if ( $dbg ) { print"  std rel1c: $common_name\n" }
	}
	elsif ( $common_name =~ /^[-, ]*(similar[a-z]*|related)/i ) {
		$common_name =~ s/^[-, ]*(similar[a-z]*|related)[-, ]*/ /i;
		$is_related = 1;
		if ( $dbg ) { print"  std rel1d: $common_name\n" }
	}
	if ( $common_name =~ /(\brelated\b|\blike\b|[a-z]*family\b|\bsimilar)/i ) {
		$is_related = 0;
	}
	if ( $is_related ) { $common_name =~ s/ {2,}/ /g } 

	# semi-colons
	$common_name =~ s/;[ 0-9]*$//;
	while ( $common_name =~ /;([^ ])/ ) {
		$common_name =~ s/;([^ ])/; $1/;
#print "while27: $common_name\n";
	}
	$common_name =~ s/ +;/;/g;
	if ( $dbg ) { print"  std simicolon: $common_name\n" }

	# LRR/F-box/K-box
	$common_name =~ s/\bleuciner ich\b/leucine rich/gi;
	$common_name =~ s/\bleucine[- ]*rich[- ]repeats*\b/LRR/gi;
	if ( $common_name =~ /\bLRR\b/i ) { $common_name =~ s/\( *LRR *\)//gi }
	$common_name =~ s/\bLRR[- ]*repeat/LRR/gi;
	$common_name =~ s/\bf[- ]*box/F-box/gi;
	$common_name =~ s/\bk[- ]*box/K-box/gi;
	if ( $dbg ) { print"  std LRR/box: $common_name\n" }

	# LRR/NBS/NB-ARC
	if ( $common_name =~ /(disease|resistance)/i ) {
		$common_name =~ s/\bnb([- ]*domains*)*\b/NBS/g;
		$common_name =~ s/nucleotide[- ]*binding[- ]*site/NBS/gi;
	}
	$common_name =~ s/\bnb *-[- ]*arc[- ]*(domains*)*\b/NBS/gi;
	$common_name =~ s/\bLRR([- \/]*|[- ]*and[- ]*)NBS\b/NBS$1LRR/gi;
	$common_name =~ s/\bnb([- \/]*)lrr\b/NBS$1LRR/gi;
	
	# amino acid rich
	$common_name =~ s/\b($aminoacids) *rich/$1-rich/gi;
	
	# reverse transcriptase
	if ( $common_name =~ /\brna[- ]*(dependent|directed|instructed)[- ]*dna[- ]*polymerases*/ ) {
		$common_name =~ s/\breverse *transcriptases*\b//gi;
		$common_name =~ s/\bRT\b//g;
	}
	if ( $dbg ) { print"  std RT: $common_name\n" }
	
	# dependent
	if ( $common_name =~ /(dependent|directed|instructed|independent)/
			&& $common_name !~ /(dependent|directed|instructed|independent) *(by|on)/ ) {
		$common_name =~ s/([a-z]) +(independent|directed|instructed|dependent)/$1-$2/gi;
	}
	# binding
	if ( $common_name =~ /binding/ && $common_name !~ /binding *(to|of|with)/ ) {
		$common_name =~ s/([a-z]) *binding/$1-binding/gi;
	}
	
	# DEAD/DEAH
	if ( ( $common_name =~ /helicase/i && $common_name =~ /(dead|deah)/i ) ||
			( $common_name =~ /(box|family|domain)/i && $common_name =~ /(dead|deah)/i ) ||
			( $common_name =~ /dead/i && $common_name =~ /deah/i )  ) {
		$common_name =~ s/deah[- ]*(box|domain|[a-z]*family)/DEAH/gi;
		$common_name =~ s/dead[- ]*(box|domain|[a-z]*family)/DEAD/gi;
		$common_name =~ s/dead/DEAD/g;
		$common_name =~ s/deah/DEAH/g;
		$common_name =~ s/\bdead\b/DEAD/gi;
		$common_name =~ s/\bdeah\b/DEAH/gi;
		$common_name =~ s/\bDEAD[-:\/& ]DEAH\b/DEAD\/DEAH/g;
		$common_name =~ s/\bDEAD[- ]*and[- ]*DEAH\b/DEAD\/DEAH/g;
		$common_name =~ s/\bDEAH[-:\/& ]DEAD\b/DEAD\/DEAH/g;
		$common_name =~ s/\bDEAH[- ]*and[- ]*DEAD\b/DEAD\/DEAH/g;
		if ( $common_name =~ /\bDEA[HD]\b/ && $common_name !~ /\bbox\b/i ) {
			$common_name =~ s/\bDEAD\b/DEAD-box/gi;
			$common_name =~ s/\bDEAH\b/DEAH-box/gi;
		}
		$common_name =~ s/\bDEAD-box\//DEAD\//gi;
		$common_name =~ s/\bDEAH-box\//DEAH\//gi;
	}
	if ( $dbg ) { print"  std DEAD/H: $common_name\n" }
	
	# activated/regulated/inhibited etc by
	if ( $common_name =~ /, +([a-z]{4,}ed +by +[^ ]+)$/i ) {
		$common_name =~ s/, +([a-z]{4,}ed +by +[^ ]+)$/ ($1)/;
	}
	if ( $dbg ) { print "  std ...ed by: $common_name\n" }
	
	# some family clean-ups
	$common_name =~ s/\bpfam[- ]*domain/domain/gi;
	$common_name =~ s/(family[-, ]*[^ ]+)[-, ]*[a-z]*family[- ]*($protypes)/$1 $2/gi;
	if ( $dbg ) { print"  std fam1a: $common_name\n" }
	$common_name =~ s/family +([0-9]+)[, ]+subfamily +([a-z])\b/family $1$2/gi;
	$common_name =~ s/\b([a-z]*family)[- ]*([^ ]+)[- ]*([a-z]*family)/$1 $2/gi;
	if ( $dbg ) { print"  std fam1b: $common_name\n" }
	$common_name =~ s/family[-, ]*domains*/family/gi;
	$common_name =~ s/family[- ]*([^,; ]+)[-, ]*domains*[- ]*protein/family $1 protein/gi;
	if ( $dbg ) { print"  std fam1c: $common_name\n" }
	$common_name =~ s/\b[a-z]*famil[yies]+[- ]([^,; ]+)[-, ]*(repeat|domains)*[- ]/family $1 $2 /gi;
	$common_name =~ s/\b($domains)[- ]*[a-z]*famil[yies]+/$1/gi;
	if ( $dbg ) { print"  std fam1d: $common_name\n" }
	$common_name =~ s/[a-z]*family[, ]*([a-z]*family)( *protein)*/$1/gi;
	$common_name =~ s/, *([a-z]*family)\b/ $1/gi;
	if ( $dbg ) { print"  std fam1e: $common_name\n" }
	$common_name =~ s/[- ]+(related|like) +($protypes) +([-a-z0-9]+-like)\b/ $3/i;
	#$common_name =~ s/[, ]*polypeptide *[a-z]{0,1}[0-9]*[a-z]{0,1}\b/ protein/gi;
	#$common_name =~ s/([, ]*)polypeptide *[a-z]{0,1}[0-9]*[a-z]{0,1}-*\b/$1/gi;
	$common_name =~ s/\bfamily[, ]*($protypes) *[0-9a-z]{1,3}\b/family $1/gi;
	$common_name =~ s/  +/ /g;
	if ( $dbg ) { print"  std fam1: $common_name\n" }
	
	# homolog/paralog/ortholog/similar
	if ( $common_name =~ /identical/ ) {
		$common_name =~ s/\b(almost|nearly|virtual+y) *identical\b/similar/gi;
		$common_name =~ s/\bidentical +to +//gi;
		$common_name =~ s/\bidentical\b//gi;
	}
	
	$common_name =~ s/\b($strength)[- ]*related/$1 similar /gi;
	$common_name =~ s/\bvery\b//gi;
	if ( $common_name =~ /($homologous|$homologs)/i ) {
		if ( $dbg ) { print "  std log0: $common_name\n" }
		$common_name =~ s/\b($strength) *($homologous|$homologs) *($protypes)/$1 $2/gi;
		if ( $common_name =~ /[-, ]+($homologs) *([0-9a-z]{1,2})\b/i ) {
			if ( $is_related || $common_name =~ /family\b/i ) {
				$common_name =~ s/[-, ]+($homologs) *([0-9a-z]{1,2})\b//i;
				if ( $dbg ) { print "  std log0a: $common_name\n" }
			}
			else {
				$common_name =~ s/[-, ]+($homologs) *([0-9a-z]{1,2})\b/-like/i;
				if ( $dbg ) { print "  std  log0b: $common_name\n" }
			}
		}
		elsif (	$common_name =~ / +(proteins* *)([0-9a-z]{1,2}) *($homologs)/i ) {
			$common_name =~ s/ +(proteins* *)([0-9a-z]{1,2}) *($homologs)/ protein $2-like/gi;
			if ( $dbg ) { print "  std  log1: $common_name\n" }
		}
		elsif (	$common_name =~ / +([0-9a-z]{1,2}) *($homologs)/i ) {
			$common_name =~ s/ +([0-9a-z]{1,2}) *($homologs)/ $1-like/gi;
			if ( $dbg ) { print "  std  log2: $common_name\n" }
		}
		$common_name =~ s/[- ]+($homologous|$homologs) +(\([^()]+h\)) *(domain|repeat|[a-z]*family)/-like ($2) $3/gi;
		$common_name =~ s/[- ]+($homologous|$homologs)[- ]+(domain|repeat|[a-z]*family)/-like $2/gi;
		if ( $dbg ) { print "  std  log3: $common_name\n" }
		if ( $common_name =~ /\b($strength) *($homologous|$homologs)( +of | +to ){0,1}/i ) {
			$common_name =~ s/\b($strength) *($homologous|$homologs)( +of | +to ){0,1}/ /gi;
			$is_related = 1;
		}
		elsif ( $common_name =~ /\b($homologous|$homologs)( +of +| +to +)/i ) {
			$common_name =~ s/\b($homologous|$homologs)( +of +| +to +)//gi;
			$is_related = 1;
		}
		if ( $dbg ) { print "  std  log4: $common_name\n" }
		$common_name =~ s/[- ]($homologs)\b/-like/gi;
		$common_name =~ s/\b($homologous|$homologs)\b/related/gi;
		if ( $dbg ) { print "  std  log5: $common_name\n" }
	}
		
	# gene
	$common_name =~ s/\bgenes* analog[ues]+\b//gi;
	$common_name =~ s/\bgenes*( +[^ ]*){0,1}protein\b/protein$1/gi;
	$common_name =~ s/\bgenes*\b/protein/gi;
	if ( $dbg ) { print "  std gene: $common_name\n" }

	# -like 2 protein
	$common_name =~ s/\blike *([0-9]{1,2}) *protein/like protein/gi; 
	if ( $dbg ) { print "  std like 9: $common_name\n" }

	# hyphenate kDa for detail trimming
	if ( $common_name !~ /\bk-/ && $common_name !~/\bk[- ]+box/i  ) {
		$common_name =~ s/\b([1-9][0-9.]*) *(kda|kd|k)\b/$1-kDa/gi;
	}
	else {
		$common_name =~ s/\b([1-9][0-9.]*) *(kda|kd)\b/$1-kDa/gi;
	}

	# containing
	$common_name =~ s/($domains|$enzymes|$protypes)[- ]*containing/$1/gi;
	$common_name =~ s/[- ]+containing/ containing/gi;
	$common_name =~ s/^[Cc]ontain[sing]* *a\b//;
	$common_name =~ s/^contain[sing]* *//i;
	if ( $dbg ) { print "  std cont: $common_name\n" }

	# C/N-terminal
	$common_name =~ s/\bC[- ]*term/carboxy-term/gi;
	$common_name =~ s/\bN[- ]*term/amino-term/gi;
	$common_name =~ s/\b(terminal|terminus|term) +(of|from|to +)/$1, /gi;
	if ( $dbg ) { print "  std terminus: $common_name\n" }

	# pseudo/open reading frame
	$common_name =~
	  s/\bpseudo[- ]response[- ]*regulators*\b/PRR response regulator/gi;
	$common_name =~ s/\bopen[- ]*reading[- ]*frame\b//gi;
	$common_name =~ s/\bORF\b//g;
	if ( $dbg ) { print "  std pseudo/ORF: $common_name\n" }
	
	# identifiers
	$common_name =~ s/(acc\.* *no\.*|acc\.* *number|accession *number|accession *no\.*|accession|identifier) *[a-z]{1,}[-_]*[0-9]{1,}[-_a-z0-9.]*\b//gi;
	$common_name =~ s/\bh([0-9])\.[0-9]/H$1/gi;
	$common_name =~ s/ [^ ]*[0-9]{5,}[-a-z0-9_.]*\b//gi;
	$common_name =~ s/\b[A-Z]{3}[0-9]{5}\b//g;
	$common_name =~ s/\b[A-Z]+[0-9]+\.[0-9]+[A-Z]{0,1}\b//gi;
	$common_name =~ s/\b[A-Z]{2,4}[0-9]{1,3}[A-Z]{1,}[0-9]{1,}[-a-z0-9.]*\b//gi;
	$common_name =~ s/\b[A-Z]+[0-9]+[A-Z0-9]*[-\.][0-9]{1,3}[a-z]{0,1}\b//gi;
	$common_name =~ s/\(\W*\)//g;
	$common_name =~ s/\[\W*\]//g;
	$common_name =~ s/\{\W*\}//g;
	if ( $dbg ) { print "  std identifiers: $common_name\n" }
	
	# organelle
	$common_name =~ s/chloroplast[a-z]*\W*(mitochond[a-z]*)/$1/gi;
	$common_name =~ s/(mitochond[a-z]*)\W*chloroplast[a-z]*/$1/gi;
	$common_name =~ s/ (in|into|from|to) *(chloroplast|mitochond)[a-z]*\b//i;
	$common_name =~ s/[,;:] *(chloroplast|mitochond)[a-z]*[,;\. ]*//i;
	$common_name =~ s/^ *(chloroplast|mitochond)[a-z]*[,;\. ]*//i;
	$common_name =~ s/ *[(\[{](chloroplast|mitochond)[a-z]*[)\]}]//i;
	$common_name =~ s/([(\[{])(chloroplast|mitochond)[a-z]*[,;\. ]*/$1/i;
	$common_name =~ s/(mitochondr*ial|chloroplastic)//gi;
	#$common_name =~ s/\bgolgi[- ]*to[- ]*(inner[- ]*|outer[- ]*|plasma[- ]*){0,1}membrane\b/transportation/gi;
	#$common_name =~ s/\bmembrane[- ]*to[- ]*golgi\b/transportation/gi;
	$common_name =~ s/endoplasmic[- ]*reticulum/ER/gi;
	#$common_name =~ s/\bER[- ]*golgi\b/transportation/gi;
	#$common_name =~ s/\bER[- ]*to[- ]*golgi\b/transportation/gi;
	$common_name =~ s/(transp[a-z]*) *transp[a-z]*\b/$1/gi;
	$common_name =~ s/\btransp[a-z]* *([a-z]*port(er|atation|ing){0,1})\b/$2/gi;
	$common_name =~ s/\btrans[- ]*Golgi[- ]*network\b/TGN/gi;
	$common_name =~ s/\bthe *TGN\b/TGN/gi;
	$common_name =~ s/\bTGN *proteins*/TGN/g;
	$common_name =~ s/\b(related|linking|linked) *to *TGN\b/TGN/gi;
	$common_name =~ s/TGN/(TGN-related)/gi;
	
	#$common_name =~ s/\bgolgi[- ]*localized\b//gi;
	if ( $common_name =~ /\bgolgi[- ]*to[- ]*er\b/i ) {
		$common_name =~ s/\bgolgi[- ]*to[- ]*er\b/golgi-to-ER/gi;
	}
	#else {
	#	$common_name =~ s/\bgolgi[- ]*(body|apparatus|complex){0,1}\b//gi;
	#}
	if ( $dbg ) { print "  std organelle: $common_name\n" }

	# aribdopsis gene name / species names
	$common_name =~ s/\beurofung\b//gi;
	$common_name =~ s/\bAt[0-9]+g[0-9]+\b/ SPECIES /gi;
	$common_name =~ s/\b(aquifex|a\.|a) *aeolicus\b/ SPECIES /gi;
	$common_name =~ s/\b(arabidopsis *thaliana|a\.* *thaliana|arabidopsis)\b/ SPECIES /gi;
	$common_name =~ s/\barchaea[ls]*\b/ SPECIES /gi;
	$common_name =~ s/\b*thaliana\b/ SPECIES /gi;
	$common_name =~ s/\b(aspergillus|a\.|a) *(fumigatus|niger|nidulans|oryzae)\b/ SPECIES /gi;
	$common_name =~ s/\b(fumigatus|niger|nidulans|oryzae)\b/ SPECIES /gi;
	$common_name =~ s/\b(betula|b\.|b) *pendula\b/ SPECIES /gi;
	$common_name =~ s/\bc[a-z.]* *thermocellum\b/ SPECIES /gi;
	$common_name =~ s/\b(caenorhabditis|c\.|c) *elegans\b/ SPECIES /gi;
	$common_name =~ s/\b(campylobacter|c\.|c) *jejuni\b/ SPECIES /gi;
	$common_name =~ s/\b(candida|c\.|c) *albicans\b/ SPECIES /gi;
	$common_name =~ s/\bchlamydia\b/ SPECIES /gi;
	$common_name =~ s/\b(dictyostelium|d\.|d) *discoideum\b/ SPECIES /gi;
	$common_name =~ s/\b(deinococcus|d\.|d) *radiodurans\b/ SPECIES /gi;
	$common_name =~ s/\bdrosophila *(melanogaster){0,1}/ SPECIES /gi;
	$common_name =~ s/\b(es[ericha]* *coli|e\.* *coli)\b/ SPECIES /gi;
	$common_name =~ s/\beukary[oteics]*\b/ SPECIES /gi;
	$common_name =~ s/\b(fugu|f\.|f) *rubripes\b/ SPECIES /gi;
	$common_name =~ s/\b(gallus|g\.|g) *gallus\b/ SPECIES /gi;
	$common_name =~ s/\b(gibberella|g\.|g) *zeae\b/ SPECIES /gi;
	$common_name =~ s/\b(homo *sapiens|h\.* *sapiens|human)\b/ SPECIES /gi;
	$common_name =~ s/\b(lactococcus|l\.|l) *lactis\b/ SPECIES /gi;
	$common_name =~ s/\b(leishmania|l\.|l) *major\b/ SPECIES /gi;
	$common_name =~ s/\b(leptosphaeria|l\.|l) *maculans\b/ SPECIES /gi;
	$common_name =~ s/\b(magnaporthe|m\.|m) *grisea\b/ SPECIES /gi;
	$common_name =~ s/\b(mesorhizobium|m\.|m) *loti\b/ SPECIES /gi;
	$common_name =~ s/\bmouse\b/ SPECIES /gi;
	$common_name =~ s/\b(mus|m\.|) *musculus\b/ SPECIES /gi;
	$common_name =~ s/\b(mycobacterium|m\.|m) *tuberculosis\b/ SPECIES /gi;
	$common_name =~ s/\b(neurospora|n\.|n) *crassa\b/ SPECIES /gi;
	$common_name =~ s/\b(ophiostoma|o\.|o) *(novo-*|ulmi-*){1,2}\b/ SPECIES /gi;
	$common_name =~ s/\b(penicillium|p\.|p) *chrysogenum\b/ SPECIES /gi;
	$common_name =~ s/\b(pichia|p\.|p) *angusta\b/ SPECIES /gi;
	$common_name =~ s/\b(podospora|p\.|p) *anserina\b/ SPECIES /gi;
	$common_name =~ s/\bprokary[oteics]*\b/ SPECIES /gi;
	$common_name =~ s/\b(pseudomonas|p.|p) *aeruginosa\b/ SPECIES /gi;
	$common_name =~ s/\br[a-z.]* *thermocellum\b/ SPECIES /gi;
	$common_name =~ s/\b(rattus|r\.|r) *norvegicus\b/ SPECIES /gi;
	$common_name =~ s/\b(saccharomyces|s\.|s) *cerevisiae\b/ SPECIES /gi;
	$common_name =~ s/\b(schizosaccharomyces|s\.|s) *pombe\b/ SPECIES /gi;
	$common_name =~ s/\b(streptomyces|s\.|s) *(avermitilis|coelicolor|griseus)\b/ SPECIES /gi;
	$common_name =~ s/\b(streptomyces|streptococcal|staphylococcal)/ SPECIES /gi;
	$common_name =~ s/\b(ustilago|u\.|u) *maydis\b/ SPECIES /gi;
	$common_name =~ s/\b(zymomonas|z\.|z) *mobilis\b/ SPECIES /gi;
	$common_name =~ s/($protypes)[ -]*($kingdoms)][- ]*(like|related)/ $2-$3 $1/i;
	$common_name =~ s/ (plants*|fungal|fungi+|bacteri[alum]*|yeast)\b/ SPECIES/gi;
	$common_name =~ s/SPECIES[- ]*(specific|type|like|related)[- ]*//gi;
	if ( $dbg ) { print "  std species1: $common_name\n" }
	$common_name =~ s/ (of|from|in) *SPECIES/ /g;
	$common_name =~ s/\b[- ]*SPECIES[- ]*\b/ /g;
	$common_name =~ s/ +$//;
	if ( $dbg ) { print "  std species2: $common_name\n" }
	
	# sub-/super-/mono-
	$common_name =~ s/\b(super|poly|sub) *-[- ]*/$1/gi;
	$common_name =~ s/mono *-[- ]*oxygenase/monooxygenase/gi;
	if ( $dbg ) { print "  std sub/super/poly-: $common_name\n" }

	# bi/multifunctional
	$common_name =~ s/\b(bi|multi)-*function[aling]*( +proteins*){0,1}//gi;
	if ( $dbg ) { print "  std multifunc: $common_name\n" }

	# remove accession number at end of name
	if ( $common_name =~ /[, ]+[A-Z]{2,}[0-9]{4,}$/ ) {
		$common_name =~ s/[, ]+[A-Z]{2,}[0-9]{4,}$//;
	}
	if ( $dbg ) { print "  std end acc: $common_name\n" }
	
	# isoforms
	$common_name =~ s/[, ]*polypeptides* *$//gi;
	$common_name =~ s/[, ]*polypeptides*[- ]*[a-z]+$//gi;
	$common_name =~ s/[, ]*polypeptides*[- ]*[0-9.]\/[0-9.]+$//gi;
	$common_name =~ s/[, ]*polypeptides*[- ]*[0-9.]$//gi;
	$common_name =~ s/\bisoenzymes*\b/isozyme/gi;
	$common_name =~ s/\bmembers*\b/protein/gi;
	if ( $common_name =~ /^.*($isoforms) +[^ ]+ +of +/i ) {
		$common_name =~ s/^.*($isoforms) +[^ ]+ +of +//gi;
	}
	elsif ( $common_name =~ /^.*($isoforms) +of +/i ) {
		$common_name =~ s/^.*($isoforms) +of +//gi;
	}
	elsif ( $common_name =~ /($isoforms) +[^ ]+$/i ) {
		$common_name =~ s/($isoforms) +[^ ]+$//gi;
	} 
	elsif ( $common_name =~ /($isoforms)$/i ) {
		$common_name =~ s/($isoforms)$//gi;
	}
	elsif ( $common_name =~ /($isoforms) +([0-9]{1,2}[-a-z_]{0,2}|[a-z]{1,3}[-0-9_]{0,3}|$greek|$roman)\b/i ) {
		$common_name =~ s/($isoforms) +([0-9]{1,2}[-a-z_]{0,2}|[a-z]{1,3}[-0-9_]{0,3}|$greek|$roman)\b//gi;
	}
	if ( $dbg ) { print "  std isoform: $common_name\n" }

	# polyprotein/retrotransposon/reverse transcriptase
	my $retrotype;
	if ( $common_name =~ /\bgypsy\b/i && $common_name =~ /\bty3\b/i ) {
		$retrotype = "Ty3/Gypsy";
	}
	elsif ( $common_name =~ /\bgypsy\b/i && $common_name =~ /poly/i ) {
		$retrotype = "Gypsy-like";
		$is_related = 0;
	}
	elsif ( $common_name =~ /\bgypsy\b/i && $common_name =~ /retro/i ) {
		$retrotype = "Gypsy-like";
		$is_related = 0;
	}
	elsif ( $common_name =~ /\bgypsy\b/i && $common_name =~ /transpos/i ) {
		$retrotype = "Gypsy-like";
		$is_related = 0;
	}
	elsif ( $common_name =~ /\bcopia\b/i && $common_name =~ /\bty1\b/i ) {
		$retrotype = "Ty1/Copia";
	}
	elsif ( $common_name =~ /\bcopia\b/i ) {
		$retrotype = "Copia-like";
		$is_related = 0;
	}
	elsif ( $common_name =~ /\bgag\b/i && $common_name =~ /\bpol\b/i ) {
		$retrotype = "Gag-Pol";
	}
	elsif ( $common_name =~ /\b(opie-*[a-z0-9]{0,2})\b/i ) {
		$retrotype = "Opie-like";
		$is_related = 0;
	}
	elsif ( $common_name =~ /\b([a-z]{1,5}[0-9][a-z0-9]{0,2})[- ]+pol\b/i ) {
		$retrotype = "$1 Pol";
	}
	elsif ( $common_name =~ /\bpol *($simpleprotypes)/i || $common_name =~ /\bpol *$/i ) {
		$retrotype = "Pol";
	}
	if ( defined $retrotype ) {
		if ( $is_related || $common_name =~ /(repeat|domain|family|like|related)/i ) {
			if ( $retrotype !~ /-like$/ ) { $retrotype .= "-like" }
			$is_related = 0;
		}
		$common_name = " $retrotype polyprotein/retrotransposon";
	}
	$common_name =~ s/(retrotransposon|retroelement)s* *($protypes)s*/retrotransposon/gi;
	$common_name =~ s/\btransposons* *($protypes)s*/transposon/gi;
	
	if ( $common_name =~ /\breverse[- ]*transcriptase/ ) {
		$common_name =~ s/\bRNA[- ]*[a-z]+[- ]*DNA[- ]*polymerase//gi;
	} 
	$common_name =~ s/\bRNA[- ]*[a-z]+[- ]*DNA[- ]*polymerase/reverse transcriptase/gi;
	if ( $dbg ) { print "  std retro: $common_name\n" }
		
	# and/or
	$common_name =~ s/\b([^ ]+) +(and|or) +([^ ]+)\b/$1\/$3/g;

	# remove extraneous uses of the word "protein"
#	my $preprotein;
	$common_name =~ s/^ *(function|product|protein)s*: *//;
	if ( $dbg ) { print "  std strip0: $common_name\n" }
	while ( $common_name =~ /($enzymes|$protypes) +protein\b/i ) {
		$common_name =~ s/($enzymes|$protypes) +protein\b/$1/gi;
		if ( $dbg ) { print "  std strip1a: $common_name\n" }
	}
	while ( $common_name =~ /\bprotein +(domain|[a-z]*family|repeat|motif)\b/i ) {
		$common_name =~ s/\bprotein +(domain|[a-z]*family|repeat|motif)\b/$1/gi;
		if ( $dbg ) { print "  std strip2b: $common_name\n" }
	}
	
	# remove minor details (protein #/mnemomic)
	while ( $common_name =~ /(^.*) +([^ ]*) *$/ ) {
		my $root = $1;
		my $detail = $2;
		if ( $root =~ /\b($groups)$/i ) { last }
		if ( is_minor_detail( $detail ) ) {
			$common_name =~ s/[-,;: ]+([^ ]*) *$//;
			if ( $dbg ) { print "  std strip2: detail: $detail\n" }
		}
		else {
			last;
		}
	}
	my $strip = 1;
	while ( $strip ) {
		$strip = 0;
		if ( $common_name =~ /^(.+\b($domains|[a-z]*family)) +([^ ]+) +protein$/i ) {
			my $root = "$1 protein";
			my $detail = $3;
			if ( $dbg ) { print "  std strip3: detail: $detail\n" }
			if ( is_minor_detail( $detail) ) {
				$common_name = $root;
				$strip = 1;
	#			$preprotein = $detail;
				if ( $dbg ) { print "  std strip3: $common_name\n" }
			}
		}
		if ( $common_name =~ /^(.+\b($domains|[a-z]*family)) +([^ ]+)$/i ) {
			my $root = "$1 protein";
			my $detail = $3;
			if ( $root !~ /family$/i || $detail =~ /[^0-9]/ ) {
				if ( $dbg ) { print "  std strip3a: detail: $detail\n" }
				if ( is_minor_detail( $detail) ) {
					$common_name = $root;
					$strip = 1;
		#			$preprotein = $detail;
					if ( $dbg ) { print "  std strip3a: $common_name\n" }
				}
			}
		}
		if ( $common_name =~ /^(.*\b($goodends)) +([^ ]+) +protein$/i ) {
			my $root = $1;
			my $detail = $3;
			if ( $root !~ /family$/i || $detail =~ /[^0-9]/ ) {
				if ( $dbg ) { print "  std strip4: detail: $detail\n" }
				if ( $root !~ /($badends|$groups)$/i && is_minor_detail( $detail) ) {
					$common_name = $root;
					$strip = 1;
		#			$preprotein = $detail;
					if ( $dbg ) { print "  std strip4: $common_name\n" }
				}
			}
		}
		if ( $common_name =~ /^(.*\b($goodends)) +([^ ]+)$/i ) {
			my $root = $1;
			my $detail = $3;
			if ( $dbg ) { print "  std strip4a: detail: $detail\n" }
			if ( $root !~ /($badends|$groups)$/i && is_minor_detail( $detail) ) {
				$common_name = $root;
				$strip = 1;
	#			$preprotein = $detail;
				if ( $dbg ) { print "  std strip4a: $common_name\n" }
			}
		}
		if ( $common_name =~ /^(.+[-,;:]) +([^ ]+) +protein$/i ) {
			my $root = $1;
			my $detail = $2;
			$root =~ s/[-,;:]+$//;
			$root .= " protein";
			if ( $dbg ) { print "  std strip5: detail: $detail\n" }
			if ( is_minor_detail( $detail ) ) {
				$common_name = $root;
				$strip = 1;
	#			$preprotein = $detail;
				if ( $dbg ) { print "  std strip5: $common_name\n" }
			}
		}
		if ( $common_name =~ /^(.+[-,;:]) +([^ ]+)$/i ) {
			my $root = $1;
			my $detail = $2;
			$root =~ s/[-,;:]+$//;
			if ( $dbg ) { print "  std strip5a: detail: $detail\n" }
			if ( is_minor_detail( $detail) ) {
				$common_name = $root;
				$strip = 1;
	#			$preprotein = $detail;
				if ( $dbg ) { print "  std strip5a: $common_name\n" }
			}
		}
		if ( $strip && $dbg ) { print "  std strip: $common_name\n" }
	}
	
	# empty parens/brackets
	$common_name =~ s/\( *\)//g;
	$common_name =~ s/\[ *\]//g;
	$common_name =~ s/\( *protein *\)//g;
	$common_name =~ s/\[ *protein *\]//g;
	$common_name =~ s/[-,;:. ]+$//;
	$common_name =~ s/^[-,;:. ]+//;
	if ( $dbg ) { print "  std empty paren: $common_name\n" }
	
#	# ribosomal protein abbreviations
#	if ( $common_name =~ /\b([LRS][1-9][0-9]{0,1})([a-z]{0,1})\b/i ) {
#		my $old = "$1$2";
#		my $new = uc( $1 ) . lc( $2 );
#		if ( $new ne $old ) { $common_name =~ s/\b$old\b/$new/gi; }
#		if  ( $common_name !~ /ribo/i ) {
#			$common_name =~ s/\b$new\b/ribosomal protein $ribo/;
#		}
#	}

	# domain in/of/from
	$common_name =~ s/\b($domains)[- ][-0-9 ]*(in|of|from) .*/$1/i;

	# LSm
	$common_name =~ s/\blike[- ]+sm\b/like-Sm/gi;
	$common_name =~ s/\bsm[- ]+like\b/like-Sm/gi;
	$common_name =~ s/\blsm *family\b/like-Sm/gi;
	$common_name =~ s/\blsm *domain*\b/like-Sm/gi;
	$common_name =~ s/\bLSm\b/like-Sm/g;
	if ( $dbg ) { print "  std LSm: $common_name\n" }

	# P450
	$common_name =~ s/cyp[-_: ]*450\b/P450/gi;
	$common_name =~ s/\bp *-[- ]*450\b/P450/gi;
	$common_name =~ s/P450-(like|related)\b/P450/gi;
	$common_name =~ s/P450: (cytochrome P450)/$1/gi;
	if ( $dbg ) { print "  std P450.0a: $common_name\n" }

	$common_name =~ s/^protein *cyp([0-9]+)[-a-z0-9]*/cytochrome P450 family $1/i;
	$common_name =~ s/cytochrome *P450[, ]*cyp([0-9]+)[-a-z0-9]*/cytochrome P450 family $1/gi;
	if ( $dbg ) { print "  std P450.0b: $common_name\n" }
	#$common_name =~ s/3-epi-6-deoxocathasterone 23-monooxygenase/brassinosteroid oxidase/i;
	#$common_name =~ s/6-deoxoteasterone to 3-dehydro 6-deoxoteasterone or teasterone to 3-dehydro teasterone/brassinosteroid oxidase/i;
	#$common_name =~ s/campestanol to 6-deoxocathasterone or 6-oxocampestanol to cathasterone/brassinosteroid oxidase/i;
	#$common_name =~ s/5-hydroxylase for coniferaldehyde, coniferyl alcohol and ferulic acid/ferulate-5-hydroxylase/i;
	if ( $common_name =~ /\bp450\b/i ) {
		if ( $dbg ) { print "  std P450.1: $common_name\n" }

		if ( $common_name =~ /-(like|related)\b/i ) {
			$common_name =~ s/-(like|related)\b//gi;
			$is_related = 1;
		}
		$common_name =~ s/\b\( *ISS *\)\b//g;
		$common_name =~ s/\bISS\b//g;
		$common_name =~ s/\bP450[^a-z0-9]*(cytochrome P450)/$1/gi;
		$common_name =~ s/\bp450\b/P450 family/gi;
		if ( $common_name !~ /chrome/i ) {
			$common_name =~ s/\bP450\b/cytochrome P450/;
		}
		if ( $dbg ) { print "  std P450.1a: $common_name\n" }
		
		$common_name =~ s/P450 family[-, ]*[a-z]*family/P450 family/gi;
		if ( $dbg ) { print "  std P450.1b: $common_name\n" }
		
		if ( $common_name =~ /\bcyp([0-9]+)[^ ]*/i ) {
			my $fam = $1;
			$common_name =~ s/\bcyp([0-9]+)[^ ]*//i;
			$common_name =~ s/P450 family/P450 family $fam/;
		}
		elsif ( $common_name =~ /($enzymes|protein)[- ]*([0-9]+)[A-Z]{0,1}[0-9]*\b/i ) {
			my $fam = $2;
			if ( $common_name !~ /P450 family [1-9]/ ) {
				$common_name =~ s/($enzymes|protein)[- ]*([0-9]+)[A-Z]{0,1}[0-9]*\b/$1/i;
				$common_name =~ s/P450 family/P450 family $fam/;
			}
		}
		$common_name =~ s/P450 family[- ]*([A-Z]+[0-9]+) *$/P450 family protein $1/;
		$common_name =~ s/P450 family[- ]*([A-Z]+[0-9]+) *,/P450 family protein $1,/;
		if ( $dbg ) { print "  std P450.1c: $common_name\n" }


		$common_name =~ s/(P450 family *[0-9]+)[^ ]*[sub]*family */$1/i;
		if ( $dbg ) { print "  std P450.1d: $common_name\n" }

		$common_name =~ s/(P450 family *[0-9]+[a-d]{0,1})[^ ]*/$1/i;
		if ( $dbg ) { print "  std P450.1e: $common_name\n" }

		$common_name =~ s/(P450 family) *[a-z]\b/$1/i;
		if ( $dbg ) { print "  std P450.1f: $common_name\n" }

	}
	
	$common_name =~ s/\bP450[, ]*[a-z]*family *[cyp]*([0-9]+)-*[a-z0-9]*\b/P450 family $1/gi;
	if ( $dbg ) { print "  std P450.3a: $common_name\n" }

	$common_name =~ s/\b(P450 *[a-z]*family)[, ]*([0-9]+)[-a-z0-9]*[, ]+($protypes) *[0-9a-z]{1,3}\b/$1 $2 $3/gi;
	$common_name =~ s/family[, ]*([-a-z0-9]+)[, ]*($protypes) *[0-9a-z]{1,3}\b/family $1 $2/gi;
	if ( $dbg ) { print "  std P450.8a: $common_name\n" }

	$common_name =~ s/P450 *family *[a-z][, ]/P450 family/g;
	$common_name =~ s/P450 *family *[a-z]$/P450 family/g;
	if ( $dbg ) { print "  std P450.8c: $common_name\n" }

	while ( $common_name =~ /\b(cyp([0-9]+)-*[a-z]{0,1}[a-z0-9]{0,5})\b/i ) {
		my $cyp = $1;
		my $num = $2;
		if ( $common_name !~ /family\b/i && $common_name !~ /\bP450\b/i ) {
			$common_name =~ s/[-:;, ]*$cyp\b/ cytochrome P450 family $num/i;
		}
		elsif ( $common_name !~ /family/i ) {
			$common_name =~ s/[-:;, ]*$cyp/ family $num/i;
		}
		else {
			$common_name =~ s/\b$cyp\b/$num/i;
		}
		if ( $dbg ) { print "  std P450.9: $common_name\n" }
#print "while31: $common_name\n";
	}
	$common_name =~ s/P450 family enzyme/P450 family protein/gi;
	$common_name =~ s/^([^;\/]*ase)[-, ]*(cytochrome P450 family *[0-9]+[^ ]*)/$2 $1/;
	$common_name =~ s/^([^;\/]*ase)[-, ]*(cytochrome P450 family)/$2 $1/;
	if ( $dbg ) { print "  std P450 final: $common_name\n" }

	# 14-3-3/4F5/Lsm imply family
	if ( $common_name =~ /\b(LSm|14-3-3|4F5)\b/ && $common_name !~ /\b(like|related|[a-z]*family)\b/i ) {
		$common_name =~ s/\b(LSm|14-3-3|4F5)\b/$1 family/i;
	}
	if ( $dbg ) { print "  std weirdfam: $common_name\n" }

	# remove explanatory phrases
	my @phrases = split /, /, $common_name;
	my $new;
	for my $phrase ( @phrases ) {
		$phrase =~ s/^ +//;
		$phrase =~ s/ +$//;
		my @tmp = split / +/, $phrase;
		my $lovalue = 0;
		my $midvalue = 0;
		my $hivalue = 0;;
		for my $word ( @tmp ) {
			$word =~ s/\W+$//;
			$word =~ s/^\W+//;
			if ( $word =~ /^[a-z]{1,3}$/ ) {
				$lovalue += 6 - length( $word );
			}
			elsif ( $word =~ /^(this|that|then|than|only|these|those|their|there|here|from|with|where|trans|towards*|also|other|such)$/ ) {
				$lovalue += 3;
			}
			elsif ( $word =~ /(play|belong|implicat|hav|involv|perform)(ed|es|e|s|ing){0,1}$/ ) {
				$lovalue += 3;
			}
			elsif ( $word =~ /^[a-z]{4}$/ ) {
				$midvalue += 2;
			}
			else {
				$word =~ s/\W//g;
				$hivalue += 6;
			}
		}
		if ( $lovalue > 9 ) { next }
		if ( 1.5 * $lovalue >= $midvalue + $hivalue ) { next }
		if ( ! defined $new ) {
			$new = $phrase;
		}
		else {
			$new .= ", $phrase";
		}
	}
	if ( ! defined $new ) { $new = "" }
	if ( $common_name ne $new ) {
		print "retain \"$new\" from \"$common_name\"\n";
		$common_name = $new;
	}
	if ( $dbg ) { print " std digressions: $common_name\n" }
	
	# of the/domain in
	if ( $common_name =~ / of the / ) {
		my $new = "";
		for my $phrase ( split /, /, $common_name ) {
			if ( $phrase =~ /^(.*) of the (.*)$/ ) {
				$phrase = "$2 $1";
			}
			if ( $new gt "" ) { $new .= ", " }
			$new .= $phrase;
		}
		$common_name = $new; 
		if ( $dbg ) { print " std of the: $common_name\n" }
	}
#	if ( $common_name =~ /($domains)[- ][-0-9 ]*(in|of|from)/i ) {	
#		my $new = "";
#		for my $phrase ( split /, /, $common_name ) {
#			if ( $phrase =~ /^(.*($domains))[- ]([-0-9 ]*)(in|of|from)(.*)$/i ) {
#				my $dom = $1;
#				my $typ = $5;
#				my $det = $3;
#				$typ =~ s/^ +//;
#				if ( $typ !~ /(like|related)$/i ) { $typ .= "-like" }
#				$det =~ s/  +/ /g;
#				$phrase = "$typ $dom $det";
#				$phrase =~ s/[- ]+$//;
#			}
#			if ( $new gt "" ) { $new .= ", " }
#			$new .= $phrase;
#		}
#		$common_name = $new; 
#		if ( $dbg ) { print " std domain in $common_name\n" }
#	}

	# make sure we have a valid ending
	my $endOK = 0; 
	if ( $common_name =~ /\b($protypes) +([-a-z0-9]+\b(like|related))$/i ) {
		$common_name =~ s/\b($protypes)[- ]*+([-a-z0-9]+\b(like|related))$/$2 $1/i;
		$is_related = 0;
	}
	
	# protein kingdom => kingdom protein
	$common_name =~ s/\b($protypes)[- ]*($kingdoms)$/$1/i;

	# allow protein at start of name?
	$common_name =~ s/($subunits) +protein\b/$1/gi;
	$common_name =~ s/^protein +(of|with|for) +//i;
	if ( $common_name =~ /^protein *($keeppros|[a-z]{3,}ase|lyase)\b/i ) {
		if ( $dbg ) { print "  std root1: $common_name\n" }
	}
	elsif ( $common_name =~ /^protein\W+(.*)/i ) {
		my $main = $1;
		if ( $dbg ) { print "  std root2: $common_name | $main\n" }
		$common_name = $main;
		if (  is_protein_name( $main ) ) {
			$endOK = 1;
			if ( $dbg ) { print "  std root3: $common_name\n" }
		}
	}
	elsif ( ! $is_related && is_protein_name( $common_name ) ) {
		$endOK = 1;
		if ( $dbg ) { print "  std root4: $common_name\n" }
	}
	
	# check for valid ending (protein|amidase (and other enzymes)|subunit|component|chaperone|etc)
	if ( $dbg ) { print "  std root endok=0: $common_name\n" } 
	if ( $common_name =~ /^(.*($goodends)) +([^ ]+) +protein/i ) {
		my $root = $1;
		my $ending = $3;
		if ( $dbg ) { print "  std root endok=?: root: $root  ending: $ending\n" } 
		if ( $root !~ /($badends)$/i ) {
			my $flag = is_protein_detail( $ending );
			if ( $dbg ) { print "ending $ending  flag $flag\n" }
			if ( $flag > 1 ) {
				$common_name = $root;
				$endOK = 1;
				if ( $dbg ) { print "  std root endOK=0a: $common_name\n" }
			}
			elsif ( $flag > 0 ) {
				$common_name = "$root $ending";
				$endOK = 1;
				if ( $dbg ) { print "  std root endOK=0b: $common_name\n" }
			}
		}
	}
	if ( ! $endOK && $common_name =~ /^(.*($goodends)) +([^ ]+)$/i ) {
		my $root = $1;
		my $ending = $3;
		if ( $dbg ) { print "  std root endok=?: root: $root  ending: $ending\n" } 
		if ( $root !~ /($badends)$/i ) {
			my $flag = is_protein_detail( $ending );
			if ( $dbg ) { print "ending $ending  flag $flag\n" }
			if ( $flag > 1 ) {
				$common_name = $root;
				$endOK = 1;
			}
			elsif ( $flag > 0 ) {
				$common_name = "$root $ending";
				$endOK = 1;
			}
		}
	}
	if ( ! $endOK && $common_name =~ /^(.*($goodends)) +protein$/i ) {
		my $root = $1;
		if ( $dbg ) { print "  std root endok=?: root: $root\n" } 
		if ( $root !~ /($badends)$/i ) {
			$common_name = $root;
			$endOK = 1;
			if ( $dbg ) { print "  std root endOK=0c: $common_name\n" }
		}
	}
	if ( ! $endOK ) {
		my $basename = base_protein_name( $common_name );
		if ( $basename =~ /($goodends)$/i && $basename !~ /($badends)$/i ) {
			$endOK = 1;
			if ( $dbg ) { print "  std root endOK=1b: $basename (from \"$common_name\")\n" }
		}
		elsif ( $basename !~ / / && is_protein_name( $basename ) ) {
			$endOK = 1;
			if ( $dbg ) { print "  std root endOK=1c: $basename (from \"$common_name\")\n" }
		}
		else {
			if ( $dbg ) { print "  std root endOK=0d: $basename (from \"$common_name\")\n" }			
		}
	}

	# append protein if we do not have a valid ending
	if ( ! $endOK ) {
		if ( $common_name =~ /^(.*) +([^ ]+)$/ ) {
			my $root = $1;
			my $ending = $2;
			my $is_detail = is_protein_detail( $ending );
			if ( $dbg ) { print "14.2: \"$root\"  ending: \"$ending\"\n" }
			if ( $root =~ /\b($goodends)$/i && $root !~ /($badends)$/i ) {
				if ( $is_detail > 1 ) {
					$common_name = $root;
				}
				elsif ( $is_detail > 0 ) {
					$common_name = "$root $ending";
				}
				else {
					$common_name .= " protein";
				}
			}
			elsif ( $is_detail < 2 ) {
				$common_name = "$root $ending protein";
				if ( $dbg ) { print "  std end1: $common_name\n" }
			}
			elsif ( $is_detail == 2
					&& $ending !~ /($groups|kDa)$/i
					&& $root !~ /\b([a-z]*family|$groups)$/i ) {
				$common_name = "$root protein $ending";
				if ( $dbg ) { print "  std end2: $common_name\n" }
			}
			else {
				$common_name .= " protein";
				if ( $dbg ) { print "  std end3: $common_name\n" }
			}
		}
		else {
			$common_name .= " protein";
			if ( $dbg ) { print "  std end4: $common_name\n" }
		}
		$endOK = 1;
	}
	$common_name =~ s/family, *protein/family protein/gi;
	if ( $dbg ) { print "  std endfinal: $common_name\n" }

	
	# transferase/monoxygenase not allowed alone
	if ( $common_name =~ /^W*(transferase|monoxygenase)s*\W*$/i ) {
		$common_name = "$1-like protein";
		$is_related = 0;
	}
	if ( $dbg ) { print "  std not-alone: $common_name\n" }
	
	# remove hypheh from nnn-kDa
	$common_name =~ s/-kDa\b/ kDa/g;
	
	# remove empty parens (etc)
	$common_name =~ s/\( *\)//gi;
	$common_name =~ s/\[ *\]//gi;
	$common_name =~ s/\{ *\}//gi;
	if ( $dbg ) { print "  std: emptyparens2: $common_name\n" }

	# remove redundant phrases
	$common_name = remove_redundant_phrases( $common_name );
	if ( $dbg ) { print "  std redundantphrases: $common_name\n" }

	# trim small words leftover at start/end
	$common_name = trim_small_words( $common_name );
	
	# remove leading parenthesis
	$common_name =~ s/^ *\(([^\)]{3,})/$1/;
	$common_name =~ s/^ *\[([^\]]{3,})/$1/;
	$common_name = balance_parens( $common_name );
	if ( $dbg ) { print "  std balance2: $common_name\n" }

	# remove protein #s
	if ( $common_name !~ /chromosome[- ]*[0-9a-z]+[- ]*(ORF|open)\b/i ) {
		$common_name =~ s/[- ]+[0-9.]+\/[0-9.]+-(like|related)/-like/gi;
		$common_name =~ s/[- ]+[0-9.]+-(like|related)/-like/gi;
		$common_name =~ s/($protypes|$enzymes)[- ]*[0-9.]+\/[0-9.]+$/$1/gi;
		$common_name =~ s/($protypes|$enzymes)[- ]*[0-9.]+$/$1/gi;
		if ( $dbg ) { print "  std prot#: $common_name\n" }
	}

	# restore related
	if ( $is_related && $common_name !~ /\b(like|related)\b/i ) {
		if ( $common_name =~ /[- ]+protein$/i ) {
			$common_name =~ s/[- ]+protein$/-like protein/i;
		}
		else {
			$common_name .= "-like protein";
		}
		if ( $dbg ) { print "  std related: $common_name\n" }
	}

	$common_name =~ s/\b(related|like)[-, ]*(related|like)\b/like/gi;
	$common_name =~ s/(family|domain|repeat|motif)[- ]*(like|related)/$1/gi;
	$common_name =~ s/(\w) +(like|related)/$1-$2/gi;
	$common_name =~ s/[- ]+like[- ]*([^ ]*like)\b/-$1/gi;
	$common_name =~ s/ +protein[-, ]*related *protein$/-like protein/i;
	$common_name =~ s/(repeat|domain|motif) +([a-z]*family)/$1/gi;
	$common_name =~ s/ [a-z]*family +([a-z]*family)/ $1/gi;
	$common_name =~ s/([a-z])[- ]+($protypes)[- ]+([^ ]*-(like|related))[- ]+protein\b/$1 $3 protein/i;
	while ( $common_name =~ /\b($domains)[- ]*(repeat|domain|motif)\b/i ) {
		$common_name =~ s/\b($domains)[- ]*(repeat|domain|motif)\b/$1/i;
#print "while32: $common_name\n";
	}
	if ( $dbg ) { print "  std protfam/protdom: $common_name\n" }
	
	# invert awkward phrasing, e.g. protease, XYZ family => XYZ family protease
	if ( $common_name !~ /terminal/i ) {
		if ( $common_name =~ /^($goodends), *(.*\b([a-z]*family|$domains|$groups|like|related|protein) *($greek|$roman|[a-zA-Z0-9]{1,3})*)$/i ) {
			my $ptype = $1;
			my $descr = $2;
			if ( $dbg ) { print "  std phrasing1a: \"$ptype\" and \"$descr\"\n" }
			if ( $descr !~ /^ *([a-z]*family|domain|repeat|motif|$groups|like|related) *protein$/i ) {
				$descr =~ s/ *protein$//;
				if ( $ptype !~ /\b($badends)$/i && $ptype !~ /\b($gerunds)$/i && length( $descr ) < 40 && $descr !~ /[?;,&]/ ) {
					$common_name = "$descr $ptype";
					if ( $dbg ) { print "  std phrasing1b: $common_name\n" }
				}
			}
		}
		elsif ( $common_name =~ /^([-+a-z0-9]+ +($goodends)), (.*\b([a-z]*family|$domains|$groups|like|related|protein) *($greek|$roman|[a-zA-Z0-9]{1,3})*)$/i ) {
			my $ptype = $1;
			my $descr = $3;
			if ( $dbg ) { print "  std phrasing2a: \"$ptype\" and \"$descr\"\n" }
			if ( $descr !~ /^ *([a-z]*family|domain|repeat|motif|$groups|like|related) *protein$/i ) {
				$descr =~ s/ *protein$//;
				if ( $ptype !~ /\b($badends)$/i && $ptype !~ /\b($gerunds)$/i && length( $descr ) < 40 && $descr !~ /[?;,&]/ ) {
					$common_name = "$descr $ptype";
					if ( $dbg ) { print "  std phrasing2b: $common_name\n" }
				}
			}
		}
	}
	
	# clean-up protein-like protein (and such)
	$common_name =~ s/(\w)[- ]+protein[- ]+(like|related)[- ]+protein$/$1-$2 protein/;
	$common_name =~ s/\bprotein[- ]+(related|like)[- ]+([a-z]*family)/ $2/gi;
	$common_name =~ s/[- ]+(related|like)[- ]+([a-z]*family)/ $2/gi;
	$common_name =~ s/[- ]+(related|like)[- ]+protein[- ]+([a-z]*family)/ $2/gi;
	$common_name =~ s/(family) *([0-9a-z]+?)[- ]+like\b/$1 $2/i;
	if ( $dbg ) { print "  std protlike/likeprot: $common_name\n" }

	# restore putative
	if ($is_putative) {
		$common_name .= ", putative";
		if ( $dbg ) { print "  std putative: $common_name\n" }
	}
	
	# final cleanups
	$common_name =~ s/(family|$domains) *-[- ]*($protypes)/$1 $2/gi;
	$common_name =~ s/($protypes|$enzymes)[- ]*protein/$1/gi;
	$common_name =~ s/[, ]*- *(like|related)/-$1/gi;
	
	# leading/trailing/consecutive comma/dash/slash/blank
	$common_name =~ s/ *-+ */-/g;
	$common_name =~ s/^ +//g;
	$common_name =~ s/  +/ /g;
	$common_name =~ s/ +$//g;
	$common_name =~ s/ +([-,])/$1/g;
	$common_name =~ s/([-,] +)/$1/g;
	$common_name =~ s/--+/-/g;
	$common_name =~ s/,,+/,/g;
	$common_name =~ s/[-, ]*\/[-, ]*/\//g;
	$common_name =~ s/^[-, \/]+//;
	$common_name =~ s/[-, \/]+$//;
	$common_name =~ s/  +/ /g;
	$common_name =~ s/-and\b/- and/g;	
	if ( $dbg ) { print " std final: $common_name\n" }
	
	# check for forbidden content
	my $rejection = rejected_name( $common_name );
	if ( $rejection > 0 ) {
		if ( $dbg || $verbose ) { print "  std discarding ($rejection): \"$orig\"\n" }
		$common_name = "";
	}

	# dbg output
	elsif ( $dbg || $verbose ) {
		my $o = lc( $orig );
		$o =~ s/\W//g;
		$o =~ s/protein//g;
		my $c = lc ( $common_name );
		$c =~ s/\W//g;
		$c =~ s/protein//g;
		if ( $o ne $c ) { print "changed \"$orig\" to \"$common_name\"\n" }
	}
	
	# return result
	return $common_name;
}

sub remove_redundant_phrases {
	my ( $name ) = @_;
	
	my @tmp = split /, +/, $name;
	if ( @tmp < 2 ) { return trim_small_words( $name ) }
	
	my %phrases;
	my $phr = 0;
	for my $phrase ( @tmp ) {
		$phrase = trim_small_words( $phrase );
		$phr++;
		my $normalized = lc( $phrase );
		$normalized =~ s/\W/ /g;
		$normalized =~ s/^ +//;
		$normalized =~ s/  +/ /g;
		$normalized =~ s/ +$//;
		$phrases{$phr}{normalized} = $normalized;
		$phrases{$phr}{text} = $phrase;
	}
	for my $p1 ( keys %phrases ) {
		if ( ! exists $phrases{$p1} ) { next }
		if ( length( $phrases{$p1}{normalized} ) < 6 ) { next }
		for my $p2 ( keys %phrases ) {
			if ( $p1 == $p2 ) { next }
			if ( length( $phrases{$p2}{normalized} ) < 6 ) { next }
			if ( index( $phrases{$p2}{normalized}, $phrases{$p1}{normalized} ) >= 0 ) {
				delete $phrases{$p1};
				last;
			}
		}
	}
	
	@tmp = ();
	for my $p ( sort { $a <=> $b } keys %phrases ) {
		push @tmp, $phrases{$p}{text};
	}
	
	my $newname = balance_parens( join( ", ", @tmp ) );
	if ( $newname ne $name && $verbose ) {
		print "redundant $name => $newname\n";
	}
	return $newname;
}

sub trim_small_words {
	my ( $common_name ) = @_;
	
	while ( $common_name =~ /^ *(or|a|to|in|of|by|is|and|the|from|for|with|has|had|have|having|this|these|that|which|who|where) +/ ) {
		$common_name =~ s/^ *(or|a|to|in|of|by|is|and|the|from|for|with|has|had|have|having|this|these|that|which|who|where) +//;
	}
	while ( $common_name =~ / +(or|a|to|in|of|by|is|and|the|from|for|with|has|had|have|having|this|these|that|which|who|where) *$/ ) {
		$common_name =~ s/ +(or|a|to|in|of|by|is|and|the|from|for|with|has|had|have|having|this|these|that|which|who|where) *$//;
	}
	
	return $common_name;
}

sub balance_parens {
	my ( $common_name ) = @_;
	my $dbg = 0;

	# clean up spacing/punctuation
	$common_name =~ s/\([-:;,. \\\/]+/\(/g;
	$common_name =~ s/[-:;, \\\/]+\)/\)/g;
	$common_name =~ s/\[[-:;,. \\\/]+/\[/g;
	$common_name =~ s/[-:;, \\\/]+\]/\]/g;
	if ( $dbg ) { print "  ()1: $common_name\n" }

	# balance parenthesis
	$common_name =~ s/ +\)/\)/g;
	while ( $common_name =~ /\(([^()]+)\)/ ) { 
		if ( $common_name =~ /^\(([^()]+)\)$/ ) {
			$common_name = $1;
		}
		$common_name =~ s/\(([^()]+)\)/!{!$1!}!/;
		if ( $dbg ) { print "()2: $common_name\n" }
	}

	$common_name =~ s/\)[-:;,. ]*/, /g;
	$common_name =~ s/[-:;,. ]*\(/, /g;
	$common_name =~ s/^[, ]+//;
	$common_name =~ s/[, ]+$//;

	$common_name =~ s/!{!/\(/g;
	$common_name =~ s/!}!/\)/g;
	$common_name =~ s/\( +/\(/g;
	$common_name =~ s/ +\)/\)/g;
	if ( $dbg ) { print "()3: $common_name\n" }

	# balance brackets
	$common_name =~ s/ +\]/\]/g;
	while ( $common_name =~ /\[([^\]\]]+)\]/ ) { 
		if ( $common_name =~ /^\[([^\]\]]+)\]{0,1}$/ ) {
			$common_name = $1;
		}
		$common_name =~ s/\[([^\]\[]+)\]/!{!$1!}!/;
		if ( $dbg ) { print "()4: $common_name\n" }
	}

	$common_name =~ s/\][-:;,. ]*/, /g;
	$common_name =~ s/[-:;,. ]*\[/, /g;
	$common_name =~ s/^[, ]+//;
	$common_name =~ s/[, ]+$//;

	$common_name =~ s/!{!/\[/g;
	$common_name =~ s/!}!/\]/g;
	$common_name =~ s/\[ +/\[/g;
	$common_name =~ s/ +\]/\]/g;
	if ( $dbg ) { print "()5: $common_name\n" }
	
	return $common_name;
}

sub does_name2_imply_name1 {
	my ( $name1, $name2, $assumed_phrase ) = @_;
	my $dbg = 0;
	if ( $dbg ) { print "\nimply: $name2 => $name1\n" }

	my $norm1 = normalize_name($name1, 0, $assumed_phrase);
	my $norm2 = normalize_name($name2, 0, $assumed_phrase);		
	if ( $dbg ) { print "  norm: $norm2 => $norm1\n" }

	# N/C-terminal names cannot imply names without
	if ( $norm2 =~ /CTM/ && $norm1 !~ /CTM/ ) { return 0 }	
	if ( $norm2 =~ /NTM/ && $norm1 !~ /NTM/ ) { return 0 }

	# does name2 contain all of the keywords from name1?
	my $tot1  = 0;
	my $match1  = 0;
	my $keys1 = get_keywords( $name1, 2, $assumed_phrase );    # exclude "family" (etc) and compound words
	my $keys2 = get_keywords( $name2, 1, $assumed_phrase );    # exclude compound words

	for my $key ( keys %{ $$keys1{keywgt} } ) {
		if ( $key =~ /^(FAM|[dglp]FA|CTM|NTM)$/ ) { next }
		$tot1 += $$keys1{keywgt}{$key};
		if ( exists $$keys2{keywgt}{$key} ) {
			$match1 += $$keys1{keywgt}{$key};
		}
		if ( $dbg ) { print "  \"$key\"  $match1 / $tot1\n" }
	}
	if ( $dbg ) { print "  final  $match1 / $tot1\n" }
	if ( $match1 > 0.99 * $tot1 ) { return 1 }	
	
	return 0;
}

sub quick_does_name2_imply_name1 {
	my ( $keys1, $keys2 ) = @_;
	my $dbg = 0;

	my $norm1 = $$keys1{normalized};
	my $norm2 = $$keys2{normalized};
	if ( $dbg ) { print "  norm: $norm2 => $norm1\n" }

	# N/C-terminal names cannot imply names without
	if ( $norm2 =~ /CTM/ && $norm1 !~ /CTM/ ) { return 0 }	
	if ( $norm2 =~ /NTM/ && $norm1 !~ /NTM/ ) { return 0 }

	# does name2 contain all of the keywords from name1?
	my $tot1 = 0;
	my $match1 = 0;
	for my $key ( keys %{ $$keys1{keywgt} } ) {
		if ( $key =~ /^(FAM|[dglp]FA|CTM|NTM)$/ ) { next }
		$tot1 += $$keys1{keywgt}{$key};
		if ( exists $$keys2{keywgt}{$key} ) {
			$match1 += $$keys1{keywgt}{$key};
		}
		if ( $dbg ) { print "  \"$key\"  $match1 / $tot1\n" }
	}
	if ( $dbg ) { print "  final  $match1 / $tot1\n" }
	if ( $match1 > 0.99 * $tot1 ) { return 1 }	
	
	return 0;
}

sub keywords1_contained_by_keywords2 {
	my ( $keywords1, $keywords2 ) = @_;
	
	my $match = 0;
	for my $kw ( keys %{ $$keywords1{keywgt} } ) {
		if ( ! exists $$keywords2{keywgt}{$kw} ) { return 0 }
		$match = 1;
	}
	return $match;
}

sub keyword_similarity {
	my ( $keywords1, $keywords2 ) = @_;
	my $dbg = 0;

	my $tot1 = 0;
	my $match1 = 0;
	my %missed1;
	for my $kw ( keys %{ $$keywords1{keywgt} } ) {
		$tot1 += $$keywords1{keywgt}{$kw};
		if ( exists $$keywords2{keywgt}{$kw} ) {
			$match1 += $$keywords1{keywgt}{$kw};
		}
		else {
			$missed1{$kw} += $$keywords1{keywgt}{$kw};
		}
	}

	my $tot2 = 0;
	my $match2 = 0;
	my %missed2;
	for my $kw ( keys %{ $$keywords2{keywgt} } ) {
		$tot2 += $$keywords2{keywgt}{$kw};
		if ( exists $$keywords1{keywgt}{$kw} ) {
			$match2 += $$keywords2{keywgt}{$kw};
		}
		else {
			$missed2{$kw} = $$keywords2{keywgt}{$kw};
		}
	}

	if ( $dbg ) {
		print "k1: " . join( " ", sort { $b cmp $a } keys %{ $$keywords1{keywgt} } ) . "\n";
		print "k2: " . join( " ", sort { $b cmp $a } keys %{ $$keywords2{keywgt} } ) . "\n";
		
		print "match1: $match1/$tot1\n";
		print "match2: $match2/$tot2\n";
	}	
	
	if ( $tot1 < 0.75 ) { $tot1 = 0.75 }
	if ( $tot2 < 0.75 ) { $tot2 = 0.75 }
	
	for my $m1 ( sort { $$keywords1{keywgt}{$b} <=> $$keywords1{keywgt}{$a} } keys %missed1 ) {
		my $x1 = lc( $m1 );
		$x1 =~ s/[^a-z0-9]/ /g;
		$x1 =~ s/  +/ /g;
		$x1 =~ s/^ //;
		$x1 =~ s/ $//;
		for my $m2 ( sort { $$keywords2{keywgt}{$b} <=> $$keywords2{keywgt}{$a} } keys %missed2 ) {
			my $x2 = lc( $m2 );
			$x2 =~ s/[^a-z0-9]/ /g;
			$x2 =~ s/  +/ /g;
			$x2 =~ s/^ //;
			$x2 =~ s/ $//;
			if ( $x1 eq $x2 ) {
				$match1 +=  $$keywords1{keywgt}{$m1} / 2.0;
				$match2 +=  $$keywords2{keywgt}{$m2} / 2.0;
				delete $missed2{$m2};
				last;
			}
			if ( $x1 =~ /\b$x2\b/ || $x2 =~ /\b$x1\b/ ) {
				$match1 +=  $$keywords1{keywgt}{$m1} / 2.0;
				$match2 +=  $$keywords2{keywgt}{$m2} / 2.0;
				delete $missed2{$m2};
				last;
			}
		}
	} 

	my $pct1 = $match1 / $tot1;
	my $pct2 = $match2 / $tot2;
	if ( $dbg ) {
		print "k1: " . join( " ", sort { $b cmp $a } keys %{ $$keywords1{keywgt} } ) . "\n";
		print "k2: " . join( " ", sort { $b cmp $a } keys %{ $$keywords2{keywgt} } ) . "\n";
		
		print "revised match1: $pct1=$match1/$tot1\n";
		print "revised match2: $pct2=$match2/$tot2\n";
	}	
	
	my $sim = 0.0;
	if ( $pct1 > 0.0 && $pct2 > 0.0 ) {
		if ( defined $$keywords1{normalized} && defined $$keywords2{normalized} ) {
			my $wgt1 = $$keywords1{keywgt};
			my $wgt2 = $$keywords2{keywgt};
			my $log1 = log( $pct1 );
			my $log2 = log( $pct2 );		
			$sim = exp( ( $wgt1 * $log1 + $wgt2 * $log2 ) / ( $wgt1 + $wgt2 ) );
		}
		else {
			$sim = sqrt( $pct1 * $pct2 );
		}
	}
	if ( $dbg ) { print "final sim=$sim\n" }
	
	return $sim;
}
1;