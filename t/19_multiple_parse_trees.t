use 5.010;
use strict;
use warnings;

use YAML;

use Test::More;

use Test::Differences;

use_ok 'MarpaX::Parse';
use_ok 'MarpaX::Parse::Tree';

# grammar
my $calc = q{
    
    Expression  ::= Term | Term Op Term
    
    Term        ::= Factor+
    
    Factor      ::= Identifier | Number | '(' Expression ')'
    
    Identifier  ::= 'qr/\w+/'
    
    Number      ::= 'qr/\d+/'
    
    Op          ::= '+' | '-' | '*' | '/'
    
};

my $tree_type = 'sexpr';

# set up the grammar
my $mp = MarpaX::Parse->new({
    rules => $calc,
    default_action => "MarpaX::Parse::Tree::$tree_type",
});

my @trees = $mp->parse('1 + 1');

eq_or_diff_text MarpaX::Parse::Tree->new({ type => $tree_type })->show_parse_forest(\@trees) . "\n", <<EOT, "multiple parse trees shown";
# Parse Tree 1:
(Expression (Term (Factor+ (Factor (Identifier 1)))) (Op +) (Term (Factor+ (Factor (Identifier 1)))))
# Parse Tree 2:
(Expression (Term (Factor+ (Factor (Number 1)))) (Op +) (Term (Factor+ (Factor (Identifier 1)))))
# Parse Tree 3:
(Expression (Term (Factor+ (Factor (Identifier 1)))) (Op +) (Term (Factor+ (Factor (Number 1)))))
# Parse Tree 4:
(Expression (Term (Factor+ (Factor (Number 1)))) (Op +) (Term (Factor+ (Factor (Number 1)))))
EOT

done_testing;
