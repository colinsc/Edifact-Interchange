package Business::Edifact::Message;

use warnings;
use strict;
use 5.010;
use Carp;
use Business::Edifact::Message::LineItem;

=head1 NAME

Business::Edifact::Message - Class that models Edifact Messages

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

Parses an individual Edifact message
Message objects are instantiated by Business::Edifact::Interchange and an array
of them is returned in its messages function
   $interchange->parse($incoming);
   my $m_array = $interchange->messages();
   for my $msg (@{$m_array}) {
      ...retrieve message data
   }

=cut

=head1 SUBROUTINES/METHODS

=head2 new

Called by Business::Edifact::Interchange to instantiate a new Message
object. The caller passes the header fields with the 
reference number identifier and message type

=cut

sub new {
    my $class      = shift;
    my $hdr_fields = shift;

    my $self = {
        ref_num            => $hdr_fields->[0]->[0],
        message_identifier => $hdr_fields->[1],
        reference          => [],
        addresses          => [],
        lines              => [],
        segment_group      => 0,
        type               => $hdr_fields->[1]->[0],
        segment_handler    => _init_sh(),
    };

    bless $self, $class;
    return $self;
}

sub _init_sh {
    return {
        BGM => \&handle_bgm,
        DTM => \&handle_dtm,
        PAT => \&handle_pat,
        RFF => \&handle_rff,
        CUX => \&handle_cux,
        NAD => \&handle_nad,
        LIN => \&handle_lin,
        PIA => \&handle_pia,
        IMD => \&handle_imd,
        QTY => \&handle_qty,
        GIR => \&handle_gir,
        MOA => \&handle_moa,
        TAX => \&handle_tax,
        ALC => \&handle_alc,
        RTE => \&handle_rte,
        LOC => \&handle_loc,
        PRI => \&handle_pri,
        UNS => \&handle_uns,
        CNT => \&handle_cnt,
        FTX => \&handle_ftx,
    };
}

=head2 add_segment

Process the next data segment

=cut

sub add_segment {
    my $self     = shift;
    my $tag      = shift;
    my $data_arr = shift;

    my $handler = $self->{segment_handler}->{$tag};
    if ($handler) {
        $self->$handler($data_arr);
    }
    return;
}

=head2 type

return the message's type
e.g. 'QUOTES' or 'ORDERS'

=cut

sub type {
    my $self = shift;
    return $self->{type};    # e.g. 'QUOTES'
}

=head2 function

Returns the message's function field
May be 'original' or 'retransmission'

=cut

sub function {
    my $self = shift;
    my $f    = $self->{bgm_data}->[2]->[0];
    if ( $f == 9 ) {
        return 'original';
    }
    elsif ( $f == 7 ) {
        return 'retransmission';
    }
    else {
        return $f;
    }
}

=head2 currency_code

=cut

sub currency_code {
    my $self = shift;
    if ( exists $self->{currency} ) {
        return $self->{currency}->[1];
    }
    return;
}

=head2 reference_number

=cut

sub reference_number {
    my $self = shift;
    return $self->{ref_num};
}

=head2 date_of_message

=cut

sub date_of_message {
    my $self = shift;
    return $self->{message_date};
}

=head2 items

return the list of lineitems

=cut

sub items {
    my $self = shift;
    return $self->{lines};
}

=head2 handle_bgm

=cut

sub handle_bgm {
    my ( $self, $data_arr ) = @_;
    $self->{bgm_data} = $data_arr;
    return;
}

=head2 handle_dtm

NB DTM can occur in different segment groups

=cut

sub handle_dtm {
    my ( $self, $data_arr ) = @_;
    my ( $qualifier, $date, $format ) = @{ $data_arr->[0] };
    if ( $self->{segment_group} == 0 ) {    # message header
                                            #TBD standard allows 35 repeats
        if ( $qualifier == 137 ) {
            $self->{message_date} = $date;
        }
        elsif ( $qualifier == 36 ) {
            $self->{expirty_date} = $date;
        }
        elsif ( $qualifier == 131 ) {
            $self->{tax_point_date} = $date;
        }
    }
    elsif ( $self->{segment_group} == 27 ) {
        $self->{lines}->[-1]->addsegment( 'datetimeperiod', $data_arr );
    }
    elsif ( $self->{segment_group} == 11 ) {
        $self->{payment_terms}->{payment_date} = $date;
    }
    return;
}

=head2 handle_pat

=cut

sub handle_pat {    # invoices only
    my ( $self, $data_arr ) = @_;
    if ( $data_arr->[0]->[0] == 1 ) {
        $self->{payment_terms} = {
            type  => 'basic',
            terms => $data_arr->[2],
        };
    }
    elsif ( $data_arr->[0]->[0] == 3 ) {
        $self->{payment_terms} = { type => 'fixed_date', };
    }
    return;
}

=head2 handle_rff

=cut

sub handle_rff {
    my ( $self, $data_arr ) = @_;
    if ( $data_arr->[0]->[0] eq 'VA' ) {
        $self->{supplier_vat_number} = $data_arr->[0]->[1];
    }
    if ( $self->{segment_group} == 0 ) {
        $self->{segment_group}     = 1;    # 1 mandatory occurence
        $self->{message_reference} = {
            qualifier => $data_arr->[0]->[0],
            number    => $data_arr->[0]->[1],
        };
    }
    elsif ( $self->{segment_group} == 11 ) {    # ref to an address (SG12)
        $self->{addresses}->[-1]->{RFF} = {
            qualifier => $data_arr->[0]->[0],
            number    => $data_arr->[0]->[1],
        };

    }
    elsif ( $self->{segment_group} == 27 ) {    # ref to an address (SG12)
        $self->{lines}->[-1]->addsegment( 'item_reference', $data_arr );
    }
    else {
        push @{ $self->{reference} },
          {
            qualifier => $data_arr->[0]->[0],
            number    => $data_arr->[0]->[1],
          };
    }
    return;
}

=head2 handle_cux

=cut

sub handle_cux {
    my ( $self, $data_arr ) = @_;
    if ( $self->{segment_group} == 1 ) {

        $self->{currency}      = $data_arr->[0];
        $self->{segment_group} = 4;
    }
    elsif ( $self->{segment_group} == 11 ) {
        $self->{currency} = $data_arr->[0];
    }
    return;
}

=head2 handle_nad

=cut

sub handle_nad {
    my ( $self, $data_arr ) = @_;
    push @{ $self->{addresses} }, { NAD => $data_arr, };
    $self->{segment_group} = 11;
    return;
}

=head2 handle_lin

=cut

sub handle_lin {
    my ( $self, $data_arr ) = @_;
    $self->{segment_group} = 27;
    my $line = {
        line_number            => $data_arr->[0]->[0],
        action_req             => $data_arr->[1]->[0],
        item_number            => $data_arr->[2]->[0],
        item_number_type       => $data_arr->[2]->[1],
        additional_product_ids => [],
        item_description       => [],
        monetary_amount        => [],
    };
    if ( $data_arr->[3]->[0] ) {
        $line->{sub_line_info} = $data_arr->[3];
    }
    my $lineitem = Business::Edifact::Message::LineItem->new($line);

    push @{ $self->{lines} }, $lineitem;
    return;
}

=head2 handle_pia

=cut

sub handle_pia {
    my ( $self, $data_arr ) = @_;
    $self->{lines}->[-1]->addsegment( 'additional_product_ids', $data_arr );
    return;
}

=head2 handle_imd

=cut

sub handle_imd {
    my ( $self, $data_arr ) = @_;
    if ( $data_arr->[0]->[0] eq 'L' ) {    # only handle text at the moment
        if ( $data_arr->[2]->[4] ) {
            $data_arr->[2]->[3] .= $data_arr->[2]->[4];
        }
        $self->{lines}->[-1]->addsegment(
            'item_description',
            {
                code => $data_arr->[1]->[0],
                text => $data_arr->[2]->[3],
            }
        );
    }
    return;
}

=head2 handle_qty

=cut

sub handle_qty {
    my ( $self, $data_arr ) = @_;
    if ( !$self->{item_locqty_flag} ) {
        $self->{lines}->[-1]->{quantity} = $data_arr->[0]->[1];
    }
    else {
        $self->{lines}->[-1]->{place_of_delivery}->[-1]->{quantity} =
          $data_arr->[0]->[1];
        delete $self->{item_locqty_flag};
    }
    return;
}

=head2 handle_gir

=cut

sub handle_gir {
    my ( $self, $data_arr ) = @_;
    my $id = shift @{$data_arr};
    my $relnum = { id => $id->[0], };
    for my $d ( @{$data_arr} ) {
        push @{ $relnum->{ $d->[1] } }, $d->[0];
    }

    push @{ $self->{lines}->[-1]->{related_numbers} }, $relnum;
    return;
}

=head2 handle_moa

=cut

sub handle_moa {
    my ( $self, $data_arr ) = @_;
    if ( $self->{segment_group} == 27 ) {
        if ( !$self->{item_alc_flag} ) {
            my $data = shift @{$data_arr};
            my $ma   = {
                qualifier => $data->[0],
                value     => $data->[1],
            };

            push @{ $self->{lines}->[-1]->{monetary_amount} }, $ma;
        }
        else {
            $self->{lines}->[-1]->{item_allowance_or_charge}->[-1]->{amount} =
              $data_arr->[0]->[1];
        }
    }
    else {
        if ( !$self->{item_alc_flag} ) {
            my $data = shift @{$data_arr};
            my $ma   = {
                qualifier => $data->[0],
                value     => $data->[1],
            };
            push @{ $self->{monetary_amount} }, $ma;
        }
        else {
            my $data = shift @{$data_arr};
            my $ma   = {
                qualifier => $data->[0],
                value     => $data->[1],
            };
            push @{ $self->{allowance_or_charge}->[-1]->{amount} }, $ma;
            delete $self->{item_alc_flag};
        }
    }
    return;
}

=head2 handle_tax

=cut

sub handle_tax {
    my ( $self, $data_arr ) = @_;
    if ( $self->{segment_group} == 27 ) {
        if ( !$self->{item_alc_flag} ) {
            my $tax = {
                type_code     => $data_arr->[1]->[0],
                rate          => $data_arr->[4]->[3],
                category_code => $data_arr->[5]->[0],
            };
            push @{ $self->{lines}->[-1]->{item_tax} }, $tax;
        }
        else {
            my $tax = {
                type_code     => $data_arr->[1]->[0],
                rate          => $data_arr->[4]->[3],
                category_code => $data_arr->[5]->[0],
            };
            push @{ $self->{lines}->[-1]->{item_allowance_or_charge}->[-1]
                  ->{tax} }, $tax;
            delete $self->{item_alc_flag};
        }
    }
    else {
        my $tax = {
            type_code     => $data_arr->[1]->[0],
            rate          => $data_arr->[4]->[3],
            category_code => $data_arr->[5]->[0],
        };
        push @{ $self->{tax} }, $tax;
    }
    return;
}

=head2 handle_alc

=cut

sub handle_alc {
    my ( $self, $data_arr ) = @_;
    if ( $self->{segment_group} == 27 ) {
        my $alc = {
            type         => $data_arr->[0]->[0],
            sequence     => $data_arr->[3]->[0],
            service_code => $data_arr->[4]->[0],
        };
        push @{ $self->{lines}->[-1]->{item_allowance_or_charge} }, $alc;
        $self->{item_alc_flag} = 1;
    }
    else {
        my $alc = {
            type         => $data_arr->[0]->[0],
            sequence     => $data_arr->[3]->[0],
            service_code => $data_arr->[4]->[0],
        };
        push @{ $self->{allowance_or_charge} }, $alc;
        $self->{item_alc_flag} = 1;
    }
    return;
}

=head2 handle_rte

=cut

sub handle_rte {
    my ( $self, $data_arr ) = @_;
    if ( $self->{item_alc_flag} == 1 ) {
        $self->{lines}->[-1]->{item_allowance_or_charge}->[-1]->{rate} =
          $data_arr->[0]->[1];
        delete $self->{item_alc_flag};
    }
    return;
}

=head2 handle_loc

=cut

sub handle_loc {
    my ( $self, $data_arr ) = @_;
    if ( $self->{segment_group} == 27 && $data_arr->[0]->[0] == 7 ) {
        my $loc = {
            place     => $data_arr->[1]->[0],
            type_code => $data_arr->[1]->[2],
        };
        push @{ $self->{lines}->[-1]->{place_of_delivery} }, $loc;
        $self->{item_locqty_flag} = 1;
    }
    return;
}

=head2 handle_pri

=cut

sub handle_pri {
    my ( $self, $data_arr ) = @_;
    $self->{lines}->[-1]->{price} = {
        qualifier            => $data_arr->[0]->[0],
        price                => $data_arr->[0]->[1],
        price_type           => $data_arr->[0]->[2],
        price_type_qualifier => $data_arr->[0]->[3],
    };
    return;
}

=head2 handle_uns

=cut

sub handle_uns {
    my ( $self, $data_arr ) = @_;
    $self->{segment_group} = -1;    # summary does not have a seg group
    return;
}

=head2 handle_cnt

=cut

sub handle_cnt {
    my ( $self, $data_arr ) = @_;
    if ( $data_arr->[0]->[0] == 2 ) {
        $self->{summary_count} = $data_arr->[0]->[1];
    }
    return;
}

=head2 handle_ftx

=cut

sub handle_ftx {
    my ( $self, $data_arr ) = @_;
    $self->{lines}->[-1]->{free_text} = {
        qualifier => $data_arr->[0]->[0],    # LIN/LNO
        reference => $data_arr->[2],
    };
    if ( $data_arr->[3] ) {
        $self->{lines}->[-1]->{free_text}->{text} = join q{ },
          @{ $data_arr->[3] };
    }
    return;
}

=head1 AUTHOR

Colin Campbell, C<< <colinsc@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-edifact-interchange at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Business-Edifact-Interchange>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Business::Edifact::Message


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Colin Campbell.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
