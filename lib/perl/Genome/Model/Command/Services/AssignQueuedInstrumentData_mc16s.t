#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use above 'Genome';

use Data::Dumper;
use Test::MockObject;
use Test::More;

use_ok('Genome::Model::Command::Services::AssignQueuedInstrumentData') or die;

my ($cnt, @samples, @instrument_data);

# Reasearch Project
my @projects;
push @projects, Genome::Project->create(id => -111, name => '__TEST_PROJECT__');
ok($projects[0], 'create project for research project');
# GSC WorkOrder
my $gsc_workorder = Test::MockObject->new();
$gsc_workorder->set_always(pipeline => '16S 454');
push @projects, Genome::Project->create(id => -222, name => '__TEST_WORKORDER__');
ok($projects[1], 'create project for research project');
# Model groups for projects
my @model_groups = Genome::ModelGroup->get(uuid => [ map { $_->id } @projects ]);
is(@model_groups, @projects, 'created model groups');

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
sub GSC::Setup::WorkOrder::get { return $gsc_workorder; }
use warnings;

for my $i (1..2) {
    ok(_create_inst_data(), 'create inst data');
}
is(@instrument_data, $cnt, "create $cnt inst data");

my $cmd = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
ok($cmd, 'create aqid');
$cmd->dump_status_messages(1);
ok($cmd->execute, 'execute');
my @new_models = values %{$cmd->_newly_created_models};
my %new_models = _model_hash(@new_models);
my @existing_models = values %{$cmd->_existing_models_assigned_to};
my %existing_models = _model_hash(@existing_models);
#print Dumper(\%new_models,\%existing_models);
my $model_name_for_entire_run = "R_2011_07_27_14_54_40_FLX08080419_Administrator_113684816_r1.prod-mc16s-qc";
my @default_processing_profile_ids = Genome::Model::MetagenomicComposition16s->default_processing_profile_ids;
is_deeply(
    \%new_models,
    {
        "AQID-testsample1.prod-mc16s.rdp2-2" => {
            subject => $samples[0]->name,
            processing_profile_id => $default_processing_profile_ids[0],
            inst => [ $instrument_data[0]->id ],
            auto_assign_inst_data => 1,
        },
        "AQID-testsample2.prod-mc16s.rdp2-2" => {
            subject => $samples[1]->name,
            processing_profile_id => $default_processing_profile_ids[0],
            inst => [ $instrument_data[1]->id ],
            auto_assign_inst_data => 1,
        },
        "AQID-testsample1.prod-mc16s.rdp2-5" => {
            subject => $samples[0]->name,
            processing_profile_id => $default_processing_profile_ids[1],
            inst => [ $instrument_data[0]->id ],
            auto_assign_inst_data => 1,
        },
        "AQID-testsample2.prod-mc16s.rdp2-5" => {
            subject => $samples[1]->name,
            processing_profile_id => $default_processing_profile_ids[1],
            inst => [ $instrument_data[1]->id ],
            auto_assign_inst_data => 1,
        },
        $model_name_for_entire_run => {
            subject => "Human Metagenome",
            processing_profile_id => $default_processing_profile_ids[0],
            inst => [ map { $_->id } @instrument_data ],
            auto_assign_inst_data => 0,
        },
    },
    'new models for run 1',
);
is_deeply(
    \%existing_models, 
    { $model_name_for_entire_run => $new_models{$model_name_for_entire_run} },
    'existing models for run 1',
);

ok(_create_inst_data(), 'made another qdidfgm');
ok(_create_inst_data(sample_name => 'n-ctrl'), 'create inst data for negative control'); # negative control sample
ok(_create_inst_data(read_count => 0), 'create inst data w/ read count 0'); # read count 0 inst data
is(@instrument_data, $cnt, "$cnt inst data");

$cmd = Genome::Model::Command::Services::AssignQueuedInstrumentData->create;
ok($cmd, 'create aqid');
$cmd->dump_status_messages(1);
ok($cmd->execute, 'execute');
@new_models = values %{$cmd->_newly_created_models};
%new_models = _model_hash(@new_models);
@existing_models = values %{$cmd->_existing_models_assigned_to};
%existing_models = _model_hash(@existing_models);
#print Dumper(\%new_models,\%existing_models);
is_deeply(
    \%new_models,
    {
        "AQID-testsample3.prod-mc16s.rdp2-2" => {
            subject => $samples[2]->name,
            processing_profile_id => $default_processing_profile_ids[0],
            processing_profile_id => Genome::Model::MetagenomicComposition16s->default_processing_profile_id,
            inst => [ $instrument_data[2]->id ],
            auto_assign_inst_data => 1,
        },
        "AQID-testsample3.prod-mc16s.rdp2-5" => {
            subject => $samples[2]->name,
            processing_profile_id => $default_processing_profile_ids[1],
            inst => [ $instrument_data[2]->id ],
            auto_assign_inst_data => 1,
        },
    },
    'new models for run 2',
);
is_deeply(
    \%existing_models,
    {
        $model_name_for_entire_run => {
            subject => "Human Metagenome",
            processing_profile_id => Genome::Model::MetagenomicComposition16s->default_processing_profile_id,
            inst => [ map { $_->id } grep { $_->sample_name ne 'n-ctrl' } @instrument_data ],
            auto_assign_inst_data => 0,
        },
    },
    'existing models for run 2',
);
is( # processed all
    scalar(grep { $_->attributes(attribute_label => 'tgi_lims_status')->attribute_value  eq 'processed' } @instrument_data),
    5,
    'set tgi lims status to processed for all instrument data',
);
is( # ignored 2
    scalar(grep { $_->ignored } @instrument_data),
    2,
    'ignored 2 instrument data',
);

done_testing();
exit;

my $source;
my $sample_cnt = 0;
sub _create_inst_data {
    my %incoming_params = @_;
    $cnt++;

    $source = Genome::PopulationGroup->__define__(name => '__TEST_POP_GROUP__', taxon => Genome::Taxon->__define__(name => 'Human Metagenome')) if not $source;
    ok($source, 'define source');

    my $sample_name = ( exists $incoming_params{sample_name} ? delete $incoming_params{sample_name} : 'AQID-testsample'.++$sample_cnt );
    my $sample = Genome::Sample->create(
        name => $sample_name,
        extraction_type => 'genomic',
        source => $source,
    );
    ok($sample, 'sample '.$sample_cnt);
    push @samples, $sample;
    my $library = Genome::Library->create(
        name => $sample->name.'-testlib',
        sample_id => $sample->id,
    );
    ok($library, 'create library '.$cnt);

    my $instrument_data = Genome::InstrumentData::454->create(
        library_id => $library->id,
        run_name => 'R_2011_07_27_14_54_40_FLX08080419_Administrator_113684816',
        region_number => 1,
        read_count => ( exists $incoming_params{read_count} ? delete $incoming_params{read_count} : 1 ),
    );
    ok($instrument_data, 'created instrument data '.$cnt);
    $instrument_data->add_attribute(
        attribute_label => 'tgi_lims_status',
        attribute_value => 'new',
    );
    push @instrument_data, $instrument_data;
    for my $project ( @projects ) {
        $project->add_part(
            entity_id => $instrument_data->id,
            entity_class_name => 'Genome::InstrumentData',
            label => 'instrument_data',
        );
    }

    return 1;
}

sub _model_hash {
    return map { 
        $_->name => { 
            subject => $_->subject_name, 
            processing_profile_id => $_->processing_profile_id,
            inst => [ map { $_->id } $_->instrument_data ],
            auto_assign_inst_data => $_->auto_assign_inst_data,
        }
    } @_;
}

