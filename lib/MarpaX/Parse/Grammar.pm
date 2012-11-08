package MarpaX::Parse::Grammar;

use 5.010;
use strict;
use warnings;

use Carp qw{cluck};
use YAML;

use Marpa::R2;

use MarpaX::Parse::Tree;

use Math::Combinatorics;

use Clone qw(clone);

my $options = {

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

    # transform quantified symbols into sequence (by default) or recursive rules
    quantifier_rules => undef,

    # if true, nullable symbols will be added instead removing the rules 
    # with ?/*-quanfitied symbols
    nullables_for_quantifiers => undef,
    
};

sub new{

    my $class = shift;
    my $options = shift;
    
    my $self = {};
    
    # clone options to enable adding rules to grammar
    $self->{options} = clone $options;

    # set defaults
    $self->{quantifier_rules} //= 'sequence';
    $self->{ambiguity} //= 'input_model';

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
    
    # set defaults
    $self->{quantifier_rules}               //= 'sequence';
    $self->{ambiguity}                      //= 'input_model';
    $self->{recognition_failure_sub}        //= \&recognition_failure;
    
    # transform rules
    my @rules = @{ $options->{rules} };

    # quantifiers to rules
    $self->_quantifiers_to_rules( \@rules );

    # extract closures and generate actions for Recognizer
    my $closures = $self->_closures_to_actions( \@rules );
    $self->{closures} = $closures;

    # handle default action
    $self->_set_default_action($options);    

    # TODO: parse() needs this; to be removed
    $self->{default_action} = $options->{default_action};
    
    # set start to lhs of the first rule if not set
    if (not exists $options->{start}){
        $options->{start} = $self->_extract_start_symbol( \@rules );
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
    
    # set rules option
    $self->set_option('rules', $grammar->show_rules);
}

sub grammar { $_[0]->{grammar} }

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

# 
# rule transform methods
#

sub _set_default_action
{
    my $self = shift;
    
    my $options = shift;
    
    # if default action exists in MarpaX::Parse::Tree package then use it
    my $da = $options->{default_action};
    if (defined $da){
        if (exists $MarpaX::Parse::Tree::{$da}){
            $options->{default_action} = 'MarpaX::Parse::Tree::' . $da;
        }
    }
    # otherwise set _default_action which prints the rules and their contents
    else{
        $options->{default_action} = 'MarpaX::Parse::Tree::' . 'AoA';
    }
    $self->{default_action} = $options->{default_action};
}

sub _rule_signature
{
    my ($lhs, $rhs) = @_;
    return "$lhs -> " . join ' ', @$rhs;
}

sub _action_name
{
    return "action(" . _rule_signature(@_) . ")";
}

sub _extract_start_symbol
{
    my $self = shift;
    
    my $rules = shift;
    
    my $rule0 = $rules->[0];
    
    my $start = ref $rule0 eq "HASH" ? $rule0->{lhs} : $rule0->[0];
    $self->{start} = $start;
    
    return $start;
}

sub _closures_to_actions
{
    my $self = shift;
    
    my $rules = shift;
    
#    say "# _closures_to_actions: rules:\n", Dump $rules;
    
    my $closures = {};
    
    for my $rule (@$rules){
        my ($lhs, $rhs, $closure);
        given (ref $rule){
            when ("HASH"){
                # get the rule's parts
                $lhs = $rule->{lhs};
                $rhs = $rule->{rhs};
                $closure = $rule->{action};
                # we need anonymous subs and not the action names
                if (defined $closure and ref $closure eq "CODE"){
                    # make action name
                    my $an = _action_name($lhs, $rhs);
                    # replace closure with action name
                    $closures->{$an} = $closure;
                    # add closure for recognizer
                    $rule->{action}  = $an;
                }
            }
            when ("ARRAY"){
                # get the rule's parts
                ($lhs, $rhs, $closure) = @$rule;
                # we need anonymous subs and not the action names
                if (defined $closure  and ref $closure eq "CODE"){
                    # make action name
                    my $an = _action_name($lhs, $rhs);
                    # replace closure with action name
                    $rule->[-1]      = $an;
                    # add closure for recognizer
                    $closures->{$an} = $closure;
                }
            }
        }
        
    }
    
#    say "# _closures_to_actions: closures:\n", Dump $closures;
    
    return $closures;
}

sub _quantifiers_to_rules
{   
    my $self = shift;
    
    my $rules = shift;
    
#    say "# rules ", Dump $rules;
    
    # symbols quantified with * or + require adding sequence rules
    my $quantified_symbol_rules = [];

    # symbols quantified with * or ? require adding rules without such symbols
    # more than one symbol per rules can be  * or ? quantified hence 
    # $nullable_symbol_indices->{quantified_rule_index}->{nullable_symbol_index}
    my $nullable_symbol_indices = {};
    
    # prevent duplication of sequence rules' lhs 
    my $sequence_lhs = {}; 

    # process rules
    for my $j (0..@$rules-1){
        my $rule = $rules->[$j];
#        say "# rule ", Dump $rule;
        # get lhs and rhs
        my ($lhs, $rhs);
        given (ref $rule){
            when ("HASH"){
                $lhs = $rule->{lhs};
                $rhs = $rule->{rhs};
            }
            when ("ARRAY"){
                ($lhs, $rhs) = @$rule;
            }
        }
#        say "# $lhs -> ", Dump $rhs;
        # check symbols ending with quantifiers
        for my $i (0..@$rhs-1){
            my $symbol = $rhs->[$i];
            # TODO: better checking for regexes (\d+)
            if ($symbol =~ m/(\?|\*|\+)$/ and $symbol !~ m{\\}){
                my $quantifier = $1;
#                say "$quantifier, $rhs->[$i]";
                # setup sequence item ($symbol without quantifier)
                my $non_quantified_symbol = $symbol;
                $non_quantified_symbol =~ s/\Q$quantifier\E$//;
#                say "$quantifier, $rhs->[$i], $symbol";
                # dispatch on quantifier
                given ($quantifier){
                    when ("?"){
#                        say "# zero or one ", Dump $rule;
                        # set rule's nullable symbol indices
                        $nullable_symbol_indices->{$j}->{$i} = undef;
                        # replace quantified symbol to non-quantified in the rule
                        $rhs->[$i] = $non_quantified_symbol;
                    }
                    # add min => 0 or min => 1 sequence 
                    when ([qw(* +)]){
                        
                        # sequence lhs must be unique
                        unless (exists $sequence_lhs->{$symbol} ){
                            if ($self->{quantifier_rules} eq 'recursive'){
#                                say "sequences as recursive rules";
                                my $item = $non_quantified_symbol;
                                my $seq = $symbol;
                                # seq ::= item
                                push @$quantified_symbol_rules, { 
                                    lhs     => $seq,
                                    rhs     => [ $item ],
                                    action  => sub { 
                                        [ $_[1] ];
                                    },
                                };
                                # seq ::= item seq
                                push @$quantified_symbol_rules, { 
                                    lhs     => $seq,
                                    rhs     => [ $seq, $item ],
                                    action  => sub { 
                                        if (ref $_[1] eq "" and ref $_[2] eq ""){
                                            return ($_[1] ? $_[1] : '') . ($_[2] ? $_[2] : '');
                                        }
                                        else{
                                            push @{ $_[1] }, $_[2];
                                        }
                                        return $_[1];
                                    },
                                };
                            }
                            else{
#                                say "sequences as sequence rules";
                                push @$quantified_symbol_rules, { 
                                    lhs => $symbol,
                                    rhs => [ $non_quantified_symbol ],
                                    min => $quantifier eq '+' ? 1 : 0,
#                                    action => sub { 
                                        # strip per-parse variable
#                                        shift;
    #                                    say Dump \@_;
    #                                    say defined @_;
    #                                    say join '', @_;
                                        # return empty array ref rather than undef for null (zero-item) sequences
#                                        \@_;
#                                    },
                                };
                            }
                            $sequence_lhs->{$symbol} = undef;
                        }
                        # set rule's nullable symbol indices
                        if ($quantifier eq '*'){
                            $nullable_symbol_indices->{$j}->{$i} = undef;
                        }
                    }
                }
            }
        }
    }
    
    # add rules for quantified symbols
#    say Dump $quantified_symbol_rules;
    push @$rules, @$quantified_symbol_rules;

    # just add [ nullable_symbol => [] ] rules if the options are set
    if ($self->{nullables_for_quantifiers}){
        my @nullables;
        my %nullables;
        for my $j (keys %$nullable_symbol_indices){
            my $rule = $rules->[$j];

            my ($lhs, $rhs);
            given (ref $rule){
                when ("HASH"){
                    $lhs = $rule->{lhs};
                    $rhs = $rule->{rhs};
                }
                when ("ARRAY"){
                    ($lhs, $rhs) = @$rule;
                }
            }

            my @nullables = sort keys %{ $nullable_symbol_indices->{$j} };
            for my $nullable (@nullables){
#                say $rhs->[$nullable];
                # avoid tule duplication
                next if exists $nullables{ $rhs->[$nullable] };
                push @$rules, [ $rhs->[$nullable] => [] ];
                $nullables{ $rhs->[$nullable] } = undef;
            }
        }
    }
    else {
        # generate and add rules with nullable symbols
        my @rules_with_nullables;
        for my $j (keys %$nullable_symbol_indices){
            my $rule = $rules->[$j];

            my ($lhs, $rhs);
            given (ref $rule){
                when ("HASH"){
                    $lhs = $rule->{lhs};
                    $rhs = $rule->{rhs};
                }
                when ("ARRAY"){
                    ($lhs, $rhs) = @$rule;
                }
            }

            my @nullables = sort keys %{ $nullable_symbol_indices->{$j} };
            # generate the indices of symbols to null
    #        say "$lhs -> @$rhs\nnullables:@nullables";
            my @symbols_to_null;
            for my $k (1..@nullables){
                my @combinations = combine($k, @nullables);
                push @symbols_to_null, \@combinations;
    #            say "$k:", join ' | ', map { join ' ', @$_ } @combinations;
            }
            # generate nullables rhs by deleting nullable symbols according to generated indices
            for my $combinations (@symbols_to_null){
                # delete (null) nullable symbols
                for my $combination (@$combinations){
    #                say "@$combination";
                    my @nullable_rhs = @$rhs;
                    for my $index (@$combination){
                        $nullable_rhs[$index] = undef;
                    }
                    @nullable_rhs = grep {defined} @nullable_rhs;
    #                say "$lhs -> @nullable_rhs";
                    push @rules_with_nullables, { lhs => $lhs, rhs => \@nullable_rhs };
                }
            }
        }
    #    say Dump \@rules_with_nullables;
        push @$rules, @rules_with_nullables;
    }
    
}

sub _extract_terminals
{
    my $self = shift;
    
    my $symbols = $self->_extract_symbols;

#    say "# _extract_terminals: symbols:", Dump $symbols;
    
    my $terminals = [];
    for my $symbol (keys %$symbols){
        if ($self->{grammar}->check_terminal($symbol)){
            push @$terminals, $symbol;
        }
    }
    
#    say "# _extract_terminals: terminals:", Dump $terminals;
    
    return $terminals;
}

sub _extract_symbols
{
    my $self = shift;
    
    my $rules = $self->{options}->{rules};
    
    my $symbols = {};
    
    for my $rule (@$rules){
        my ($lhs, $rhs);
        given (ref $rule){
            when ("HASH"){
                # get the rule's parts
                $lhs = $rule->{lhs};
                $rhs = $rule->{rhs};
            }
            when ("ARRAY"){
                # get the rule's parts
                ($lhs, $rhs) = @$rule;
            }
        }
        for my $symbol ($lhs, @$rhs){
            $symbols->{$symbol} = undef;
        }
    }
    return $symbols;
}

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

1;

