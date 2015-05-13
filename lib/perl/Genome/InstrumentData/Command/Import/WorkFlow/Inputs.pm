package Genome::InstrumentData::Command::Import::WorkFlow::Inputs;

use strict;
use warnings;

use Genome;

use Genome::InstrumentData::Command::Import::WorkFlow::SourceFiles;

class Genome::InstrumentData::Command::Import::WorkFlow::Inputs { 
    is => 'UR::Object',
    has => {
        analysis_project => { is => 'Genome::Config::AnalysisProject', },
        library => { is => 'Genome::Library', },
        instrument_data_properties => { is => 'HASH', },
        source_files => { is => 'Genome::InstrumentData::Command::Import::WorkFlow::SourceFiles', },
    },
    has_transient => {
        format => { via => 'source_files', to => 'format', },
        library_name => { via => 'library', to => 'name', },
        sample_name => { via => 'library', to => 'sample_name', },
    },
};

sub create {
    my ($class, %params) = @_;

    my $self = $class->SUPER::create(%params);
    return if not $self;

    for my $requried (qw/ analysis_project library source_files /) {
        die $self->error_message("No $requried given to work flow inputs!") if not $self->$requried;
    }

    $self->source_files(
        Genome::InstrumentData::Command::Import::WorkFlow::SourceFiles->create(paths => $self->source_files) 
    );
    $self->_resolve_instrument_data_properties;

    return $self;
}

sub _resolve_instrument_data_properties {
    my $self = shift;

    my $incoming_properties = $self->instrument_data_properties || [];
    my %properties;
    return \%properties if not $incoming_properties and not @$incoming_properties;

    for my $key_value_pair ( @$incoming_properties ) {
        my ($label, $value) = split('=', $key_value_pair);
        if ( not defined $value or $value eq '' ) {
            die $self->error_message('Failed to parse with instrument data property label/value! '.$key_value_pair);
        }
        if ( exists $properties{$label} and $value ne $properties{$label} ) {
            die $self->error_message(
                "Multiple values for instrument data property! $label => ".join(', ', sort $value, $properties{$label})
            );
        }
        $properties{$label} = $value;
    
    }

    if ( not $properties{original_data_path} ) {
        $properties{original_data_path} = join(',', $self->source_files->paths);
    }

    $self->instrument_data_properties(\%properties);
    return 1;
}

sub instrument_data_for_original_data_path {
    my $self = shift;
    my @odp_attrs = Genome::InstrumentDataAttribute->get(
        attribute_label => 'original_data_path',
        attribute_value => $self->source_files->original_data_path,
    );
    return if not @odp_attrs;
    return map { $_->instrument_data } @odp_attrs;
}

sub as_hashref {
    my $self = shift;

    my %hash = map { $_ => $self->$_ } (qw/
        analysis_project instrument_data_properties library library_name sample_name
        /);
    $hash{downsample_ratio} = $self->instrument_data_properties->{downsample_ratio};
    $hash{source_paths} = [ $self->source_files->paths ];

    return \%hash;
}

1;

