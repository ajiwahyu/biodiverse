package Biodiverse::Metadata;
use strict;
use warnings;

our $VERSION = '0.99_002';

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    return $self;
}


1;