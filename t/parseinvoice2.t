use Test::More tests => 16;

use Business::Edifact::Interchange;

my $edi = Business::Edifact::Interchange->new;

$edi->parse_file('examples/invoice_example');
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

is( $messages->[0]->date_of_message(), '20010831', 'message date returned' );

cmp_ok( $messages->[0]->{supplier_vat_number},
    'eq', '123456789', 'supplier vat number returned' );

#cmp_ok( $messages->[0]->{currency}->[1], 'eq', 'GBP', 'currency returned' );

cmp_ok( $messages->[0]->{payment_terms}->{type},
    'eq', 'basic', 'payment terms returned' );

cmp_ok( $messages->[0]->{payment_terms}->{terms}->[2],
    'eq', 'D', 'payment terms are in days' );
cmp_ok( $messages->[0]->{payment_terms}->{terms}->[3],
    '==', '30', 'payment terms are 30 days' );

my $moa_values = @{ $messages->[0]->{monetary_amount} };
cmp_ok( $moa_values, '==', 7, 'message level monetary values returned' );

my $invoicelines = $messages->[0]->items();

isa_ok( $invoicelines->[0], 'Business::Edifact::Message::LineItem' );

cmp_ok( $invoicelines->[1]->{item_ID_number}->{number},
    'eq', '0140374132', 'ID for invoice line returned' );
cmp_ok( $invoicelines->[1]->{item_ID_number}->{type},
    'eq', 'ISBN', 'ID for invoice line is ISBN' );

cmp_ok( $invoicelines->[1]->{quantity_invoiced},
    '==', 3, 'invoiced qty returned' );

cmp_ok( $invoicelines->[1]->{lineitem_amount},
    '==', 10.77, 'lineitem amount returned' );
