#!/usr/bin/env genome-perl
use strict;
use warnings;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use above "Genome";
use Test::More tests => 22;

use Genome::Test::Factory::Build;
use Genome::Test::Factory::InstrumentData::Solexa;
use Genome::Test::Factory::Model::ReferenceAlignment;

#All models and builds in this test use the same data directory
#It is intended that nothing actually writes to it--this should just be to prevent allocations
my $test_data_dir = File::Temp::tempdir('Genome-Model-Convergence-XXXXX', CLEANUP => 1, TMPDIR => 1);

use_ok('Genome::Model::Convergence');

my $model_group = Genome::ModelGroup->create(
  id => -12345,
  name => 'Testsuite_ModelGroup',
);

ok($model_group, 'Got a modelgroup');
ok(!$model_group->convergence_model, 'Did not auto-generate a convergence model');

generate_convergence_model($model_group);

my $convergence_model = $model_group->convergence_model;
ok($convergence_model, 'Generated associated Convergence model');
isa_ok($convergence_model, 'Genome::Model::Convergence');

$convergence_model->auto_build_alignments(0);
ok(! $convergence_model->auto_build_alignments, 'Alignment auto-build disabled');

my ($test_model, $test_model_two) = setup_test_models();

my $add_command = Genome::ModelGroup::Command::Member::Add->create(
    model_group=> $model_group,
    models => [ $test_model, $test_model_two ],
);

ok($add_command, 'created member add command');
ok($add_command->execute(), 'executed member add command');

my @builds = $convergence_model->builds;
is(scalar @builds, 0, 'did not launch auto-build');

my $convergence_build = Genome::Model::Build::Convergence->create(
    model_id => $convergence_model->id,
    data_directory => $test_data_dir,
);

ok($convergence_build, 'created convergence build');
isa_ok($convergence_build, 'Genome::Model::Build::Convergence');

my @members = $convergence_build->members;
is(scalar @members, 1, 'build has one member');
is($members[0]->status, 'Succeeded', 'that member is the succeeded build');

# Create some test models with builds and all of their prerequisites
sub setup_test_models {
    my $test_instrument_data = Genome::Test::Factory::InstrumentData::Solexa->setup_object();
    ok($test_instrument_data, 'created test instrument data');

    my $test_model = Genome::Test::Factory::Model::ReferenceAlignment->setup_object();
    ok($test_model, 'created test model');

    my $test_input = $test_model->add_instrument_data($test_instrument_data);
    ok($test_input, 'assigned data to model');

    my $test_build = Genome::Test::Factory::Build->setup_object(
        model_id => $test_model->id,
        data_directory => $test_data_dir,
    );
    ok($test_build, 'created test build');

    $test_build->_verify_build_is_not_abandoned_and_set_status_to('Succeeded', 1);

    is_deeply($test_model->last_complete_build, $test_build, 'last succeeded build is the test build');

    my $test_model_two = Genome::Test::Factory::Model::ReferenceAlignment->setup_object(
        processing_profile_id => $test_model->processing_profile->id,
        reference_sequence_build => $test_model->reference_sequence_build,
    );
    ok($test_model_two, 'created second test model');

    my $test_input_two = $test_model_two->add_instrument_data($test_instrument_data);
    ok($test_input_two, 'assigned data to second model');

    my $test_build_two = Genome::Test::Factory::Build->setup_object(
        model_id => $test_model_two->id,
        data_directory => $test_data_dir,
    );
    ok($test_build_two, 'created second test build');

    return ($test_model, $test_model_two);
}

sub generate_convergence_model {
    my $model_group = shift;
    my $cmd = Genome::Model::Command::Define::Convergence->create(
        model_group_id => $model_group->id,
    );
    ok($cmd->execute, 'Generated convergence model for model group');
}
