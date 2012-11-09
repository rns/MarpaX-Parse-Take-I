package MarpaX::Parse::Parser;

use 5.010;
use strict;
use warnings;

use YAML;

use Encode qw{ encode };

use MarpaX::Parse::Lexer;
use MarpaX::Parse::Tree;

sub new{

    my $class = shift;
    my $options = shift;
    
    my $self = {};

    say "# parser:\n", Dump $options;
    
    # extract the grammar and the default action for it
    $self->{g}  = $options->{grammar} or die 'grammar required';
    $self->{da} = $options->{default_action};
    delete $options->{default_action};
    
    # default_action by, well, default
    $self->{da} //= 'MarpaX::Parse::Tree::AoA';

#    say "# parser:\n", $options->{da};
    
    # extract other options of this module
    # TODO: die on improper option values
    for my $o (qw{
        ambiguity 
        recognition_failure_sub 
        show_recognition_failures
        }){
        if (exists $options->{$o}){
            $self->{$o} = $options->{$o};
            delete $options->{$o};
        }
    }

    # set default for this module options
    $self->{ambiguity}                  //= 'input_model';
    $self->{recognition_failure_sub}    //= \&recognition_failure;
    $self->{show_recognition_failures}  //= 0;
    
    # other options must be those of the recognizer
    $self->{ro} = $options;
    
    bless $self, $class;
}

# recognition failures are not necessarily fatal so by default, 
# this sub will be called to get the most out of the recognizer and set that 
# as recognition failure item under recognition_failures option
# that can be further retrieved by show_recognition_failures
# this default sub is here for demonstration only and cannot be considered as
# any guide.
sub recognition_failure {
    
    my $self = shift;
    
    my $recognizer  = shift;
    my $token_ix    = shift;
    my $tokens      = shift;
    
    my $token = $tokens->[$token_ix];
    
    push @{ $self->{recognition_failures} }, { 
        token               => join(': ', @$token),
        events              => [ $recognizer->events ],
        exhausted           => $recognizer->exhausted,
        latest_earley_set   => $recognizer->latest_earley_set,
        # TODO: stringify progress by converting IDs into rules/symbols
        progress            => [ $recognizer->progress ],
        terminals_expected  => [ $recognizer->terminals_expected ],
    };
    
    # fix things (that includes do nothing) and return true to continue parsing
    # undef will lead to die()
    return "true";
}

sub parse{

    my $self = shift;
    my $input = shift;
    # TODO (NLP): get %$features, split $input, set up $tokens
    
    # init recognition failures
    $self->{recognition_failures} = [];
    
    # input can be name/value pair arrayref or a string
    # name/value pair arrayrefs are used as is
    my $tokens;
    if (ref $input eq "ARRAY"){
        $tokens = $input;
        # TODO: grammar data can be shown here for tracing
        # find ambiguous tokens and disambiguate them by adding rules to the grammar
        if ($self->{ambiguity} eq 'tokens'){
            # rules for the ambiguous token must be unique
            my $ambiguous_token_rules = {};
            my $rules_name = ref $self->{options}->{rules};
            # enumerate tokens
            for my $i (0..@$tokens-1){
                my $token = $tokens->[$i];
                # if $token is ambiguous, generate and add rules for it before recognizing
                if (ref $token->[0] eq "ARRAY" ){
                    my $ambiguous_token = $token;
#                    _dump "ambiguous token", $ambiguous_token;
                    # get $ambiguous_token names as an array and a string
                    my @names = map { $_->[0] } @$ambiguous_token; 
                    my $names = join('/', @names);
                    # get $ambiguous_token value 
                    my $value = $ambiguous_token->[0]->[1];
                    # disambiguate $ambiguous_token (well, sort of)
                    my $disambiguated_token = [ $names, $value ];
                    # replace ambiguous token with disambiguated
                    $tokens->[$i] = $disambiguated_token;
                    # generate *unique* rules for the $ambiguous_token
                    $ambiguous_token_rules->{$_}->{$names} = undef for @names;
                }
            }
            # add %$ambiguous_token_rules as generated
            if ($rules_name eq "ARRAY"){
                # lhs => [qw{rhs}]
                my @rules = map { [ $_ => [ $ambiguous_token_rules->{$_} ] ] } keys %$ambiguous_token_rules;
                $self->merge_token_rules(\@rules);
            }
            else{
                # make a BNF grammar of @ambiguous_token_rules
                my $bnf = "\n# rules added from ambiguous tokens\n";
                # lhs ::= rhs
                for my $lhs (keys %$ambiguous_token_rules){
                    my @rhs = keys %{ $ambiguous_token_rules->{$lhs} };
                    $bnf .= join "\n", map { $lhs . '::=' . $_ } @rhs;
                    $bnf .= "\n";
                }
                $bnf .= "\n";
                # add $bnf to $self->{options}->{$rules} and rebuild the grammar
                $self->merge_token_rules($bnf);
            }
        } ## ($self->{ambiguity} eq 'tokens'
    } ## if (ref $input eq "ARRAY"){
    # strings are split
    else{
        my $l = MarpaX::Parse::Lexer->new($self->{g});
        $tokens = $l->lex($input);
    }
    
    # TODO: option is needed to show tokens here
    
    # set recognizer options we received and got
    my $recce_opts = $self->{ro};

    # get closures for the recognizer from the grammar if we can
    my $grammar  = $self->{g};
    # including descendants: (E)BNF 
    if (ref $grammar =~ /^MarpaX::Parse::Grammar/){
        say "setting closures";
        $recce_opts->{closures} = $self->{g}->{closures}; 
    }
    
    # set default_action for the grammar if we can
    if ($self->{da} and ref $grammar eq "Marpa::R2::Grammar"){
        $grammar->set( { default_action => $self->{da} } );
    }

    # set grammar
    $recce_opts->{grammar}  = $grammar;
    
    # setup recognizer
    my $recognizer = Marpa::R2::Recognizer->new( $recce_opts ) 
       or die 'Failed to create recognizer';

    # read tokens
    for my $i (0..@$tokens-1){
        my $token = $tokens->[$i];
#say Dump "read()ing", $token;
        if (ref $token->[0] eq "ARRAY"){ # ambiguous token
            # use alternate/end_input
            for my $alternative (@$token) {
                my ($name, $value) = @$alternative;
                $recognizer->alternative( $name, \$value, 1 )
            }
            $recognizer->earleme_complete();
        }
        else{ # unambiguous token
               defined $recognizer->read( @$token ) 
            or $self->{recognition_failure_sub}->($self, $recognizer, $i, $tokens) 
            or die "Parse failed";
        }
#        say "# progress:", $recognizer->show_progress;
    }
    
    # TODO: this needs to be $self->{o}->show
#    $self->{g}->show_option('recognition_failures');
    
    # TODO: 'parse' needs to be split to 'recognize' and 'evaluate'
    # get values    
    my @values;
    my %values; # only unique parses will be returned
    while ( defined( my $value_ref = $recognizer->value() ) ) {
        my $value = $value_ref ? ${$value_ref} : 'No parse';
        # use dumper based on default_action
        my $value_dump = ref $value ? 
            $self->{da} eq 'MarpaX::Parse::Tree::tree' ?
                MarpaX::Parse::Tree->show_parse_tree($value, 'text') 
                :
                Dump $value
            :
            $value;
        # TODO: $ebnf_parser produces very ambiguous grammars
        next if exists $values{$value_dump};
        # save unique parses for return
        # prepend xml prolog and encode to utf8 if we need to return an XML string
        if ($self->{da} eq 'MarpaX::Parse::Tree::xml'){
            $value = '<?xml version="1.0"?>' . "\n" . $value;
            # enforce strict encoding (UTF-8 rather than utf8)
            $value = encode("UTF-8", $value);
        }
        push @values, $value;
        # save parse to test for uniqueness
        $values{$value_dump} = undef;
    }
    
    # set up the return value and parse tree/forest reference    
    if (wantarray){         # mupltiple parses are expected
        $self->{tree_package}->{parse_forest} = \@values;
        return @values;
    }
    elsif (@values > 1){    # single parse is expected, but we have many, 
        $self->{tree_package}->{parse_forest} = \@values;
        return \@values;    # hence the array ref
    }
    else {
        $self->{tree_package}->{parse_tree} = $values[0];
        return $values[0];  # single parse is expected and we have just it
                            # hence the scalar
    }
    
}

=pod
#
# TODO: compatibility-only, both to be deleted
#
sub show_parse_tree{
    my $self = shift;
    $self->{tree_package}->show_parse_tree(@_);
}

sub show_parse_forest{
    my $self = shift;
    $self->{tree_package}->show_parse_forest(@_);
}
=cut

1;

__END__
