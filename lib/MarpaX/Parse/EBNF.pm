package MarpaX::Parse::EBNF;

use 5.010;
use strict;
use warnings;

use YAML;

use Eval::Closure;

sub new
{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

my $action_prolog = q{
    # start action prolog
    # imports
    use 5.010; use strict; use warnings; use YAML;
    # rule parts and signature
    my ($rule_lhs, @rule_rhs) = $Marpa::R2::Context::grammar->rule($Marpa::R2::Context::rule);
    my $rule_signature = $rule_lhs . ' -> ' . join ' ', @rule_rhs;
    # more dumpers
    use Data::Dumper;
    $Data::Dumper::Terse = 1;          # don't output names where feasible
    $Data::Dumper::Indent = 0;         # turn off all pretty print
    # end action prolog
};

my $ebnf_rules = [
    
    # grammar ::= production+
    [ grammar => [qw( production+ )], sub {
        shift;
        
        my @productions = @_;
#        say "# productions:\n", Dump \@productions;
        my $rules = [];
        
        if (@productions == 1 and ref $productions[0] ne "ARRAY"){
            push $rules, @productions;
        }
        else{
            for my $production (@productions){
                for my $Marpa_rules (@$production){
#                    say "# production rules:\n", Dump $Marpa_rules;
                    push @$rules, ref $Marpa_rules->[0] eq "ARRAY" ? @$Marpa_rules : $Marpa_rules;
                }
            }
        }
        
#        say "# rules to return:\n", Dump $rules;
        $rules;
    } ],
    
    # production    ::= lhs '::=' rhs action?
    [ production => [qw( lhs ::= rhs action )], 
        sub {
            
            my $per_parse = shift;
            
            # set up subrules
            my $subrules    = $per_parse->{subrules};
            my $subrule_no  = $per_parse->{subrule_no};
            
            my ($lhs, undef, $rhs, $prod_action) = @_;
            
            my $rules = [];
            
#            say "=-" x 32;
#            say "# adding\n";

#            say "# production/lhs\n", $lhs;
#            say "# production/rhs\n", Dump $rhs;
#            say "# production/action\n", $prod_action if $prod_action;
#            say "# subrules\n", Dump $subrules;
            
            # add rule
            my $alt = $rhs->{alternation};
            for my $seq ( map { $_->{sequence} } @$alt ){
                my @symbols = map { ref $_ eq "HASH" ? $_->{symbol} : "$lhs$_" } @$seq;
#                say "$lhs -> @symbols";
                # set up rule
                my $rule = [ $lhs, \@symbols ];
                # add production action if any
                if ($prod_action){
                    # setup production action closure
                    my $closure = eval_closure(
                        source => 'sub{' . $action_prolog . substr($prod_action, 2, -3) . '}',
                        description => 'action of rule ' . 
                            $rule->[0] . ' -> ' . join ' ', @{ $rule->[1] },
                    );
                    # add production action closure
                    push @$rule, $closure;
                }
                # add rule
                push @$rules, $rule;
            }            
            
            # add subrules prepending the rule's $lhs
            for my $subrule_lhs (sort keys %$subrules){
                my $subrule_rhs = $subrules->{$subrule_lhs};
#                say "# subrule:\n$subrule_lhs\n", Dump $subrule_rhs;
                for my $seq (map { $_->{sequence} } @{ $subrule_rhs->{alternation} }){
                    my @symbols = map { ref $_ eq "HASH" ? $_->{symbol} : "$lhs$_" } @$seq;
                    # remove quantifiers
                    $subrule_lhs =~ s/\?|\*|\+//;
#                    say "$lhs$subrule_lhs -> @symbols";
                    my $rule = [ "$lhs$subrule_lhs", \@symbols ];
                    # add action if any
                    my $subrule_action = $subrule_rhs->{action};
                    if ($subrule_action){
                        # setup subrule action closure
                        my $closure = eval_closure(
                            source => 'sub{' . $action_prolog . substr($subrule_action, 2, -3) . '}',
                            description => 'action of rule ' . 
                                $rule->[0] . ' -> ' . join ' ', @{ $rule->[1] },
                        );
                        # add subrule action closure
                        push @$rule, $closure;
                    }
                    push @$rules, $rule;
                }            
            }
            
            # reinitialize subrules
            %{ $per_parse->{subrules} } = ();
            $per_parse->{subrule_no}    = 0;
            
#            say "# rules:\n", Dump $rules;
            $rules;
        }
    ],
    
    # lhs ::= symbol
    [ lhs => [qw( symbol )] ],

    # rhs ::= term action? (rhs | term action?)*
    [ 'rhs' => [qw(term action)], sub { 
#        say Dump \@_;
        my $term = { alternation => [ $_[1] ] };
        $term->{alternation}->[0]->{action} = $_[2] if defined $_[2];
        $term;
    } ],

    [ 'rhs' => [qw(rhs '|' term action )], sub { 
#        say "# :\n", Dump \@_;
        $_[3]->{action} = $_[4] if defined $_[4];
        push @{ $_[1]->{alternation} }, $_[3];
        $_[1]
    } ],
    
    # term ::= factor | term factor
    [ term => [qw{ factor }], sub {
        { sequence => [ $_[1] ] }
    } ],

    [ term => [qw{ term factor }], sub {
        push @{ $_[1]->{sequence} }, $_[2];
        $_[1]
    } ],
    
    # factor ::= symbol quantifier
    [ factor => [qw( symbol quantifier )], 
        sub { 
            { symbol => $_[1] . ($_[2] ? $_[2] : '')  }
        } 
    ], 

    # TODO: factor ::= '(' identifier ':' rhs ')' quantifier? action?
    # ...
    
    # factor ::= '(' rhs ')' quantifier? action?
    [ factor => [qw( '(' rhs ')' quantifier action )], 
        sub { 
#            say "# factor (subrule to be set up):\n", Dump \@_;
            my $per_parse = shift;
            
            # set up subrules
            my $subrules    = $per_parse->{subrules};
            my $subrule_no  = $per_parse->{subrule_no};
            
            my $subrule = $_[1];

            my $quantifier = $_[3] if defined $_[3] and $_[3] ~~ ['?', '*', '+'];
            $quantifier //= '';

            my $action = $_[-1] if defined $_[-1] and index($_[-1], "%{", 0) == 0;
            
            # add subrule under provisional lhs with quantifier
            my $prov_lhs = "__subrule" . $subrule_no++ . ($_[3] ? $_[3] : '');
            $subrules->{$prov_lhs} = $subrule;
            
            # save subrule number and subrules
            $per_parse->{subrule_no} = $subrule_no;
            $per_parse->{subrules}   = $subrules;
            
#            say "# subrules:\n", $subrule_no, Dump $subrules;
            
            # return provisional lhs
            $prov_lhs;
        } 
    ], 

    [ action => [] ],
    [ action => [qw(action_in_tags)], sub { $_[1] } ],

    [ quantifier => [], ],
    [ quantifier => [qw( '?' )] ], 
    [ quantifier => [qw( '*' )] ], 
    [ quantifier => [qw( '+' )] ], 

    [ symbol     => [qw( identifier )] ],
    [ symbol     => [qw( literal    )] ],

];

sub rules { $ebnf_rules }

my $balanced_terminals = {
    '%{.*?%}' => 'action_in_tags',
    '".+?"' => 'literal',
    "'.+?'" => 'literal',
};
my $balanced_terminals_re = join '|', keys %$balanced_terminals;

my $literal_terminals = {
    '::=' => '::=',
    "|" => "'|'",
    '(' => "'('",
    ')' => "')'",
    '?' => "'?'",
    '*' => "'*'",
    '+' => "'+'",
};
my $literal_terminals_re = join '|', map { quotemeta } keys %$literal_terminals;
# and the rest must be symbols

sub lex_ebnf_text
{
    my $self = shift;
    
    my $ebnf_text = shift;
    
    my $tokens = [];
    
#    say $ebnf_text;
    
    # trim ebnf text
    $ebnf_text =~ s/^\s+//s;
    $ebnf_text =~ s/\s+$//s;

    # remove comments at line start and trim
    $ebnf_text =~ s/^#.*?$//mg;
    $ebnf_text =~ s/^\s+//s;
    $ebnf_text =~ s/\s+$//s;
    
    # split on balanced
    for my $on_balanced (split /($balanced_terminals_re)/s, $ebnf_text){
        
        # trim
        $on_balanced =~ s/^\s+//s;
        $on_balanced =~ s/\s+$//s;
#        say "on balanced: <$on_balanced>";

        # find balanced terminals
        if ($on_balanced =~ /^$balanced_terminals_re$/s){
            for my $re (keys %$balanced_terminals){
                if ($on_balanced =~ m/^$re$/s){
#                    say $balanced_terminals->{$re}, ": ",$on_balanced;
                    push @$tokens, [ $balanced_terminals->{$re}, $on_balanced ];
                }
            }      
        }
        else{

            # remove comments and trim
            $on_balanced =~ s/#.*?$//mg;
            $on_balanced =~ s/^\s+//s;
            $on_balanced =~ s/\s+$//s;
            
            # split on literals
            for my $on_literal (split /($literal_terminals_re)/s, $on_balanced){
                $on_literal =~ s/^\s+//s;
                $on_literal =~ s/\s+$//s;
#                say "on literal: <$on_literal>";
                # find literal terminals
#                say "on literal: <$on_literal>";
                if ($on_literal =~ /^$literal_terminals_re$/){
                    for my $re (keys %$literal_terminals){
                        if ($on_literal =~ m/^\Q$re\E$/){
#                            say $literal_terminals->{$re}, ": ",$on_literal;
                            push @$tokens, [ $literal_terminals->{$re}, $on_literal ];
                        }
                    }      
                }
                else{
                    for my $identifier (split /\s+/s, $on_literal){
                        $identifier =~ s/^\s+//s;
                        $identifier =~ s/\s+$//s;
#                        say "identifier: $identifier";
                        push @$tokens, [ 'identifier', $identifier ];
                    }
                }
            }
        }
    }

#    say "# ebnf tokens ", Dump $tokens;
    return $tokens; 
}

1;
