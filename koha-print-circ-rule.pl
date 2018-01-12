#! /usr/bin/perl

use strict;
use warnings;

use C4::Circulation;
use C4::Items;
use C4::Members;
use C4::Biblio;
use Getopt::Long;
use Data::Dumper;
use C4::Context;
use List::Util qw( any pairgrep );

sub header {
    my $string = "@_";
    my $underline = '=' x length( $string );
    return   "\n"
           . "${string}\n"
           . "${underline}\n";
}


my $fields_to_pull = {
      borrower         => [ qw( categorycode borrowernumber branchcode description 
                                dateenrolled dateexpiry firstname surname 
                                dateofbirth debarred userid ) ]
    , item             => [ qw( itemlost withdrawn restricted notforloan 
                                itemnumber ccode itemcallnumber datelastseen 
                                homebranch holdingbranch timestamp 
                                damaged itype onloan ) ]
    , issueing_rules   => [ qw( issuelength lengthunit renewalperiod ) ]
    , branch_item_rule => [ qw( returnbranch holdallowed  ) ]
};

my $opt_borrower_card_num;
my $opt_item_barcode;

GetOptions(
      "cardnumber=s"   => \$opt_borrower_card_num
    , "barcode=s"      => \$opt_item_barcode
);

my $item           = GetItem( GetItemnumberFromBarcode( $opt_item_barcode ) );
my $borrower       = C4::Members::GetMember( cardnumber =>  $opt_borrower_card_num );
my $branch         = C4::Circulation::_GetCircControlBranch( $item, $borrower );
my $borrowertype   = $borrower->{categorycode};
my $biblioitem     = GetBiblioItemData( $item->{biblioitemnumber} );
my $itemtype       = ( C4::Context->preference( 'item-level_itypes' ) ) ? $item->{'itype'} : $biblioitem->{'itemtype'};
my $loanlength     = C4::Circulation::GetLoanLength( $borrowertype, $itemtype, $branch );
my $branchitemrule = C4::Circulation::GetBranchItemRule( $branch, $item->{'itype'} );
my $irule          = Koha::IssuingRules->get_effective_issuing_rule(
                         {
                             categorycode => $borrowertype,
                             itemtype     => $itemtype,
                             branchcode   => $branch
                         }
                     );

my $bci            = [ "branch => $irule->{branchcode}",
                       "category => $irule->{categorycode}",
                       "itemtype => $irule->{itemtype}" 
                     ];

( %$borrower ) = pairgrep { any { $_ eq $a } @{$fields_to_pull->{borrower}}  } ( %$borrower );
( %$item )     = pairgrep { any { $_ eq $a } @{$fields_to_pull->{item}}  } ( %$item );
#( %$irule )     = pairgrep { any { $_ eq $a } @{$fields_to_pull->{issueing_rules}}  } ( %$irule );

my @fields = (
      [ 'Rule Branch/Category/Itype' => $bci                ]
    , [ 'Circulation Branch'         => $branch             ]
    , [ 'Item type'                  => $itemtype           ]
    , [ 'Issuing Rule'               => $irule              ]
    , [ 'Branch Item Rule'           => $branchitemrule     ]
    , [ 'Borrower'                   => $borrower           ]
    , [ 'Item'                       => $item               ]
    , [ 'Loan Length'                => $loanlength         ]
);

for my $field ( @fields ) {
    my ( $header, $value ) = @$field;
    print header( $header );
    print Dumper( $value );
}
