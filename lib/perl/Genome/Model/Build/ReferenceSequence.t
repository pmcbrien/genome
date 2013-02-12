#!/usr/bin/env genome-perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';
use Test::More;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}else {
    plan tests => 5;
}

use_ok("Genome::Model::Build::ReferenceSequence");

my $data_dir = File::Temp::tempdir('ImportedAnnotationTest-XXXXX', CLEANUP => 1, TMPDIR => 1);
my $pp = Genome::ProcessingProfile::ImportedReferenceSequence->create(name => 'test_ref_pp');
my $taxon = Genome::Taxon->get(name => 'human');
my $patient = Genome::Individual->create(name => "test-patient", common_name => 'testpat', taxon => $taxon);
my $sample = Genome::Sample->create(name => "test-patient", common_name => 'tumor', source => $patient);
ok($sample, 'created sample');

my $sequence_uri = "http://genome.wustl.edu/foo/bar/test.fa.gz";

my $fasta_file1 = "$data_dir/data.fa";
my $fasta_fh = new IO::File(">$fasta_file1");
$fasta_fh->write(">HI\nNACTGACTGNNACTGN\n");
$fasta_fh->close();

my $command = Genome::Model::Command::Define::ImportedReferenceSequence->create(
    fasta_file => $fasta_file1,
    model_name => 'test-ref-seq-1',
    processing_profile => $pp,
    species_name => 'human',
    subject => $sample,
    version => 42,
    sequence_uri => $sequence_uri
);

ok($command, 'created command');

ok($command->execute(), 'executed command');

my $build_id = $command->result_build_id;

my $build = Genome::Model::Build->get($build_id);

my $path = $build->get_sequence_dictionary('sam','human','1.29');

ok(-e $path, 'get sequence dictionary returned valid path');
