
package adcc::parser::x86_64aast;

use strict;
use warnings;
use Data::Dumper;

use Exporter 'import';

our @EXPORT=qw(TACToAast);
#convert C abstract syntax tree to assembly abstract syntax tree

#translation tables
my %TopTT = ( # top table can really only be functions and declarations
	function => \&TranslateFunction,
);
my %TT = (
	return => \&TranslateReturn,
	unaryOperation => \&TranslateUnaryOp,
	int => \&TranslateInt,
);

sub TACToAast {
	my $TAC = shift @_;
	my $aast = {functions=>[]};
	foreach my $function (@{$TAC->{functions}}) {
		my $unit = $TopTT{function}($function);
		push @{$aast->{functions}}, $unit;
	}
	return $aast;
}

sub TranslateFunction {
	my $cfunction = shift @_;
	my $function = { 
		unit => "function", 
		name => $cfunction->{name}, 
		instructions => [], 
		pseudotable=>{},
		minStack=>0,
	};
	
	# 1st pass generate pseudo table"
	foreach my $instruction (@{$cfunction->{instructions}}) {
		# if we have a return type instruction
		if($instruction->{type} eq "return") { 
			$function->{pseudotable}{$instruction->{src}{value}} = {type => 'register', value=>'eax'};
			$function->{minStack} += 4;
		}

		AddPseudoEntry($instruction->{src}{value}, $function) if($instruction->{src}{type} and $instruction->{src}{type} eq "pseudo");
		AddPseudoEntry($instruction->{dest}{value}, $function) if($instruction->{dest}{type} and $instruction->{dest}{type} eq "pseudo");

	}	
	
	foreach my $instruction (@{$cfunction->{instructions}}) {
		if($instruction->{src}{type} and $instruction->{src}{type} eq "pseudo") {
			my $newSrc = $function->{pseudotable}{$instruction->{src}{value}};
			$instruction->{src}=$newSrc;
		}
		if($instruction->{dest}{type} and $instruction->{dest}{type} eq "pseudo") {
			my $newDst = $function->{pseudotable}{$instruction->{dest}{value}};
			$instruction->{dest}=$newDst;
		}
		my $instructions = $TT{$instruction->{type}}($instruction);
		push @{$function->{instructions}}, @$instructions;
	}
	return $function;
};

sub AddPseudoEntry {
	my ($varname, $function) = @_;
	unless (defined $function->{pseudotable}{$varname}) {
		$function->{minStack} -= 4;
		$function->{pseudotable}{$varname} = {type => 'stack', value => "$function->{minStack}(%rbp)"};
	}
	return
}
		

sub TranslateReturn {
	my $instruction = shift @_;
	my $instructions = [];
	my $retInstruction = {name => "ret", operands => []};
	push @$instructions, $retInstruction;
	return $instructions;
}

sub TranslateUnaryOp {
	my $instruction = shift @_;
	my $instructions = [];
	my %ops = (negate => 'negl', bitnot => 'notl' );

	my $operation = {name => $ops{$instruction->{operation}},  operands => [ $instruction->{src} ]};
	push @$instructions, $operation;

	if($instruction->{dest}{type} eq 'stack') {
		push @$instructions, {name => 'movl', operands => 
			[ $instruction->{src}, {type => 'register', value => 'r10d'} ] };
		push @$instructions, {name => 'movl', operands => 
			[ {type => 'register', value => 'r10d'}, $instruction->{dest} ] };
	}
	elsif($instruction->{dest}{type} eq 'register') {
		push @$instructions, {name => 'movl', operands => 
			[ $instruction->{src}, {type => 'register', value => 'eax'} ] };
	}
	return $instructions;
}

sub TranslateInt {
	my $instruction = shift @_;
	my $instructions = [];
	push @$instructions, {name => 'movl', operands => 
		[ $instruction->{src}, $instruction->{dest} ] };
	
	return $instructions;
}
	

1
