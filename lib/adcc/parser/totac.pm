package adcc::parser::totac;

use strict;
use warnings;

use Exporter 'import';
use Data::Dumper;
our @EXPORT = qw ( CastToTAC );

# Convert C AST to TAC tree

sub CastToTAC {
	my $cast = shift @_;
	my $tacTree = {functions=>[]};
	foreach my $stmnt (@{$cast->{statements}}) {
		if($stmnt->{statement_type} eq "function") {
			my $function = FunctionToTAC($stmnt);
			push @{$tacTree->{functions}}, $function;
		}
	}

	return $tacTree;	

}

sub FunctionToTAC {
	my $castFunction = shift @_;
	my $TACFunction = {
		name => $castFunction->{name},
		returnType => $castFunction->{return_type},
		arguments => $castFunction->{arguments},
		internalVarCounter => 0,
		operations=>[],
	};

	my $operations;	
	foreach my $stmnt (@{$castFunction->{statements}}) {
		$operations = StatementToTAC($TACFunction, $stmnt);
	}

	for my $op (@$operations) {
		push @{$TACFunction->{operations}}, $op;
	}

	return $TACFunction;
}

sub StatementToTAC {
	my ($TACFunction, $stmnt) = @_;
	if($stmnt->{statement_type} eq 'return') {
		my $operationChain = ExpressionToTAC($TACFunction, $stmnt->{expression});
		push @$operationChain, { type=>"return", src=> $operationChain->[-1]{dest}};
		return $operationChain;
	}
	else {"invalid statement\n"};
}

sub ExpressionToTAC {
	my ($TACFunction, $exp) = @_;
	if($exp->{type} eq 'unaryOperation') {
		my $operationChain = ExpressionToTAC($TACFunction, $exp->{subexpression}[0]);
		my $myexp= { type => 'unaryOperation', 
		             operation => $exp->{operation}, 
		             dest => {type => 'pseudo', value => GetNextVarname($TACFunction)},
		             src  => $operationChain->[-1]{dest},
		};
		push @$operationChain, $myexp; 
		return $operationChain;
	}
	elsif($exp->{type} eq 'binaryOperation') {
		my $operationChainLeft = ExpressionToTAC($TACFunction, $exp->{subexpression}[0]);
		my $myexp= { type => 'binaryOperation', 
		             operation => $exp->{operation}, 
		             dest => {type => 'pseudo', value => GetNextVarname($TACFunction)},
		             left  => $operationChainLeft->[-1]{dest},
		};
		my $operationChainRight = ExpressionToTAC($TACFunction, $exp->{subexpression}[1]);
		$myexp->{right}=$operationChainRight->[-1]{dest};
		push @$operationChainLeft, @$operationChainRight; 
		push @$operationChainLeft, $myexp; 
		return $operationChainLeft;
	}
	elsif($exp->{type} eq "int") {
		return [{type => "int", src => {type => 'imm', value => $exp->{value}}, dest => {type=>'pseudo', value => GetNextVarname($TACFunction)} }];
	}
	else { die "unknown expression type $exp->{type}\n"}
}

sub GetNextVarname {
	my $TACFunction = shift @_;
	$TACFunction->{internalVarCounter}++;
	return "$TACFunction->{name}.$TACFunction->{internalVarCounter}";
}
