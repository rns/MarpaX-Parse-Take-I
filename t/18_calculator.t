use 5.010;
use strict;
use warnings;

=pod algebraic identtities (patterns)

a + b = b + a
a * b = b * a

a + 0 = a

a * 1 = a

a + (–a) = 0

a * 1/a  = 1

a + (b + c) = (a + b) + c

(a * b) * c = a * (b * c)

a * (b + c) = a * b + a * c, 

(a + b) * c = a * c + b * c

(a^x)^y = a^(x*y)

a^x * a^y = a^(x+y)

a/b + c/d = (a*d + b*c) / (b*d)

(a + b)^2 = a^2 + 2*a*b + b^2

(a + b) * (c + d) = a*c + a*d + b*c + b*d 

=cut

use YAML;

use Test::More;

use MarpaX::Parse;

# grammar
my $calc = q{

    expr   ::= '+' term              
             | '-' term              
             | term                  
             | expr '+' term          
             | expr '-' term          
             | expr '=' expr
             | expr '^' expr

    term   ::= fact                
             | term '*' fact
             | term '/' fact

    fact   ::= num
             | var
             | '(' expr ')'
             | func '(' expr ')'
    
    func    ::= 'sin' | 'cos' | 'sqrt' 
    
    num     ::= 'qr/\d+(\.\d+)?/'

    var     ::= 'qr/(?!sin|cos|sqrt)[a-zA-Z]+/'

};

#say $mp->show_rules;

for my $expr (
    '1 + 2 ^ 3',
    '2 - 11 + 2 + 1',
    'a/b + (b/c)',
    '(a + b)^2 + (b/c)',
    'a^2 + 2*a*b + b^2',
    '((1 + 2) * 3 / (- a) - (+ b)) * (c + d + e * 4) ',
    'sin(x^2)^2 + cos(x^2) = 1',
    '2*x + 3*(sin(y) + 4 * z)',
    '(x+y)^z)'
    ){
    say "\n# $expr";
    # set up the grammar
    my $mp = MarpaX::Parse->new({
        rules => $calc,
        default_action => 'tree',
#        show_tokens => 1,
#        show_lexer_rules => 1,
    });

    my $trees = $mp->parse($expr);
#    say ref $trees;
    say $mp->show_parse_tree;
}


done_testing;
