#!/usr/bin/perl

package parser::cast;

use strict;
use warnings;

use Exporter 'import';

our @EXPORT = qw( ParseTokens );

my @context;

sub CompareArray {
	my ($larray, $rarray) = @_;
	return 0 unless (@$larray == @$rarray);
	for my $indx (0..(@$larray)-1) {
		return 0 unless($larray->[$indx] eq $rarray->[$indx]);
	}
	return 1;
}

sub ExpectToken {
	my($token, $tokentypes) = @_;
	for my $tokentype (@$tokentypes) {
		if($tokentype eq $token->{type}) {
			return $token;
		}
	}	
	die "expected token (@$tokentypes)\n";
}

sub ParseTokens {

	my $tokens = shift @_;
	my $tree = {statements => []};
	
	while (scalar(@$tokens) > 0) {
		my $result = ParseStatement($tokens);
		if($result->{statement_type} eq 'function') {
			push @{$tree->{statements}}, $result;
		}
	}
	
	return $tree;
}

sub ParseStatement {
	my $tokens = shift @_;
	my @tmptokens = map {$_->{type}} @$tokens; # 10 is kind of arbitrary, that should be enough 
	if(CompareArray( [('type', 'identifier', '(') ], [@tmptokens[0..2]])) {
		return ParseFunction($tokens);
	} elsif ( $tmptokens[0] eq 'return' ) {
		return ParseReturnStatement($tokens);
	}
	my $tok = shift(@{$tokens});
	die "syntax error : $tok->{line}\n";
	return $tok;
}

sub ParseExpression {
	my $tokens = shift @_;
	my $tok = shift @$tokens;
	ExpectToken($tok,["constant"]);
	return {value => $tok->{value}};
}

sub ParseFunction {
	# add function to the context to allow use of "return"
	if(grep(/function/,@context)) { 
		die "functions cannot be nested\n";
	}
	push @context, "function";
	my $tokens = shift @_;
	my %function=(statement_type => 'function', arguments => [], statements => []);
	
	my $tok = shift @$tokens;
	$function{return_type}=$tok->{value};
	$tok = shift @$tokens;
	$function{name} = $tok->{value};
	$tok = shift @$tokens;
	ExpectToken($tok, ["("]);
	$tok = shift @$tokens;
	ExpectToken($tok, ["type"]);
	unshift @{$function{arguments}}, $tok->{value};
	$tok = shift @$tokens;
	ExpectToken($tok,[")"]);
	ExpectToken($tokens->[0],['{']);
	shift @$tokens;
	while((@$tokens) > 0 and $tokens->[0]{type} ne '}') {
		my $substatement = ParseStatement($tokens);
		#print "substatement @$substatement\n";
		push @{$function{statements}}, $substatement;
	}
	$tok = shift @$tokens;
	ExpectToken($tok, ["}"]);
	pop @context;
	return \%function;
}

sub ParseReturnStatement {	
	# add function to the context to allow use of "return"
	if(! grep(/function/,@context)) { 
		die "return outside of function\n";
	}
	my $tokens = shift @_;
	my $tok = shift @$tokens;
	die "compiler error parsing return in correctly" unless($tok->{value} eq "return");
	my $expression = ParseExpression($tokens);	
	$tok = shift @$tokens;
	ExpectToken($tok, [";"]);
	return {statement_type => "return", expression => $expression};
}

1
