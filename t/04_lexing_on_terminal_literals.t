use 5.010;
use strict;
use warnings;

use Test::More tests => 4;

use Marpa::R2;

# BNF for decimal numbers (the literals will be used as lexer regexes)
#
#    expr    ::= '-' num | num 
#    num     ::= digits | digits '.' digits 
#    digits  ::= digit | digits digit
#    digit   ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
#

#
# The Grammar
#
my $grammar = Marpa::R2::Grammar->new({   
    start   => 'expr',
    rules   => [
        [ expr => [qw('-' num)] ],
        [ expr => [qw(num)] ],

        [ num => [qw(digits)] ],
        [ num => [qw(digits '.' digits)] ],

        [ digits => [qw(digit)] ],
        [ digits => [qw(digits digit)] ],

        [ digit => [qw('0')] ],
        [ digit => [qw('1')] ], 
        [ digit => [qw('2')] ], 
        [ digit => [qw('3')] ], 
        [ digit => [qw('4')] ], 
        [ digit => [qw('5')] ], 
        [ digit => [qw('6')] ], 
        [ digit => [qw('7')] ], 
        [ digit => [qw('8')] ], 
        [ digit => [qw('9')] ],
    ],
    actions => __PACKAGE__,
    default_action => 'do_what_I_mean',
});

$grammar->precompute();

sub do_what_I_mean { 
    shift;
    my @values = grep { defined } @_;
    scalar @values > 1 ? \@values : shift @values;
}

#
# The Lexer
#
use MarpaX::Parse::Lexer;

my $lexer = MarpaX::Parse::Lexer->new($grammar);

#
# The Dumper
#
use Data::Dumper;

$Data::Dumper::Terse = 1;
$Data::Dumper::Indent = 0;
 
#
# The Test
#
for my $test (
    [  '1234',     qq{[[['1','2'],'3'],'4']} ],
    [ '-1234.423', qq{['-',[[[['1','2'],'3'],'4'],'.',[['4','2'],'3']]]} ],
    [  '-123',     qq{['-',[['1','2'],'3']]} ],
    [  '1234.43',  qq{[[[['1','2'],'3'],'4'],'.',['4','3']]} ],
    ){
    my ($number, $expected) = @$test;
    
    # recognize
    my $recognizer = Marpa::R2::Recognizer->new( { 
        grammar => $grammar, 
    } ) or die 'Failed to create recognizer';
    
    # tokenize
    my $tokens = $lexer->lex($number);
    
    # read
    for my $token (@$tokens){
        defined $recognizer->read( @$token ) or die "Recognition failed";
    }

    # evaluate
    while ( defined( my $value_ref = $recognizer->value() ) ) {
        my $value = $value_ref ? ${$value_ref} : 'No parse';
        is Dumper($value), $expected, "$number lexed on literals and recognized";
    }

}




