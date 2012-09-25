#!/usr/bin/env genome-perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above "Genome";

use Test::More;

use_ok('Genome::Model::Tools::Vcf::Convert::Snv::Strelka') or die;

my $test_dir = $ENV{GENOME_TEST_INPUTS} . "/Genome-Model-Tools-Vcf-Convert-Snv-Strelka";
my $input_file    = $test_dir . '/snvs.hq';
my $expected_file = $test_dir . '/expected.v1/snvs.vcf.gz';
my $output_file   = Genome::Sys->create_temp_file_path;

my $command = Genome::Model::Tools::Vcf::Convert::Snv::Strelka->create(
    input_file                   => $input_file, 
    output_file                  => $output_file,
    aligned_reads_sample         => "TUMOR_SAMPLE_123",
    control_aligned_reads_sample => "CONTROL_SAMPLE_123",
    reference_sequence_build_id  => 101947881,
);

ok($command, 'Command created');
my $rv = $command->execute;
ok($rv, 'Command completed successfully');
ok(-s $output_file, "output file created");

# The files will have a timestamp that will differ. Ignore this but check the rest.
my $expected = `zcat $expected_file | grep -v fileDate`;
my $output   = `zcat $output_file   | grep -v fileDate`;
my $diff = Genome::Sys->diff_text_vs_text($output, $expected);
ok(!$diff, 'output matched expected result')
    or diag("diff results:\n" . $diff);

done_testing();

1;
