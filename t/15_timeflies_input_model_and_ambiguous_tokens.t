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

my $mp = Marpa::Easy->new({
    rules => $grammar,
    default_action => 'sexpr', # s-expression, that's right
});

isa_ok $mp, 'Marpa::Easy';

# these part-of-speech (pos) data will be added to those provided by WordNet
my $lex = {
    a   => [ 'ia' ],        # indefinite articles
    an  => [ 'ia' ],
    but => [ 'conj' ],      # but is a coordinating conjunction in addition to
                            # WordNet's adverb
    time  => [ 'a' ],       # nouns can be adjectives as they can modify other nouns 
    fruit => [ 'a' ],       # which WordNet seems to be sadly knowing nothing about
                            
};

SKIP: {

eval { require WordNet::QueryData };
skip "WordNet::QueryData not installed", 1 if $@;

sub tokenize {

    my $text   = shift;

    my @lexems = grep { $_ } map { s/^\s+//; s/\s+$//; $_ } split /(\w+)/, $text;
    
    my $tokens = [];
    
    my $wn     = WordNet::QueryData->new( noload => 1 );
    
    # set up [ pos, word ] tokens
    for my $lexem (@lexems){
        
        # pull part-of-speech data from WordNet 
        my @pos = keys { map { $_->[1] => undef } map { [ split /#/ ] } $wn->validForms( $lexem ) };
        
        # pull more part-of-speech data from $lex, if any
        push @pos, @{ $lex->{$lexem} || [] };

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

# we know we want multiple parses
my @parses = $mp->parse( tokenize($sentence) );

my $expected = q{(Sentence (Clause (Subject (noun (bare_noun time))) (Verb flies) (Object (adjective like) (noun (article an) (bare_noun arrow)))) (comma ,) (conjunction but) (Clause (Subject (noun (bare_noun fruit))) (Verb flies) (Object (adjective like) (noun (article a) (bare_noun banana)))))
(Sentence (Clause (Subject (adjective time) (noun (bare_noun flies))) (Verb like) (Object (noun (article an) (bare_noun arrow)))) (comma ,) (conjunction but) (Clause (Subject (noun (bare_noun fruit))) (Verb flies) (Object (adjective like) (noun (article a) (bare_noun banana)))))
(Sentence (Clause (Subject (noun (bare_noun time))) (Verb flies) (Object (adjective like) (noun (article an) (bare_noun arrow)))) (comma ,) (conjunction but) (Clause (Subject (adjective fruit) (noun (bare_noun flies))) (Verb like) (Object (noun (article a) (bare_noun banana)))))
(Sentence (Clause (Subject (adjective time) (noun (bare_noun flies))) (Verb like) (Object (noun (article an) (bare_noun arrow)))) (comma ,) (conjunction but) (Clause (Subject (adjective fruit) (noun (bare_noun flies))) (Verb like) (Object (noun (article a) (bare_noun banana)))))};

is join("\n", map { $mp->show_parse_tree($_) } @parses), $expected, "'$sentence' parsed";

} ## SKIP

done_testing;
