#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;
}

use strict;
use warnings;

use above 'Genome';
use Genome::Test::Factory::SoftwareResult::User;

use File::Path;
use Test::More;

my $arch_os = Genome::Config->arch_os;
if ($arch_os =~ /x86_64/) {
    plan tests => 18;
} else {
    plan skip_all => 'Must run on a 64 bit machine';
}

use_ok('Genome::InstrumentData::AlignmentResult::Bwa') or die;
use_ok('Genome::InstrumentData::Solexa');

# Inst data
my $instrument_data = Genome::InstrumentData::Solexa->create(
    id => -123456,
    library => Genome::Library->create(
        name => 'test_sample_name-lib1',
        sample => Genome::Sample->create(name => 'test_sample_name'),
    ),
    flow_cell_id => '12345',
    lane => '1',
    old_median_insert_size => '22',
    run_name => '110101_TEST',
    subset_name => 4,
    run_type => 'Paired',
    bam_path => $ENV{GENOME_TEST_INPUTS} . '/Genome-InstrumentData-Align-Bwa/input_rg.bam',
     # expected outputs are here, too
);
ok($instrument_data, 'create instrument data: '.$instrument_data->id);
ok($instrument_data->is_paired_end, 'instrument data is paired end');

# Result parameters
my %result_params = (
    instrument_data_id => $instrument_data->id,
    reference_build => Genome::Model::ImportedReferenceSequence->get(name => 'TEST-human')->build_by_version('1'),
    samtools_version => Genome::Model::Tools::Sam->default_samtools_version,
    picard_version => Genome::Model::Tools::Picard->default_picard_version,
    aligner_version => '0.5.9',
    aligner_name => 'bwa',
);

my $result_users = Genome::Test::Factory::SoftwareResult::User->setup_user_hash(
    reference_sequence_build => $result_params{reference_build},
);

# ALIGN!
my $alignment = Genome::InstrumentData::AlignmentResult->create(
    %result_params,
    _user_data_for_nested_results => $result_users
);
ok($alignment, "created alignment");
isa_ok($alignment, 'Genome::InstrumentData::AlignmentResult::Bwa');
my $bam_path = $alignment->output_dir."/all_sequences.bam";
ok(-s $bam_path, "created a bam");
my $generated_bam_md5 = Genome::Sys->md5sum($bam_path);
is($generated_bam_md5, 'a15544d06deeda14506ac9beb8af78d1', "MD5 of bam matches");

# FIXME test if the iar are deleted? if not we is done

my @users = Genome::SoftwareResult::User->get(user => $alignment, label => 'intermediate result');
ok(!@users, 'alignment is not using any intermediate results');

# RECREATE FAIL
my $recreate = Genome::InstrumentData::AlignmentResult->create(
    %result_params,
    _user_data_for_nested_results => $result_users,
);
ok(!$recreate, "Did not recreate the alignment result");
like(Genome::InstrumentData::AlignmentResult::Bwa->error_message, qr/already have one/, "correct error");

# GET WITH LOCK OK
my $get_with_lock = Genome::InstrumentData::AlignmentResult->get_with_lock(
    %result_params,
    users => $result_users
);
ok($get_with_lock, 'Re-get with lock');
is($get_with_lock, $alignment, 'Got the same alignment');

# Clear tmp dir
for ( glob( Genome::Sys->base_temp_directory."/*") ) {
    File::Path::rmtree($_);
}

# ALIGN BY READ GROUP - not sure why this is tested here
$result_params{instrument_data_segment_id} = 'Z';
$result_params{instrument_data_segment_type} = 'read_group';
$alignment = Genome::InstrumentData::AlignmentResult->create(
    %result_params,
    _user_data_for_nested_results => $result_users,
);
ok($alignment, "created alignment");
isa_ok($alignment, 'Genome::InstrumentData::AlignmentResult::Bwa');
$bam_path = $alignment->output_dir."/all_sequences.bam";
ok(-s $bam_path, "created a bam");
$generated_bam_md5 = Genome::Sys->md5sum($bam_path);
is($generated_bam_md5, '2ea7b6431d9e9cb7e33207ecf7438d3e', "MD5 of bam matches");
@users = Genome::SoftwareResult::User->get(user => $alignment, label => 'intermediate result');
ok(!@users, 'alignment is not using any intermediate results');

done_testing();
