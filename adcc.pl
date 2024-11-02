#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use adcc::parser::x86_64aast;
use adcc::parser::cast;
use adcc::parser::totac;
use adcc::lexer;
use adcc::x86_64emit;

my @flags = grep(/^--/,@ARGV);
my @files = grep(!/^--/,@ARGV);

my $stopAfter = '';

open(my $fh, ">", "/home/aaron/adcc.log") or die("couldn't open log file\n");
print $fh "@flags\n";
print $fh "@files\n";
close($fh);

# provide flags for unit tests and debugging each flag will end the compilation
# process at the named stage and output the code representation at that point 
# in the process
foreach my $flag (@flags) {
	if( $flag eq "--lex") {$stopAfter = "lex";}
	elsif( $flag eq "--parse") {$stopAfter = "parse";}
	elsif( $flag eq "--tacky") {$stopAfter = "tacky";}
	elsif( $flag eq "--codegen") {$stopAfter = "codegen";}
}

foreach my $file (@files) {
	my $tokens = Tokenize($file);
	if( $stopAfter eq "lex") {
		WriteObject("$file.tok", $tokens);
		next;
	}
	
	my $cast = ParseTokens($tokens);

	if( $stopAfter eq "parse") {
		WriteObject("$file.cast", $cast);
		next;
	}

	my $TAC = CastToTAC($cast);
	if( $stopAfter eq "tacky") {
		WriteObject("$file.tac", $TAC);
		next;
	}

	my $aast = TACToAast($TAC);	

	if($stopAfter eq "codegen") {
		WriteObject("$file.aast", $aast);
		next;
	}
	
	my $lines = EmitObject($aast);
	
	my $outfile = $file;

	$outfile =~ s/[.]c$/.s/;
	open(my $f, ">",$outfile) or die "could not open $outfile for writing";

	foreach my $l (@$lines) {
		print $f "$l\n";
	}
	close $f;
	my $executable = $outfile;
	$executable =~ s/[.]s//;
	`gcc $outfile -o $executable`;
}	
