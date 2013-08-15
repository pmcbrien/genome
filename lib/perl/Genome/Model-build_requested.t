#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use strict;
use warnings;

use above "Genome";
use Test::More;

# Create test subclasses of model and processing profile that can be easily instantiated
class Genome::Model::Test {
    is => 'Genome::ModelDeprecated',
};

class Genome::ProcessingProfile::Test {
    is => 'Genome::ProcessingProfile',
};

# Make test sample, processing profile, and model
my $sample = Genome::Sample->create(
    name => 'dummy test sample',
);
ok($sample, 'created test sample with id ' . $sample->id) or die;

my $pp = Genome::ProcessingProfile::Test->create(
    name => 'dummy processing profile',
);
ok($pp, 'created test processing profile') or die;

my $model = Genome::Model::Test->create(
    subject_id => $sample->id,
    subject_class_name => $sample->class,
    processing_profile_id => $pp->id,
    name => 'test model',
);
ok($model, 'created test model') or die;

$model->build_requested(1);
is($model->build_requested, 1, 'build requested successfully set');
{
    my $count = count_notes(
        notes => [$model->notes],
        header_text => 'build_requested',
        body_text => 'no reason given',
    );
    is($count, 1, 'found expected note');
}

$model->build_requested(0);
is($model->build_requested, 0, 'unset build requested');
{
    my $count = count_notes(
        notes => [$model->notes],
        header_text => 'build_unrequested',
        body_text => 'no reason given',
    );
    is($count, 1, 'found expected note');
}

my $reason = 'test build';
$model->build_requested(1, $reason);
is($model->build_requested, 1, 'set build requested with reason provided');
{
    my $count = count_notes(
        notes => [$model->notes],
        header_text => 'build_requested',
        body_text => $reason,
    );
    is($count, 1, 'found expected note');
}

done_testing();

sub count_notes {
   my %args = Params::Validate::validate(
       @_, { notes => 1, header_text => 1, body_text => 1 },
   );

   my $count = 0;
   for my $n (@{$args{notes}}) {
        if ($n->header_text eq $args{header_text}
            && $n->body_text eq $args{body_text}
        ) {
            $count++;
        } else {
            diag $n->header_text, "\n", $n->body_text, "\n";
        }
   }

   return $count;
}
