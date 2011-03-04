use Test::More tests => 2;

use Edifact::Interchange;

my $edi = Edifact::Interchange->new;

$edi->parse_file('examples/SampleQuote.txt');

my $messages = $edi->messages();

isa_ok($messages->[0], 'Edifact::Message');

my $msg_cnt = @{$messages};

cmp_ok($msg_cnt, '==', 1, 'number of messages returned');

