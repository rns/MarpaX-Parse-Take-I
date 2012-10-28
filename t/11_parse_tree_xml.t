use 5.010;
use strict;
use warnings;

use YAML;
use Test::More tests => 4;

use Marpa::Easy;

# set up grammar
my $grammar = q{

    # decimal number, possibly signed and fractional
    # text literal nodes are hard to process in XML, hence minus and point rules
    expr    ::= minus num | num
    num     ::= digits | digits point digits
    digits  ::= digit | digit digits
    digit   ::= '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9'
    minus   ::= '-' 
    point   ::= '.' 

};

my $bnf = Marpa::Easy->new({
    rules => $grammar,
    default_action => 'xml',
});

# input
my $numbers = [
    '1234',
    '-1234.423',
    '-1234',
    '1234.423',
];

use XML::Twig;

for my $number (@$numbers){
    my $xml = $bnf->parse($number);

    my @digits;

    # parse XML parse tree
    my $t = XML::Twig->new( 
        twig_handlers => {
            _all_ => sub { 
                if ($_->tag ~~ [ qw{ digit minus point } ]){
                    push @digits, $_->text
                }
            }
        },
    );
    $t->parse($xml);

    is join('', @digits), $number, "numeral $number parsed with pure BNF to an XML string";
}
