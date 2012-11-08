package MarpaX::Parse::Lexer::BNF;

use 5.010;
use strict;
use warnings;

use YAML;

sub new{
    my $class = shift;
    my $self = {};
    bless $self, $class;
    $self;
}

my $balanced_terminals = {
    '%{.+?%}' => 'action',
    '".+?"' => 'literal',
    "'.+?'" => 'literal',
};

# add passed pairs replacing keys as needed
sub set_balanced_terminals{
    my $self = shift;
    my $value = shift;
    %$balanced_terminals = ();
    while (my ($k, $v) = each %$value){
        $balanced_terminals->{$k} = $v;
    }
#    say Dump $balanced_terminals;
}

my $literal_terminals = {
    '::=' => '::=',
    '|' => '|',
};

sub set_literal_terminals{
    my $self = shift;
    my $value = shift;
    %$literal_terminals = ();
    while (my ($k, $v) = each %$value){
        $literal_terminals->{$k} = $v;
    }
#    say Dump $literal_terminals;
}

sub lex
{
    my $self = shift;
    
    my $bnf_text = shift;
    
    # set up regexes; the rest must be symbols
    my $balanced_terminals_re = join '|', keys %$balanced_terminals;
    my $literal_terminals_re = join '|', map { quotemeta } keys %$literal_terminals;
    
#    say $balanced_terminals_re;
#    say $literal_terminals_re;
    my $tokens = [];
    
#    say $bnf_text;
    
    # trim bnf text
    $bnf_text =~ s/^\s+//s;
    $bnf_text =~ s/\s+$//s;

    # remove comments at line start and trim
    $bnf_text =~ s/^#.*?$//mg;
    $bnf_text =~ s/^\s+//s;
    $bnf_text =~ s/\s+$//s;
    
    # split on balanced
    for my $on_balanced (split /($balanced_terminals_re)/s, $bnf_text){
        
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

#    say "# bnf tokens ", Dump $tokens;
    return $tokens; 
}

1;
