#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use File::Path;
use File::Temp;
use Test::More;
use above 'Genome';
use Genome::SoftwareResult;
use Genome::Utility::Test qw(compare_ok);

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from a 64-bit machine";
}

use_ok('Genome::Model::Tools::Mutect::ParallelWrapper');

my $tumor =  Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Mutect-Parallel-Wrapper/tiny.tumor.bam";
my $normal = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Mutect-Parallel-Wrapper/tiny.normal.bam";
my $expected_out = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Mutect-Parallel-Wrapper/expected.v2.out"; #updating for v1.1.4
my $expected_vcf = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Mutect-Parallel-Wrapper/expected.vcf";

#Define path to a custom reference sequence build dir
my $custom_reference_dir = Genome::Config::get('test_inputs') . "/Genome-Model-Tools-Mutect-Parallel-Wrapper/custom_reference";
ok(-e $custom_reference_dir, "Found the custom reference dir: $custom_reference_dir");

my $fasta = Genome::File::Fasta->create(id => "$custom_reference_dir/all_sequences.fa");

my $test_base_dir = File::Temp::tempdir('MutectXXXXX', CLEANUP => 1, TMPDIR => 1);
my $wrapper = Genome::Model::Tools::Mutect::ParallelWrapper->create(tumor_bam=>$tumor, 
                                                                    normal_bam=>$normal,
                                                                    chunk_num => 5,
                                                                    total_chunks => 5,
                                                                    fasta_object => $fasta,
                                                                    reference => $fasta->path,
                                                                    basename => "$test_base_dir/test",
                                                                   );
ok($wrapper, 'parallel wrapper command created');
my $rv = $wrapper->execute;
is($rv, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$rv);

my $out_file = "$test_base_dir/test_5.out";
my $vcf_file = "$test_base_dir/test_5.vcf";

ok(-s $out_file, "output file created");
ok(-s $vcf_file, "vcf file created");

compare_ok($expected_out, $out_file, name => 'output matched expected result', filters => [ qr/^##.*$/ ] );
compare_ok($expected_vcf, $vcf_file, name => 'vcf matched expected result', filters => [ qr/^##MuTect.*$/, qr/^##reference.*$/ ] );

done_testing();
