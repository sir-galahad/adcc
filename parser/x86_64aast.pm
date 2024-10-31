
package parser::x86_64aast;

use strict;
use warnings;
use Data::Dumper;

use Exporter 'import';

our @EXPORT=qw(CastToAast);
#convert C abstract syntax tree to assembly abstract syntax tree

#statement translation tables
my %TopSTT = ( # top table can really only be functions and declarations
	function => \&TranslateStatementFunction,
);
my %STT = (
	return => \&TranslateStatementReturn,
);

sub CastToAast {
	my $cast = shift @_;
	my $aast = {functions=>[]};
	foreach my $stmnt (@{$cast->{statements}}) {
		my $unit = $TopSTT{$stmnt->{statement_type}}($stmnt);
		if($unit->{unit} eq "function") {
			push @{$aast->{functions}}, $unit;
		}
	}
	return $aast;
}

sub TranslateStatementFunction {
	my $cfunction = shift @_;
	my $function = { unit => "function", name => $cfunction->{name}, instructions => []} ;
	foreach my $stmnt (@{$cfunction->{statements}}) {	
		my $instructions = $STT{$stmnt->{statement_type}}($stmnt);
		push @{$function->{instructions}}, @$instructions;
	}
	return $function;
};

sub TranslateStatementReturn {
	my $retStmnt = shift @_;
	my $instructions = [];
	my ($result_location, $expInstructions) = TranslateExpression($retStmnt->{expression});
	if(scalar @$expInstructions > 0) {
		push @$instructions, (@$expInstructions);
	}
	my $movInstruction = {name => "mov", operands => [
		{type => $result_location->{type}, value => $result_location->{value}},
		{type => "register", value=>"eax"},
	]};
	my $retInstruction = {name => "ret", operands => []};
	
	push @$instructions, $movInstruction;
	push @$instructions, $retInstruction;
	
	return $instructions;
	
		
}

sub TranslateExpression {
	my $exp = shift @_;
	my $result_location;
	if(defined $exp->{value}) {
		$result_location={type=>"Imm", value=>$exp->{value}};
		return ($result_location, []);
	}
	return (undef,undef);
}

1
