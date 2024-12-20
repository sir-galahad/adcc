
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
	binaryOperation => \&TranslateBinaryOp,
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
	foreach my $operation (@{$cfunction->{operations}}) {
		# if we have a return type instruction
		if($operation->{type} eq "return") {
			$function->{pseudotable}{$operation->{src}{value}} = {type => 'register', value=>'eax'};
			$function->{minStack} += 4;
		}

		AddPseudoEntry($operation->{src}{value}, $function) if($operation->{src}{type} and $operation->{src}{type} eq "pseudo");
		AddPseudoEntry($operation->{left}{value}, $function) if($operation->{left}{type} and $operation->{left}{type} eq "pseudo");
		AddPseudoEntry($operation->{right}{value}, $function) if($operation->{right}{type} and $operation->{right}{type} eq "pseudo");
		AddPseudoEntry($operation->{dest}{value}, $function) if($operation->{dest}{type} and $operation->{dest}{type} eq "pseudo");

	}	
	my @tmpInstructions;
	foreach my $operation (@{$cfunction->{operations}}) {
		if($operation->{left}{type} and $operation->{left}{type} eq "pseudo") {
			my $newSrc = $function->{pseudotable}{$operation->{left}{value}};
			$operation->{left}=$newSrc;
		}
		if($operation->{right}{type} and $operation->{right}{type} eq "pseudo") {
			my $newSrc = $function->{pseudotable}{$operation->{right}{value}};
			$operation->{right}=$newSrc;
		}
		if($operation->{src}{type} and $operation->{src}{type} eq "pseudo") {
			my $newSrc = $function->{pseudotable}{$operation->{src}{value}};
			$operation->{src}=$newSrc;
		}
		if($operation->{dest}{type} and $operation->{dest}{type} eq "pseudo") {
			my $newDst = $function->{pseudotable}{$operation->{dest}{value}};
			$operation->{dest}=$newDst;
		}
		my $instructions = $TT{$operation->{type}}($operation);
		push @tmpInstructions, @$instructions;
	}

	#final pass to replace instances of mov <mem>, <mem>
	foreach my $instruction (@tmpInstructions) {
		if($instruction->{name} eq 'movl' and 
			$instruction->{operands}[0]{type} eq 'stack' and
			$instruction->{operands}[1]{type} eq 'stack' 
		) {
			push @{$function->{instructions}}, {name => 'movl', operands => 
				[ $instruction->{operands}[0], {type => 'register', value => 'r10d'} ] };
			push @{$function->{instructions}}, {name => 'movl', operands => 
				[ {type => 'register', value => 'r10d'}, $instruction->{operands}[1] ] };
		}
		elsif($instruction->{name} eq 'movl' and $instruction->{operands}[0]{value} eq $instruction->{operands}[1]{value}) {
			next;
		}
		else {
			push @{$function->{instructions}}, $instruction;
		}
	}
			
			
	#push @{$function->{instructions}}, @$instructions;
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
	my $operation = shift @_;
	my $instructions = [];
	if($operation->{src}{type} eq 'imm') {
		push @$instructions, {name => 'movl', operands => [ $operation->{src}, {type=>'register', value=>'eax'}]};
	}
	my $retInstruction = {name => "ret", operands => []};
	push @$instructions, $retInstruction;
	return $instructions;
}

sub TranslateUnaryOp {
	my $operation = shift @_;
	my $instructions = [];
	my %ops = (negate => 'negl', bitnot => 'notl' );

	push @$instructions, {name => 'movl', operands => 
		[ $operation->{src}, $operation->{dest} ] };	
	
	my $instruction = {name => $ops{$operation->{operation}},  operands => [ $operation->{dest} ]};
	push @$instructions, $instruction;

	
	return $instructions;
}

sub TranslateBinaryOp {
	my $operation = shift @_;
	my $instructions = [];
	my %ops = (
		add         => 'addl', 
		subtract    => 'subl', 
		divide      => 'idivl', 
		modulo      => 'idivl', 
		multiply    => 'imull', 
		bitwise_or  => 'orl', 
		bitwise_and => 'andl', 
		bitwise_xor => 'xorl',
		shift_left  => 'sall',
		shift_right => 'sarl',

	);
	
	my $isDiv = 0;
	if( grep( $operation->{operation} eq $_, (qw(divide modulo)) ) ) {
		$isDiv = 1;
		push @$instructions, {name => 'movl', operands => 
			[$operation->{left}, {type => 'register', value => 'eax'}] };
		push @$instructions, {name => 'cdq', operands => [] }; 
	}
	else {
		push @$instructions, {name => 'movl', operands => 
			[$operation->{left}, {type => 'register', value => 'r11d'}] };
	}
	
	if($isDiv) {
		if($operation->{right}{type} eq 'imm') {
			push @$instructions, {name => 'movl', operands =>
				[ $operation->{right}, {type=>'register', value=>'r10d'} ] };	
			$operation->{right}={type=>'register', value=>'r10d'};
		}	
		push @$instructions, {name => $ops{$operation->{operation}}, operands =>
			[$operation->{right}] };
	}
	elsif($operation->{operation} eq "shift_left" or $operation->{operation} eq "shift_right") {
		push @$instructions, {name => 'movl', operands =>
			[ $operation->{right}, {type=>'register', value=>'ecx'} ] };
		
		push @$instructions, {name => $ops{$operation->{operation}}, operands =>
			[ {type=>'register', value=>'cl'},{type=>'register', value=>'r11d'} ] };
		
		
	} 
	else {
		push @$instructions, {name => $ops{$operation->{operation}}, operands =>
			[$operation->{right}, {type=>'register', value=>'r11d'}] };
	}

	if($operation->{operation} eq 'modulo') {
		push @$instructions, {name => 'movl', operands => 
			[ {type=>'register', value=>'edx'}, $operation->{dest}  ] };	
	} 
	elsif($operation->{operation} eq 'divide') {
		push @$instructions, {name => 'movl', operands => 
			[ {type=>'register', value=>'eax'}, $operation->{dest} ] };	
	}
	else{ 
		push @$instructions, {name => 'movl', operands => 
			[ {type=>'register', value=>'r11d'}, $operation->{dest} ] };	
	}
	return $instructions;
}

sub TranslateInt {
	my $instruction = shift @_;
	my $instructions = [];
	#push @$instructions, {name => 'movl', operands => 
	#	[ $instruction->{src}, $instruction->{dest} ] };
	# do nothing
	return $instructions;
}
	

1
