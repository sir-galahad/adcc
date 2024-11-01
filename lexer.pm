#!/usr/bin/perl

package lexer; 
use strict;
use warnings;
use Switch;
use JSON;
use Exporter 'import';

our @EXPORT = qw( Tokenize WriteObject );

sub appendToken {
	 push @{$_[0]}, {type => $_[1], value => $_[2], line => $_[3]}
}

sub Tokenize {
	my $constClass = "[0-9]";
	my $startChars = "a-zA-Z_";
	my $followingChars = "${startChars}0-9";
	my $startClass = "[$startChars]";
	my $followingClass = "[$followingChars]";
	my @tokens=();
	my @types = qw (int void);
	my @keywords = qw (return);
	push(@keywords, @types);
	
	open(my $file,"<", $_[0]);
	my $linenum = 1;
	my $inComment=0;
	while(my $line=<$file>) {
		my $counter = 0;
		chomp $line;
		while ($counter < length($line)) {
			$_=substr($line,$counter);
			my $match = "";
			if(! $inComment) {
				if(/^(\s+)/)                            { } # do nothing whitespace 
				elsif(m#^(//.*)$#)                      { } # do nothing comment
				elsif(m#^(/\*.*?\*/)#)                  { } # do nothing comment
				elsif(m#^(/\*.*)$#)                     {$inComment = 1} # do nothing comment
				elsif(/^([;])/)                         { appendToken (\@tokens, $1, $1, $linenum ) }
				elsif(/^(\d+)([^a-zA-Z_]|$)/)           { appendToken (\@tokens, "constant",$1,$linenum) }
				elsif(/^([()])/)                        { appendToken (\@tokens, $1,$1,$linenum) }
				elsif(/^([{}])/)                        { appendToken (\@tokens, $1,$1,$linenum) }
				elsif(/^([-]{1,2}|~)/)                   	    { appendToken (\@tokens, "operator", $1, $linenum)	}
				elsif(/^($startClass$followingClass*)/) { 
															my $iden = $1;
															if( grep(/$iden/, @types) ) {
																appendToken(\@tokens, "type", $iden, $linenum);
															} elsif ( grep(/$iden/, @keywords) ) {
																appendToken(\@tokens, $iden, $iden, $linenum);
															} else {
																appendToken(\@tokens, "identifier", $1, $linenum)
															}
														}
				else { die "error at line: $linenum"}
				$match = $1;
			} else {
				if(m#^(.*?\*/)#) {$inComment = 0 ; $match = $1}
				else {$match=$_; } #if comment doesn't end on this line mathc it all
			}
			$counter+=length($match);
		}
		$linenum++;
	}
	
	close($file);
	return \@tokens;
}

sub WriteObject {
	my $filename = shift @_;
	my $object = shift @_;
	open(my $file,">",$filename);
	print $file encode_json($object);
	close $file;
}
1
