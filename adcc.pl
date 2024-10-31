#!/usr/bin/perl


use strict;
use warnings;
use lib '/home/aaron/compiler';
use parser::x86_64aast;
use parser::cast;
use lexer;
use x86_64emit;

my @flags = grep(/^--/,@ARGV);
my @files = grep(!/^--/,@ARGV);

my $stopAfter = '';

open(my $fh, ">", "/home/aaron/adcc.log") or die("couldn't open log file\n");
print $fh "@flags\n";
print $fh "@files\n";
close($fh);

foreach my $flag (@flags) {
	if( $flag eq "--lex") {$stopAfter = "lex";}
	elsif( $flag eq "--parse") {$stopAfter = "parse";}
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

	my $aast = CastToAast($cast);	

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
