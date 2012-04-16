use Test::More tests => 12;

use Business::Edifact::Interchange;

my $edi = Business::Edifact::Interchange->new;

$edi->parse_file('examples/INVOIC_019371B.CEI');
my $messages = $edi->messages();

isa_ok( $messages->[0], 'Business::Edifact::Message' );

my $msg_cnt = @{$messages};

cmp_ok( $msg_cnt, '==', 1, 'number of messages returned' );

is( $messages->[0]->type(), 'INVOIC', 'message type returned' );

cmp_ok( $messages->[0]->message_code,
    'eq', '380', 'message code indicate invoice' );

is(
    $messages->[0]->function(),
    'additional transmission',
    'message function type returned'
);

is( $messages->[0]->date_of_message(), '20111124', 'message date returned' );

cmp_ok( $messages->[0]->{supplier_vat_number},
    'eq', '153400995', 'supplier vat number returned' );

cmp_ok( $messages->[0]->{currency}->[1], 'eq', 'GBP', 'currency returned' );

cmp_ok( $messages->[0]->{payment_terms}->{type},
    'eq', 'fixed_date', 'payment terms returned' );

my $invoicelines = $messages->[0]->items();

isa_ok( $invoicelines->[0], 'Business::Edifact::Message::LineItem' );

cmp_ok( $invoicelines->[3]->{item_number},
    'eq', '9781846554070', 'EAN for invoice line returned' );

cmp_ok( $invoicelines->[3]->{quantity_invoiced},
    '==', 2, 'invoiced qty returned' );
