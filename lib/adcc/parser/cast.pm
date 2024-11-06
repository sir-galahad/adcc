package adcc::parser::cast;

use strict;
use warnings;

use Exporter 'import';

our @EXPORT = qw( ParseTokens );

my %unaryOperations = ( 
	'--' => 'decrement',
	'-'  => 'negate',
	'~'  => 'bitnot',
	'++' => 'increment',
	'+'  => 'positive'
);

my %binaryOperations = (
	'+' => 'add',
	'-' => 'subtract',
	'*' => 'multiply',
	'/' => 'divide',
	'%' => 'modulo',
);

my %operatorPrecedence = (
	'+' => 10,
	'-' => 10,
	'*' => 20,
	'/' => 20,
	'%' => 20,
);
my @unaryPrefixOperators = keys %unaryOperations; 
my @binaryOperators = keys %binaryOperations; 

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
	my @tmptokens = map {$_->{type}} @$tokens;
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
	my ($tokens, $minPrecedence) = @_;
	my $left = ParseFactor($tokens);
	while( grep($tokens->[0]{value} eq $_, @binaryOperators), and $operatorPrecedence{$tokens->[0]{value}} > $minPrecedence ) {
		my $operator = shift @$tokens;
		my $right = ParseExpression($tokens,$operatorPrecedence{$operator->{value}}+1);
			
		$left = {type=>"binaryOperation", operation => $binaryOperations{$operator->{value}},  subexpression => [$left, $right]};
	}
	return $left;
}

sub ParseFactor {
	my $tokens = shift @_;
	my $tok = shift @$tokens;
	my $result;
	if($tok->{type} eq "constant") { $result = {type=>"int", value => $tok->{value}} }
	elsif($tok->{type} eq "(") { $result = ParseExpression($tokens,0); $tok = shift @$tokens; ExpectToken($tok,[")"]); }
	# prefix unary operator
	# + is allowed as a unary operator, but it does nothing
	elsif($tok->{type} eq "operator" and $tok->{value} eq "+") { $result = ParseExpression($tokens,0); }
	# rest of the unary operators
	elsif($tok->{type} eq "operator" and grep($tok->{value} eq $_ , @unaryPrefixOperators) ) { 
		die "decrement not yet supported \n" if($tok->{value} eq '--'); 
		die "increment not yet supported \n" if($tok->{value} eq '++'); 
		$result = {type=>"unaryOperation", operation => $unaryOperations{$tok->{value}},  subexpression => [ParseFactor($tokens)] };
	}
	else{ die "got $tok->{value} $tok->{type} where expression expected line:$tok->{line}\n" };
	return $result;
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
	my $expression = ParseExpression($tokens, 0);	
	$tok = shift @$tokens;
	ExpectToken($tok, [";"]);
	return {statement_type => "return", expression => $expression};
}

1
