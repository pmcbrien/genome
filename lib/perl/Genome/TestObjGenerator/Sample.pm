package Genome::TestObjGenerator::Sample;
use base qw(Genome::TestObjGenerator::Base);

use strict;
use warnings;
use Genome;

our @required_params = qw(name);

sub generate_obj {
    my $self = shift;
    return Genome::Sample->create(@_);
}

sub create_name {
    return Genome::TestObjGenerator::Util::generate_name('sample_name');
}

1;
