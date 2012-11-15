use 5.010;
use strict;
use warnings;

use YAML;

use Test::More;

use_ok 'MarpaX::Parse';
use_ok 'MarpaX::Parse::Tree';

# grammar
# these rules will be added first
my $non_terminals = q{

    expr    ::= num | minus num

    num     ::= digits | digits point digits
    digits  ::= digit | digit digits

};

# these rules will be added second
my $terminals = q{
    digit   ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
    point   ::= '.'
    minus   ::= '-' 
};

# input
my $number = '-1234.423'; 

# set up the grammar
my $mt = MarpaX::Parse->new({
    rules => $non_terminals,
    default_action => 'MarpaX::Parse::Tree::sexpr',
});

eval { $mt->parse($number) }; 
like $@, qr/\Qalternative(): symbol "::any" does not exist\E/, "$number cannot be parsed without terminals";

# add terminals
$mt->grammar->merge_token_rules($terminals);

is $mt->parse($number), '(expr (minus -) (num (digits (digit 1) (digits (digit 2) (digits (digit 3) (digits (digit 4))))) (point .) (digits (digit 4) (digits (digit 2) (digits (digit 3))))))', "$number can be parsed with terminals added";

done_testing;
