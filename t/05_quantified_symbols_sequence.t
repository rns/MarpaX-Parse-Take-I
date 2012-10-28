use 5.010;
use strict;
use warnings;

use Test::More;

use YAML;

use Marpa::Easy;

my $inputs = [
# head1 item? tail1
    [
        [ 'head1', 'head1' ],
        [ 'tail1', 'tail1' ],
    ],
    [
        [ 'head1', 'head1' ],
        [ 'item', 'item' ],
        [ 'tail1', 'tail1' ],
    ],
# head2 item1? item2? tail2    
    [
        [ 'head2', 'head2' ],
        [ 'tail2', 'tail2' ],
    ],
    [
        [ 'head2', 'head2' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'tail2', 'tail2' ],
    ],
    [
        [ 'head2', 'head2' ],
        [ 'item1', 'item1' ],
        [ 'tail2', 'tail2' ],
    ],
    [
        [ 'head2', 'head2' ],
        [ 'item2', 'item2' ],
        [ 'tail2', 'tail2' ],
    ],
# head3 item1? item2? item3? tail3
    [
        [ 'head3', 'head3' ],
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'item3', 'item3' ],
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item2', 'item2' ],
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item3', 'item3' ],
        [ 'tail3', 'tail3' ],
    ],
    
# head1 item+
    [
        [ 'head1', 'head1' ],
        [ 'item', 'item' ],
    ],
    [
        [ 'head1', 'head1' ],
        [ 'item', 'item' ],
        [ 'item', 'item' ],
    ],
# head2 item1+ item2+    
    [
        [ 'head2', 'head2' ],
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
    ],
    [
        [ 'head2', 'head2' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
    ],
    [
        [ 'head2', 'head2' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
    ],
    [
        [ 'head2', 'head2' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
    ],
# head3 item1+ item2+ item3+
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
        [ 'item3', 'item3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
        [ 'item3', 'item3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
    ],

# item+ tail1
    [
        [ 'item', 'item' ],
        [ 'item', 'item' ],
        [ 'tail1', 'tail1' ],
    ],
    [
        [ 'item', 'item' ],
        [ 'tail1', 'tail1' ],
    ],
# item1+ item2+ tail2
    [
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'tail2', 'tail2' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'tail2', 'tail2' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'tail2', 'tail2' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'tail2', 'tail2' ],
    ],

# item1+ item2+ item3+ tail3
    [
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
        [ 'item3', 'item3' ],
        [ 'tail3', 'tail3' ],
    ],
# head1 item*
    [
        [ 'head1', 'head1' ],
    ],
    [
        [ 'head1', 'head1' ],
        [ 'item', 'item' ],
        [ 'item', 'item' ],
    ],
# head2 item1* item2*
    [
        [ 'head2', 'head2' ],
    ],
    [
        [ 'head2', 'head2' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
    ],
    [
        [ 'head2', 'head2' ],
        [ 'item1', 'item1' ],
    ],
    [
        [ 'head2', 'head2' ],
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
    ],
    [
        [ 'head2', 'head2' ],
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
    ],

# head3 item1* item2* item3*
    [
        [ 'head3', 'head3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'item3', 'item3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
    ],
    [
        [ 'head3', 'head3' ],
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
        [ 'item3', 'item3' ],
    ],

# item* tail1
    [
        [ 'tail1', 'tail1' ],
    ],
    [
        [ 'item', 'item' ],
        [ 'tail1', 'tail1' ],
    ],

# item1* item2* tail2
    [
        [ 'tail2', 'tail2' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'tail2', 'tail2' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'tail2', 'tail2' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'tail2', 'tail2' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'tail2', 'tail2' ],
    ],

# item1* item2* item3* tail3
    [
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
        [ 'item3', 'item3' ],
        [ 'tail3', 'tail3' ],
    ],
    [
        [ 'item1', 'item1' ],
        [ 'item1', 'item1' ],
        [ 'item2', 'item2' ],
        [ 'item2', 'item2' ],
        [ 'item3', 'item3' ],
        [ 'tail3', 'tail3' ],
    ],

];

my $rules = [
 
    [ sequence => [qw(head_zero_or_one_tail)] ],
    [ sequence => [qw(head_zero_or_one_2_tail)] ],
    [ sequence => [qw(head_zero_or_one_3_tail)] ],
    [ sequence => [qw(head2_zero_or_one_3_tail2)] ],

    [ sequence => [qw(head_zero_or_more)] ],
    [ sequence => [qw(head_zero_or_more_2)] ],
    [ sequence => [qw(head_zero_or_more_3)] ],
    
    
    [ sequence => [qw(zero_or_more_tail)] ],
    [ sequence => [qw(zero_or_more_2_tail)] ],
    [ sequence => [qw(zero_or_more_3_tail)] ],

    [ sequence => [qw(head_one_or_more)] ],
    [ sequence => [qw(head_one_or_more_2)] ],
    [ sequence => [qw(head_one_or_more_3)] ],
    [ sequence => [qw(one_or_more_tail)] ],
    [ sequence => [qw(one_or_more_2_tail)] ],
    [ sequence => [qw(one_or_more_3_tail)] ],        

# ?    
    [ head_zero_or_one_tail => [qw(head1 item? tail1)] ],
    [ head_zero_or_one_2_tail => [qw(head2 item1? item2? tail2)] ],
    [ head_zero_or_one_3_tail => [qw(head3 item1? item2? item3? tail3)] ],

    [ head2_zero_or_one_3_tail2 => [qw(head2 item1? tail2 item2? head2 item3? tail2)] ],
    
# *
    [ head_zero_or_more => [qw(head1 item*)] ],
    [ head_zero_or_more_2 => [qw(head2 item1* item2*)] ],
    [ head_zero_or_more_3 => [qw(head3 item1* item2* item3*)] ],

# *
    [ zero_or_more_tail => [qw(item* tail1)] ],
    [ zero_or_more_2_tail => [qw(item1* item2* tail2)] ],
    [ zero_or_more_3_tail => [qw(item1* item2* item3* tail3)] ],

# +
    [ head_one_or_more => [qw(head1 item+)] ],
    [ head_one_or_more_2 => [qw(head2 item1+ item2+)] ],
    [ head_one_or_more_3 => [qw(head3 item1+ item2+ item3+)] ],
    [ one_or_more_tail => [qw(item+ tail1)] ],
    [ one_or_more_2_tail => [qw(item1+ item2+ tail2)] ],
    [ one_or_more_3_tail => [qw(item1+ item2+ item3+ tail3)] ],
];

my $me = Marpa::Easy->new({ 
    rules => $rules,
    default_action => 'AoA',
});

say $me->grammar->show_rules();

for my $input (@$inputs){
    my $input_str = join ' ', map { $_->[0] } @$input;
    my $value = $me->parse($input);
    unless (
        is 
            join(' ', map { ref $_ eq "ARRAY" ? join ' ', @$_ : $_ } ref $value eq "ARRAY" ? @$value : $value ), 
            $input_str,
            "<$input_str> parsed with quantifiers in rules"
        ){
        say "# value: ", Dump $value;
    }
}
    
done_testing;
