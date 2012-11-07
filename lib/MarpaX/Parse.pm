package MarpaX::Parse;

use 5.010;
use strict;
use warnings;

use Carp qw{cluck};

use YAML;

use Marpa::R2;

use MarpaX::Parse::Grammar;
use MarpaX::Parse::Lexer;

use MarpaX::Parse::BNF;
use MarpaX::Parse::EBNF;

use MarpaX::Parse::Tree;

use Encode qw{ encode is_utf8 };

use XML::Twig;

use Clone qw(clone);

=pod distro module layout

# 
use MarpaX::Parse;

my $p = MarpaX::Parse->new( {  
    rules => q{} 
    ...
} ) or die "can't create parser";

my $output = $p->parse( $input );

#

my $out = MarpaX::Parse->new( {  rules => q{} } )->parse( $in );

MarpaX::Parse
    
    grammar
    
    sub new{
        ref $rules eq 
            "ARRAY" # Marpa::R2::Grammar
            "HASH"
            "" = textual grammar: 
            first try to parse it with BNF; if this fails, then with EBNF 
            to have $rules which will be fed to MarpaX::Parse::Grammar       

    sub grammar {

    sub recognition_failure {
    sub parse{
    sub show_parse_forest{
    sub show_parse_tree{

MarpaX::Parse::Grammar
    
    grammar = Marpa::R2::Grammar
    
    sub _build {
    
    sub _extract_start_symbol
    sub _set_default_action
    sub _closures_to_actions
    sub _quantifiers_to_rules   # if there are quantifiers, e.g. symbol+
    sub _rule_signature
    sub _action_name

    sub _extract_terminals
    sub _extract_symbols

    sub merge_token_rules {     # add rules to the grammar and re-build()


    MarpaX::Parse::Grammar::BNF->can(build)
    MarpaX::Parse::Grammar::EBNF->can(build)

MarpaX::Parse::Lexer 
    # supposed to be called from MarpaX::Parse::parse()
    # when it has scalar $input
    
    new (MarpaX::Parse::Grammar)
    
    sub _extract_lexer_rules
    sub lex

MarpaX::Parse::Tree
    
    # subs in this package will be used to build parse trees
    # for MarpaX::Parse::Grammar
    
    sub AoA { 
    sub HoA { 
    sub HoH { 
    sub AoA_with_rule_signatures { 
    sub sexpr { 
    sub tree { 
    sub filter
    sub xml {
    
    sub show
    sub traverse
    sub transform
    
MarpaX::Parse::NLP
    
    5W+H+Vs
    
    lex input as for NM
    tokenize ($input, $features_provider)
        augment grammar
    parse
    
    MarpaX::Parse::NLP::Grammar
        MarpaX::Parse::RU::Grammar
        MarpaX::Parse::EN::Grammar
#
MarpaX::Parse::Util -- Debug::Msg
    
    sub _dump {

MarpaX::Parse::Options
    
    new (MarpaX::Parse)
    
    sub _token_string {
    sub set_option{
    sub get_option{
    sub comment_option {
    sub show_option{
    sub show_parsed_bnf_rules      
    sub show_transformed_bnf_rules 
    sub show_closures              
    sub show_bnf_tokens            
    sub show_bnf_rules             
    sub show_bnf_closures          
    sub show_tokens                
    sub show_rules                 
    sub show_symbols               
    sub show_terminals             
    sub show_lexer_rules           
    sub show_literals              
    sub show_lexer_regexes         
    sub show_recognition_failures  

    sub _bnf_to_rules
    sub _ebnf_to_rules

=cut

=head1 DESCRIPTION

=cut

#
# Any BNF grammar passed to MarpaX::Parse by setting <rules> to scalar 
# is parsed by the BNF parser with rules set in MarpaX::Parse::BNF
#
# BNF parser tokens, rules and closures are shown by show_bnf_parser_* options
# 
# tokens, rules and closures of the BNF grammar passed to MarpaX::Parse are shown
# by show_bnf_* options
# 
# Finally, tokens, rules and closures of the input parsed by the BNF grammar passed 
# to MarpaX::Parse are shown # by show_* options
#

my $MarpaX_Parse_options = {

    # stage: BNF grammar parser initialization
    show_bnf_parser_tokens => undef,
    show_bnf_parser_rules => undef,    
    show_bnf_parser_closures => undef, 
    show_parsed_bnf_rules => undef,    
    
    # stage: parsing the BNF grammar text set as <rules> option
    show_bnf_tokens => undef,
    show_bnf_rules => undef,    
    show_bnf_closures => undef, 
    
    # stage: pre-lexing
    # extracting lexer rules from the grammar rules (terminal literals)
    show_literals => undef,
    show_lexer_rules => undef,
    # setting up lexer regexes based on lexer rules 
    show_lexer_regexes => undef,

    # stage: lexing input for parsing (BNF parser and input)
    show_input => undef,
    show_tokens => undef,
    
    # stage: transforming BNF or Marpa::R2 rules passed in 'rules' option 
    # and setting up the grammar based on them
    show_rules => undef,
    show_closures => undef,
    
    # stage: parsing input with BNF or Marpa::R2 rules passed in 'rules' option
    show_symbols => undef,
    show_terminals => undef,
    
    # stage: recognition by Marpa::R2 
    show_recognition_failures => undef,
    recognition_failure_sub => undef,

    # handle ambuous tokens with input model (alternate()/earleme_complete()
    ambiguity => undef,
    
    # transform quantified symbols into sequence (by default) or recursive rules
    quantifier_rules => undef,

    # if true, nullable symbols will be added instead removing the rules 
    # with ?/*-quanfitied symbols
    nullables_for_quantifiers => undef,

    ebnf => undef,
};

sub new{

    my $class = shift;
    my $options = shift;
    
    my $self = {};
    bless $self, $class;
    
    $self->build($options);
    
    return $self;
}

#
# extract Marpa::R2::(Grammar|Recornizer) options 
# parse (E)BNF if needed
# transform rules
# set and precomute() grammar
#
sub build {
    
    my $self = shift;
    
    my $options = shift;
    
    # set up and save the grammar
    my $g = MarpaX::Parse::Grammar->new(clone $options);
    $self->{g} = $g;
    
    # clone options to enable adding rules to grammar
    $self->{options} = clone $options;
    
    # extract MarpaX::Parse options and set defaults
    while (my ($option, $value) = each %$options){
        if (exists $MarpaX_Parse_options->{$option}){
            $self->{$option} = $value;
            delete $options->{$option};
        }
    }
    
    # set defaults
    $self->{quantifier_rules}               //= 'sequence';
    $self->{ambiguity}                      //= 'input_model';
    $self->{recognition_failure_sub}        //= \&recognition_failure;
    
    # TODO: extract recognizer options
    my @recognizer_options = qw{
        closures
        end
        event_if_expected
        max_parses
        ranking_method
        too_many_earley_items
        trace_actions
        trace_file_handle
        trace_terminals
        trace_values
        warnings
    };
    
    # transform rules
    my @rules;

    # indicate that BNF grammar scalar rather than rules aref was passed
    my $bnf = 0;

    # array ref means we have rules
    if (ref $options->{rules} eq "ARRAY"){  
        @rules = @{ $options->{rules} };
    }
    # scalar means we have a BNF grammar we need to parse to get rules
    else {
        $bnf = 1;
        my $rules;
        # ebnf (contains grouping (non-literal) parens)
        if ($self->{ebnf}){ 
            $rules = $self->_ebnf_to_rules( $options->{rules} );
        }
        # bnf
        else{ 
            $rules = $self->_bnf_to_rules( $options->{rules} );
        }
        # TODO: catch BNF parsing errors, e.g. := not ::=
        @rules = @$rules;
        $self->set_option('parsed_bnf_rules', \@rules);
    }

    # quantifiers to rules
    $g->_quantifiers_to_rules( \@rules );

    # extract closures and generate actions for Recognizer
    my $closures = $g->_closures_to_actions( \@rules );
    $self->{closures} = $closures;

    # handle default action
    $g->_set_default_action($options);    

    # TODO: parse() needs this; to be removed
    $self->{default_action} = $options->{default_action};
    
    # set start to lhs of the first rule if not set
    if (not exists $options->{start}){
        $options->{start} = $g->_extract_start_symbol( \@rules );
    }

    # save transformed rules for further adding to them 
    $self->set_option('transformed_rules', \@rules);
    
    # set transformed rules as Marpa grammar option
    $options->{rules} = \@rules;
    
    # set up the grammar
    my $grammar = Marpa::R2::Grammar->new($options);
    $grammar->precompute();
    
    # save the grammar
    $self->{grammar} = $grammar;
    $self->{g}->{grammar} = $grammar;
    
    # set rules option
    $self->set_option('rules', $grammar->show_rules);
    
    # save bnf rules
    if ($bnf){
        $self->set_option('bnf_rules', $grammar->show_rules);
    }
    
    # TODO: the below 2 calls need to be moved to MarpaX::Parse::Grammar 
    # once {rules} are fully there

    # extract save terminals for lexing
    $self->{g}->{terminals} = $g->_extract_terminals( \@rules, $grammar );
    
    # extract and save lexer rules
    $self->set_option('lexer_rules', $g->_extract_lexer_rules( $options->{rules} ) );
    
    $self->{tree_package} = MarpaX::Parse::Tree->new;
}

# print a variable with comment and stack trace
sub _dump {
    my $comment     = shift || "";
    my $var         = shift;
    my $stack_trace = shift || 0;
    
#    cluck "_dump";
    
    my $dump = ref $var ? 
        DumpTree( $var, "# $comment:", DISPLAY_ADDRESS => 0, DISPLAY_OBJECT_TYPE => 0 )
        :
        "# $comment:\n$var";
    
    $stack_trace ? cluck $dump : say $dump;
}

# =========
# accessors
# =========

sub grammar { $_[0]->{grammar} }

# =================================
# options getting, setting, showing
# =================================

# stringify tokens as name[ name]: value
sub _token_string {

    my $token = shift;
    
    my $_token_string;
    
    # ambigious token
    if (ref $token->[0] eq "ARRAY"){ 
        $_token_string = join(": ", join(' ', map { $_->[0] } @$token), $token->[0]->[1]);
    }
    # unambigious token
    else{ 
        $_token_string = join (': ', @$token);
    }
    
    return $_token_string;
}

# set the value to {$option} key to be printed if "show_$option" is set in the constructor
sub set_option{

    my $self = shift;

    my $option = shift;
    my $value = shift;

    $self->{"$option"} = $value;
}

# return show_$option value or say show_$option's value if show_$option is set to true in the constructor
sub get_option{

    my $self = shift;

    my $option = shift;
    my $value = $self->{$option} || ''; #cluck "value of option '$option' undefined";

    # stringify the option value
    if (ref $value ~~ ["ARRAY", "HASH"]){
        # tokens
        if ($option eq 'tokens'){
            $value = join "\n", map { _token_string($_) } @$value;
        }
        # rules
        elsif ($option eq 'rules'){
            my $rules = $self->grammar->show_rules; 
            $value = $rules;
        }
        # symbols
        elsif ($option eq 'symbols'){
            my $symbols = $self->grammar->show_symbols;
            $value = $symbols;
        }
        # terminals
        elsif ($option eq 'terminals'){
            $value = join "\n", sort @{ $self->{terminals} }
        }
        # lexer rules
        elsif ($option eq 'lexer_rules'){
            my $lr = $self->{lexer_rules};
            $value = join "\n", map { join ': ', $_, $lr->{$_} } sort keys %$lr;
        }
        # recognition failures        
        elsif ($option eq 'recognition_failures'){
            $value = @{ $self->{$option} } ? _dump ("recognition failures", $self->{$option}) : "";
        }
        # anything else
        else{
            $value = Dump $value;
            $value =~ s/^---\n//s;
        }
    } ## stringify the option value

    # set empty value for undefined options
    $value //= '';
    
    # remove newlines, if any
    chomp $value;
    
    return $value;
}

sub comment_option {
    my $self = shift;

    # we derive the comment from the option
    my $comment = shift; 

    # make the comment more readable
    $comment =~ s/_/ /g;
    $comment =~ s/bnf/BNF/g;
    
    return "# $comment:";
}

# print the value of $option to stdout if show_$option is set to true in the constructor
sub show_option{
    my $self = shift;

    my $option = shift;

    if (exists $self->{"show_$option"}){
        my $value = $self->get_option($option);
        if ($value){
            my $comment = $self->comment_option($option);
            say join "\n", $comment, $value;
        }
    }
}

# options getters

sub show_parsed_bnf_rules       { $_[0]->get_option('parsed_bnf_rules') }
sub show_transformed_bnf_rules  { $_[0]->get_option('transformed_bnf_rules') }
sub show_closures               { $_[0]->get_option('closures') }

sub show_bnf_tokens             { $_[0]->get_option('bnf_tokens') }
sub show_bnf_rules              { $_[0]->get_option('bnf_rules') }
sub show_bnf_closures           { $_[0]->get_option('bnf_closures') }

sub show_tokens                 { $_[0]->get_option('tokens') }
sub show_rules                  { $_[0]->get_option('rules') }
sub show_symbols                { $_[0]->get_option('symbols') }
sub show_terminals              { $_[0]->get_option('terminals') }

sub show_lexer_rules            { $_[0]->get_option('lexer_rules') }
sub show_literals               { $_[0]->get_option('literals') }

sub show_lexer_regexes          { $_[0]->get_option('lexer_regexes') }

sub show_recognition_failures   { $_[0]->get_option('recognition_failures') }

# =============================
# parsing BNF and EBNF to rules
# =============================

#
# BNF and EBNF parsers need to be package variables of MarpaX::Parse
# to prevent repeated transformation of their rules
#   
# BNF parser grammar setup
my $bnf_parser = MarpaX::Parse->new({ 
    rules => MarpaX::Parse::BNF::rules,
    default_action => 'AoA',
});

# EBNF parser grammar setup
my $ebnf_parser = MarpaX::Parse->new({ 
    rules => MarpaX::Parse::EBNF::rules,
    default_action => 'AoA',
});

# parse BNF to what will become Marpa::R2 rules after transformation 
# (extraction of closures, adding rules for quantifiers, extraction of lexer rules, etc.)
sub _bnf_to_rules
{
    my $self = shift;
    
    my $bnf = shift;
    
    # parse bnf
    my $bnf_tokens = MarpaX::Parse::BNF->lex_bnf_text($bnf);

    # save bnf tokens
    $self->set_option('bnf_tokens', join "\n", map { join ': ', @$_ } @$bnf_tokens);

    # show BNF tokens if the option is set
    # say "# BNF tokens:\n", $self->show_bnf_tokens if $self->{show_bnf_tokens};
    $self->show_option('bnf_tokens');
    
    # $bnf_parser is a package variable
    # TODO: show bnf parser tokens, rules, and closures if the relevant options are set
    
    # parse BNF tokens to Marpa::R2 rules
    my $rules = $bnf_parser->parse($bnf_tokens);
    
    return $rules;
}

sub _ebnf_to_rules
{
    my $self = shift;
    
    my $ebnf = shift;

#    say Dump $ebnf;
    
    # parse ebnf
    my $ebnf_tokens = MarpaX::Parse::EBNF->lex_ebnf_text($ebnf);
    
#    say "# EBNF tokens:\n", Dump $ebnf_tokens;
    
    # save ebnf tokens
    $self->set_option('ebnf_tokens', join "\n", map { join ': ', @$_ } @$ebnf_tokens);

    # show EBNF tokens if the option is set
    
#    say "# EBNF tokens:\n", $self->show_bnf_tokens if $self->{show_ebnf_tokens};
#    $self->show_option('ebnf_tokens');
    
    # $bnf_parser is a package variable
    # TODO: show bnf parser tokens, rules, and closures if the relevant options are set
    
    # parse EBNF tokens to Marpa::R2 rules
#    say "# parsing EBNF";
#    say $ebnf_parser->show_rules;
    my $rules = $ebnf_parser->parse($ebnf_tokens);
    
#    say "# rules returned:", Dump $rules;
    if (ref $rules->[0]->[0] eq "ARRAY"){
        # sort rules by the maximum NoA number of actions
        my %NoA_indices;
        for my $i (0..@$rules-1){
            my $rule_set = $rules->[$i];
            my $NoA = grep { @$_ eq 3 } @$rule_set;
            $NoA_indices{$NoA} = $i;
        }
        # among those with equal number of actions, select an arbitrary one
        # TODO: ensure grammar amniguity
        $rules = $rules->[ $NoA_indices{(sort { $b <=> $a } keys %NoA_indices)[0]} ];
    }
    
    return $rules;
}

#
# get current options (as-passed), get rules from them, merge new rules, 
# and rebuild MarpaX::Parse
# 
sub merge_token_rules { 
    
    my $self = shift;

    my $token_rules = shift;

    # get initial options
    my $options = $self->{options};
    
    # $token_rules and $options->{rules} need to be both array refs or scalars (strings)
    if (ref $token_rules eq "ARRAY" and ref $options->{rules} eq "ARRAY"){
        # merge arrays
        push @{ $options->{rules} }, @$token_rules;
        
    }
    elsif (ref $token_rules eq "" and ref $options->{rules} eq ""){
        # merge texts
        $options->{rules} .= $token_rules;
    }
    
    # rebuild
    $self->build($options);
}

# =======
# parsing
# =======

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
        # TODO: stringify progress by converting IDs in to rules/symbols
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
    # TODO: get %$features, split $input, set up $tokens
    
    # init recognition failures
    $self->set_option('recognition_failures', []);
    
    $self->show_option('bnf_tokens');
    $self->show_option('bnf_rules');

    # input can be name/value pair arrayref or a string
    # name/value pair arrayrefs are used as is
    my $tokens;
    if (ref $input eq "ARRAY"){
        $tokens = $input;
        # show options if set
        $self->show_option('rules');
        $self->show_option('symbols');
        $self->show_option('terminals');
        $self->show_option('literals');
        # find ambiguous tokens and disambiguate them by adding rules to the grammar
        if ($self->{ambiguity} eq 'tokens'){
#            say "adding rules for ambiguous_tokens";
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
#            _dump "disambiguated tokens", $tokens; 
            # add %$ambiguous_token_rules as generated
#            _dump "ambiguous token rules", $ambiguous_token_rules;
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

    $self->set_option('tokens', $tokens);
    $self->show_option('tokens');
    
    # get grammar and closures
    my $grammar  = $self->{grammar};
    
    my $closures = $self->{closures};
    
    $self->show_option('closures');

#    say $self->get_option('tokens');
#    say $self->get_option('rules');
#    say $self->get_option('terminals');

    # setup recognizer
    my $recognizer = Marpa::R2::Recognizer->new( { 
        grammar => $grammar, 
        closures => $closures,
#        trace_terminals => 3,
    } ) or die 'Failed to create recognizer';

    # read tokens
    for my $i (0..@$tokens-1){
        my $token = $tokens->[$i];
# _dump "read()ing", $token;
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

#    $self->show_option('recognition_failures');
#    $self->show_recognition_failures if $self->{recognition_failures};
    
    # get values    
    my @values;
    my %values; # only unique parses will be returned
    while ( defined( my $value_ref = $recognizer->value() ) ) {
        my $value = $value_ref ? ${$value_ref} : 'No parse';
        # use dumper based on default_action
        my $value_dump = ref $value ? 
            $self->{default_action} eq 'MarpaX::Parse::Tree::tree' ?
                $self->{tree_package}->show_parse_tree($value, 'text') 
                :
                Dump $value
            :
            $value;
        # TODO: $ebnf_parser produces very ambiguous grammars
        next if exists $values{$value_dump};
        # save unique parses for return
        # prepend xml prolog and encode to utf8 if we need to return an XML string
        if ($self->{default_action} eq 'MarpaX::Parse::Tree::xml'){
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


1;
