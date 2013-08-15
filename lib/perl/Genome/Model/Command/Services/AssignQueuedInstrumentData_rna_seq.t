#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use above 'Genome';

use Test::More;
use Genome::Utility::Test qw(is_equal_set);

use_ok('Genome::Model::Command::Services::AssignQueuedInstrumentData') or die;

# Reasearch Project
my @projects;
push @projects, Genome::Project->create(id => -111, name => '__TEST_PROJECT__');
ok($projects[0], 'create project for research project');
# 'GSC WorkOrder'
my $gsc_workorder = Genome::Site::TGI::Synchronize::Classes::SetupProject->__define__(id => -222, name => '__TEST_WORKORDER__', pipeline => 'rna');
push @projects, Genome::Project->create(id => -222, name => '__TEST_WORKORDER__');
ok($projects[1], 'create project for research project');
# Model groups for projects
my @model_groups = Genome::ModelGroup->get(uuid => [ map { $_->id } @projects ]);
is(@model_groups, @projects, 'created model groups');

my ($sample, @instrument_data) = _create_inst_data();
no warnings;
*Genome::InstrumentDataAttribute::get = sub {
    my ($class, %params) = @_;
    my %attrs = map { $_->id => $_ } map { $_->attributes } @instrument_data;
    for my $param_key ( keys %params ) {
        my @param_values = ( ref $params{$param_key} ? @{$params{$param_key}} : $params{$param_key} );
        my @unmatched_attrs;
        for my $attr ( values %attrs ) {
            next if grep { $attr->$param_key eq $_ } @param_values;
            push @unmatched_attrs, $attr->id;
        }
        for ( @unmatched_attrs ) { delete $attrs{$_} }
    }
    return values %attrs;
};
#sub GSC::Setup::WorkOrder::get { return $gsc_workorder; }
use warnings;

$instrument_data[0]->add_attribute(attribute_label => 'tgi_lims_status', attribute_value => 'new');
$instrument_data[1]->add_attribute(attribute_label => 'tgi_lims_status', attribute_value => 'new');

my $cmd = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
ok($cmd, 'create aqid');
ok($cmd->execute, 'execute');
my @new_models = values %{$cmd->_newly_created_models};
my @new_model_ids = map { $_->id } @new_models;
my %new_models = _model_hash(@new_models);
my @existing_models = values %{$cmd->_existing_models_assigned_to};
my %existing_models = _model_hash(@existing_models);
#print Data::Dumper::Dumper(\%new_models,\%existing_models);
my $default_processing_profile_id = Genome::Model::Command::Services::AssignQueuedInstrumentData->_default_rna_seq_processing_profile_id;
is_deeply(
    \%new_models,
    {
        "__TEST_SAMPLE__.prod-rna_seq" => {
            subject => $sample->name,
            processing_profile_id => $default_processing_profile_id,
            reference_sequence_build_id => 106942997,
            inst => [ $instrument_data[1]->id, ],
            auto_assign_inst_data => 0,
        },
    },
    'new models for run 1',
);
is_deeply(
    \%existing_models, 
    {}, 
    'existing models for run 1',
);
ok( # skipped instdata[0]
    eval{ $instrument_data[0]->attributes(attribute_label => 'tgi_lims_status')->attribute_value  eq 'skipped' },
    'set tgi_lims_status to skipped for 454 instrument data',
);
ok( # processed instdata[1]
    eval{ $instrument_data[1]->attributes(attribute_label => 'tgi_lims_status')->attribute_value  eq 'processed' },
    'set tgi_lims_status to processed for solexa instrument data #1',
);

# process another solexa...
$instrument_data[2]->add_attribute(attribute_label => 'tgi_lims_status', attribute_value => 'new');
$cmd = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
ok($cmd, 'create aqid');
ok($cmd->execute, 'execute');
@new_models = values %{$cmd->_newly_created_models};
push @new_model_ids, map { $_->id } @new_models;
%new_models = _model_hash(@new_models);
@existing_models = values %{$cmd->_existing_models_assigned_to};
%existing_models = _model_hash(@existing_models);
#print Data::Dumper::Dumper(\%new_models,\%existing_models);
is_deeply(
    \%new_models,
    {
        "__TEST_SAMPLE__.prod-rna_seq-1" => {
            subject => $sample->name,
            processing_profile_id => $default_processing_profile_id,
            reference_sequence_build_id => 106942997,
            inst => [ $instrument_data[2]->id ],
            auto_assign_inst_data => 0,
        },
    },
    'new models for run 1',
);
is_deeply(
    \%existing_models, 
    {},
    'existing models for run 1',
);
ok( # processed instdata[2]
    eval{ $instrument_data[2]->attributes(attribute_label => 'tgi_lims_status')->attribute_value  eq 'processed' },
    'set tgi_lims_status to processed for solexa instrument data #2',
);

# Did the models get added to the projects?
for my $project ( @projects ) {
    is_equal_set(
        [@new_model_ids],
        [map { $_->entity_id } grep { $_->entity_class_name =~ /^Genome::Model/ } $project->parts],
        'added models to project ' . $project->name,
    );
}

done_testing();

###

sub _create_inst_data {
    my $source = Genome::Individual->__define__(name => '__TEST_IND__', taxon => Genome::Taxon->__define__(name => 'human', species_latin_name => 'homo sapiens'));
    ok($source, 'source');

    $sample = Genome::Sample->create(
        name => '__TEST_SAMPLE__',
        source => $source,
        extraction_type => 'rna',
        common_name => 'normal',
    );
    ok($sample, 'sample');

    my $library = Genome::Library->create(
        name => $sample->name.'-testlib',
        sample_id => $sample->id,
    );
    ok($library, 'library');

    push @instrument_data, Genome::InstrumentData::454->create(
        library => $library,
        run_name => 'R_2011_07_27_14_54_40_FLX08080419_Administrator_113684816',
        region_number => 1,
        read_count => 100,
    );
    is(@instrument_data, 1, 'create instrument data');

    push @instrument_data, Genome::InstrumentData::Solexa->create(
        library => $library,
        lane => '1',
        index_sequence => 'AAAAAA',
        subset_name => '1-AAAAAA',
        run_type => 'Paired',
        fwd_read_length => 100,
        rev_read_length => 100,
        fwd_clusters => 100,
        rev_clusters => 100,
    );
    is(@instrument_data, 2, 'create instrument data');

    push @instrument_data, Genome::InstrumentData::Solexa->create(
        library => $library,
        lane => '1',
        index_sequence => 'TTTTTT',
        subset_name => '1-TTTTTT',
        run_type => 'Paired',
        fwd_read_length => 100,
        rev_read_length => 100,
        fwd_clusters => 100,
        rev_clusters => 100,
    );
    is(@instrument_data, 3, 'create instrument data');

    for my $instrument_data ( @instrument_data ) {
        for my $project ( @projects ) {
            $project->add_part( entity_id => $instrument_data->id, entity_class_name => 'Genome::InstrumentData', label => 'instrument_data');
        }
    }

    return ($sample, @instrument_data);
}

sub _model_hash {
    return map { 
        $_->name => { 
            subject => $_->subject_name, 
            processing_profile_id => $_->processing_profile_id,
            reference_sequence_build_id => eval{ $_->reference_sequence_build_id },
            inst => [ map { $_->id } $_->instrument_data ],
                auto_assign_inst_data => $_->auto_assign_inst_data,
            }
        } @_;
    }
