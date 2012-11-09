use 5.010;
use strict;
use warnings;

use Test::More;

use Marpa::R2;

use MarpaX::Parse::Tree;

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
        [ expr => [qw(minus num)] ],
        [ expr => [qw(num)] ],

        [ num   => [qw(digits)] ],
        [ num   => [qw(digits point digits)] ],
        
        [ digits => [qw(digit)] ],
        [ digits => [qw(digits digit)] ],

        [ minus => [qw('-')] ],
        [ point => [qw('.')] ],

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
});

$grammar->set( { default_action => 'do_what_I_mean' } );

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
    [  '1234',     qq{[[['1','2'],'3'],'4']}, # AoA
                   qq{tree
`- expr 
   `- num 
      `- digits 
         |- 0 
         |  `- digits 
         |     |- 0 
         |     |  `- digits 
         |     |     |- 0 
         |     |     |  `- digits 
         |     |     |     `- digit = 1 
         |     |     `- 1 
         |     |        `- digit = 2 
         |     `- 1 
         |        `- digit = 3 
         `- 1 
            `- digit = 4 
}, # HoA
                   qq{tree
`- expr 
   `- num 
      `- digits 
         |- digit = 4 
         `- digits 
            |- digit = 3 
            `- digits 
               |- digit = 2 
               `- digits 
                  `- digit = 1 
}, # HoH
                   qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<expr>
  <num>
    <digits>
      <digits>
        <digits>
          <digits>
            <digit>1</digit>
          </digits>
          <digit>2</digit>
        </digits>
        <digit>3</digit>
      </digits>
      <digit>4</digit>
    </digits>
  </num>
</expr>
}, # xml
                   qq{(expr (num (digits (digits (digits (digits (digit 1)) (digit 2)) (digit 3)) (digit 4))))}, # sexpr
                   qq{expr
`- num 
   `- digits 
      |- digits 
      |  |- digits 
      |  |  |- digits 
      |  |  |  `- digit 
      |  |  |     `- 1 
      |  |  `- digit 
      |  |     `- 2 
      |  `- digit 
      |     `- 3 
      `- digit 
         `- 4 
}, # tree
    ],
    [ '-1234.423', qq{['-',[[[['1','2'],'3'],'4'],'.',[['4','2'],'3']]]}, #AoA 
                   qq{tree
`- expr 
   |- 0 
   |  `- minus = - 
   `- 1 
      `- num 
         |- 0 
         |  `- digits 
         |     |- 0 
         |     |  `- digits 
         |     |     |- 0 
         |     |     |  `- digits 
         |     |     |     |- 0 
         |     |     |     |  `- digits 
         |     |     |     |     `- digit = 1 
         |     |     |     `- 1 
         |     |     |        `- digit = 2 
         |     |     `- 1 
         |     |        `- digit = 3 
         |     `- 1 
         |        `- digit = 4 
         |- 1 
         |  `- point = . 
         `- 2 
            `- digits 
               |- 0 
               |  `- digits 
               |     |- 0 
               |     |  `- digits 
               |     |     `- digit = 4 
               |     `- 1 
               |        `- digit = 2 
               `- 1 
                  `- digit = 3 
}, # HoA
                   qq{tree
`- expr 
   |- minus = - 
   `- num 
      |- digits 
      |  |- 0 = . 
      |  |- 1 
      |  |  |- digit = 4 
      |  |  `- digits 
      |  |     |- digit = 3 
      |  |     `- digits 
      |  |        |- digit = 2 
      |  |        `- digits 
      |  |           `- digit = 1 
      |  `- 2 
      |     |- digit = 3 
      |     `- digits 
      |        |- digit = 2 
      |        `- digits 
      |           `- digit = 4 
      `- point = . 
}, # HoH
                   qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<expr>
  <minus>-</minus>
  <num>
    <digits>
      <digits>
        <digits>
          <digits>
            <digit>1</digit>
          </digits>
          <digit>2</digit>
        </digits>
        <digit>3</digit>
      </digits>
      <digit>4</digit>
    </digits>
    <point>.</point>
    <digits>
      <digits>
        <digits>
          <digit>4</digit>
        </digits>
        <digit>2</digit>
      </digits>
      <digit>3</digit>
    </digits>
  </num>
</expr>
}, # xml
                   qq{(expr (minus -) (num (digits (digits (digits (digits (digit 1)) (digit 2)) (digit 3)) (digit 4)) (point .) (digits (digits (digits (digit 4)) (digit 2)) (digit 3))))}, # sexpr
                   qq{expr
|- minus 
|  `- - 
`- num 
   |- digits 
   |  |- digits 
   |  |  |- digits 
   |  |  |  |- digits 
   |  |  |  |  `- digit 
   |  |  |  |     `- 1 
   |  |  |  `- digit 
   |  |  |     `- 2 
   |  |  `- digit 
   |  |     `- 3 
   |  `- digit 
   |     `- 4 
   |- point 
   |  `- . 
   `- digits 
      |- digits 
      |  |- digits 
      |  |  `- digit 
      |  |     `- 4 
      |  `- digit 
      |     `- 2 
      `- digit 
         `- 3 
}, # tree
    ],
    [  '-123',     qq{['-',[['1','2'],'3']]}, 
                   qq{tree
`- expr 
   |- 0 
   |  `- minus = - 
   `- 1 
      `- num 
         `- digits 
            |- 0 
            |  `- digits 
            |     |- 0 
            |     |  `- digits 
            |     |     `- digit = 1 
            |     `- 1 
            |        `- digit = 2 
            `- 1 
               `- digit = 3 
}, # HoA
                   qq{tree
`- expr 
   |- minus = - 
   `- num 
      `- digits 
         |- digit = 3 
         `- digits 
            |- digit = 2 
            `- digits 
               `- digit = 1 
}, # HoH
                   qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<expr>
  <minus>-</minus>
  <num>
    <digits>
      <digits>
        <digits>
          <digit>1</digit>
        </digits>
        <digit>2</digit>
      </digits>
      <digit>3</digit>
    </digits>
  </num>
</expr>
}, # xml
                   qq{(expr (minus -) (num (digits (digits (digits (digit 1)) (digit 2)) (digit 3))))}, # sexpr
                   qq{expr
|- minus 
|  `- - 
`- num 
   `- digits 
      |- digits 
      |  |- digits 
      |  |  `- digit 
      |  |     `- 1 
      |  `- digit 
      |     `- 2 
      `- digit 
         `- 3 
}, # tree
    ],
    [  '1234.43',  qq{[[[['1','2'],'3'],'4'],'.',['4','3']]}, 
                   qq{tree
`- expr 
   `- num 
      |- 0 
      |  `- digits 
      |     |- 0 
      |     |  `- digits 
      |     |     |- 0 
      |     |     |  `- digits 
      |     |     |     |- 0 
      |     |     |     |  `- digits 
      |     |     |     |     `- digit = 1 
      |     |     |     `- 1 
      |     |     |        `- digit = 2 
      |     |     `- 1 
      |     |        `- digit = 3 
      |     `- 1 
      |        `- digit = 4 
      |- 1 
      |  `- point = . 
      `- 2 
         `- digits 
            |- 0 
            |  `- digits 
            |     `- digit = 4 
            `- 1 
               `- digit = 3 
}, # HoA
                   qq{tree
`- expr 
   `- num 
      |- digits 
      |  |- 0 = . 
      |  |- 1 
      |  |  |- digit = 4 
      |  |  `- digits 
      |  |     |- digit = 3 
      |  |     `- digits 
      |  |        |- digit = 2 
      |  |        `- digits 
      |  |           `- digit = 1 
      |  `- 2 
      |     |- digit = 3 
      |     `- digits 
      |        `- digit = 4 
      `- point = . 
}, # HoH
                   qq{<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<expr>
  <num>
    <digits>
      <digits>
        <digits>
          <digits>
            <digit>1</digit>
          </digits>
          <digit>2</digit>
        </digits>
        <digit>3</digit>
      </digits>
      <digit>4</digit>
    </digits>
    <point>.</point>
    <digits>
      <digits>
        <digit>4</digit>
      </digits>
      <digit>3</digit>
    </digits>
  </num>
</expr>
}, # xml
                   qq{(expr (num (digits (digits (digits (digits (digit 1)) (digit 2)) (digit 3)) (digit 4)) (point .) (digits (digits (digit 4)) (digit 3))))}, # sexpr
                   qq{expr
`- num 
   |- digits 
   |  |- digits 
   |  |  |- digits 
   |  |  |  |- digits 
   |  |  |  |  `- digit 
   |  |  |  |     `- 1 
   |  |  |  `- digit 
   |  |  |     `- 2 
   |  |  `- digit 
   |  |     `- 3 
   |  `- digit 
   |     `- 4 
   |- point 
   |  `- . 
   `- digits 
      |- digits 
      |  `- digit 
      |     `- 4 
      `- digit 
         `- 3 
}, # tree
    ],
    ){
    my ($number, @expected) = @$test;
    
    # tokenize
    my $tokens = $lexer->lex($number);
    
    # these are the default actions recognized by MarpaX::Parse::Tree
    # they need to be set as default_action argument of a Marpa::R2::Grammar
    # and Marpa::R2::Recognizer will evaluate the parse to the required tree type
    my @trees = qw{ AoA HoA HoH xml sexpr tree }; 
    for my $i (0..@trees-1){

        my $tree     = $trees[$i];
        my $expected = $expected[$i];

        # set default_action of the grammar
        $grammar->set({ default_action => 'MarpaX::Parse::Tree' . '::' . $tree });
        
        # setup the recognizer
        my $recognizer = Marpa::R2::Recognizer->new( { 
            grammar => $grammar, 
        } ) or die 'Failed to create recognizer';
    
        # read
        for my $token (@$tokens){
            defined $recognizer->read( @$token ) or die "Recognition failed";
        }

        # evaluate
        my $value;
        while ( defined( my $value_ref = $recognizer->value() ) ) {
            $value = $value_ref ? ${$value_ref} : 'No parse';
        }

        # set up the tree
        my $t = MarpaX::Parse::Tree->new({
            grammar => $grammar,
            type    => $tree,
        });

        # use MarpaX::Parse::Tree views to stringify trees
        # xml parse trees need a decl
        # until Marpa::R2::Grammar has no accessor for start
        if ($tree eq "xml"){
            $value = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' . $value;
        }

        # get the parse tree as text
        my $got = $tree eq "AoA" ? Dumper($value): $t->show_parse_tree($value);
        # test
        unless (is $got, $expected, "$number recognized as $tree parse tree"){
            say $got;                
        }
    }

}

done_testing;
