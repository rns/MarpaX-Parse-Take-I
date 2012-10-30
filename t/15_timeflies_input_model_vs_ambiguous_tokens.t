use 5.010;
use strict;
use warnings;

use Test::More;

use YAML;

use_ok 'Marpa::Easy';

my $grammar = q{
    
    Sentence ::= 
          Clause
        | Clause comma conjunction Clause
    
    Clause  ::= Subject Verb Object Manner? # Place Time
                                            # but we have no sentence for them (yet)
    
    Subject ::= adjective? noun
    Object  ::= adjective? noun
    Manner  ::= adverb                      # adverb/adjunct of manner
    
    noun        ::= article? bare_noun
    bare_noun   ::= n
    article     ::= ia
    adjective   ::= a
    adverb      ::= r
    Verb        ::= v
    conjunction ::= conj
    comma       ::= ,

};

# part-of-speech (pos) data 
# if WordNet::QueryData is installed, we will pull them from it
my $pos = {

    a       => [qw{ ia n    }],     # indefinite articles
    an      => [qw{ ia n    }],

    arrow   => [qw{ n       }],
    banana  => [qw{ n       }],
    but     => [qw{ conj r  }],     # but is a coordinating conjunction
                                    # r stands for an adverb in WordNet
    flies   => [qw{ n v     }],
    fruit   => [qw{ a n v   }],     # nouns can be adjectives as they can modify other nouns 
    time    => [qw{ a n v   }],  

    like    => [qw{ a n v   }],     

};

# check if we have something to pull pos from
eval { require WordNet::QueryData };
my $WordNet_QueryData_installed = not $@;

# split sentence into [ part_of_speech, word ] tokens
sub tokenize {

    my $text   = shift;

    my @lexems = grep { $_ } map { s/^\s+//; s/\s+$//; $_ } split /(\w+)/, $text;
    
    my $tokens = [];
    
    my $wn     = $WordNet_QueryData_installed ? WordNet::QueryData->new( noload => 1 ) : undef;
    
    # set up [ pos, word ] tokens
    for my $lexem (@lexems){

        # pull lexem's part(s) of speech from WordNet if we have it installed
        # set empty otherwise
        my %pos = ref $wn eq 'WordNet::QueryData' ? 
                  map { $_->[1] => undef } 
                  map { [ split /#/ ] } $wn->validForms( $lexem ) : 
                  ();
                  
        
        # add only missing part-of-speech data from $pos
        map { $pos{$_} = undef } @{ $pos->{$lexem} || [] };
        
        # set up part of speech data as an array
        my @pos = keys %pos;
        
        # ambiguous token
        if (@pos > 1){      
            push @$tokens, [ map { [ $_, $lexem ] } @pos ] ;
        }
        # unambiguous token
        elsif (@pos){       
            push @$tokens, [ $pos[0], $lexem ];
        }
        # unknown token, treat as a bare literal
        else {
            push @$tokens, [ $lexem, $lexem ];
        }
    }
    
    $tokens;
}

my $sentence = 'time flies like an arrow, but fruit flies like a banana';

my $expected = q{(Sentence (Clause (Subject (noun (bare_noun time))) (Verb flies) (Object (adjective like) (noun (article an) (bare_noun arrow)))) (comma ,) (conjunction but) (Clause (Subject (noun (bare_noun fruit))) (Verb flies) (Object (adjective like) (noun (article a) (bare_noun banana)))))
(Sentence (Clause (Subject (adjective time) (noun (bare_noun flies))) (Verb like) (Object (noun (article an) (bare_noun arrow)))) (comma ,) (conjunction but) (Clause (Subject (noun (bare_noun fruit))) (Verb flies) (Object (adjective like) (noun (article a) (bare_noun banana)))))
(Sentence (Clause (Subject (noun (bare_noun time))) (Verb flies) (Object (adjective like) (noun (article an) (bare_noun arrow)))) (comma ,) (conjunction but) (Clause (Subject (adjective fruit) (noun (bare_noun flies))) (Verb like) (Object (noun (article a) (bare_noun banana)))))
(Sentence (Clause (Subject (adjective time) (noun (bare_noun flies))) (Verb like) (Object (noun (article an) (bare_noun arrow)))) (comma ,) (conjunction but) (Clause (Subject (adjective fruit) (noun (bare_noun flies))) (Verb like) (Object (noun (article a) (bare_noun banana)))))};

# set up the grammar
my $mp = Marpa::Easy->new({
    rules => $grammar,
    default_action => 'sexpr', # s-expression, that's right
# ===============================================================
# handle ambiguity with Marpa::R2 input model that is the default, 
# so the below line is here for information only
    ambiguity => 'input_model',
});

isa_ok $mp, 'Marpa::Easy';

# we know we want multiple parses
my @parses = $mp->parse( tokenize($sentence) );

is join("\n", map { $mp->show_parse_tree($_) } @parses), $expected, "ambiguous '$sentence' parsed using input model (alternate()/earleme_complete())";

# ==========================================
# now handle ambiguity with ambiguous tokens
$mp->set_option(ambiguity => 'tokens');

@parses = $mp->parse( tokenize($sentence) );
is join("\n", map { $mp->show_parse_tree($_) } @parses), $expected, "ambiguous '$sentence' parsed using ambiguous tokens";

done_testing;
