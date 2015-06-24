#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::More tests => 7;
use Genome::Utility::Test;

my $expected_out = Genome::Utility::Test->data_dir_ok(
    'Genome::Model::ClinSeq::Command::Converge::SnvIndelReport', '2015-05-05');
ok(-d $expected_out, "directory of expected output exists: $expected_out") or die;

my $clinseq_build_id = 'a2eb4f40a47a4dc5ac410c81b3d2fc17';
my $clinseq_build = Genome::Model::Build->get($clinseq_build_id);
ok($clinseq_build, "Got clinseq build from id: $clinseq_build_id") or die;
my @builds = ($clinseq_build);

#Create a temp dir for results
my $temp_dir = Genome::Sys->create_temp_directory();
ok($temp_dir, "created temp directory: $temp_dir");

my $cmd = Genome::Model::ClinSeq::Command::Converge::SnvIndelReport->create(
    builds => \@builds, 
    outdir => $temp_dir,
    tmp_space => 1,
    summarize => 1,
    test => 10,
    chromosome => '1',
    tiers => 'tier3',
    bam_readcount_version => 0.6,
    bq => 0,
    mq => 1,
);
$cmd->queue_status_messages(1);
my $r1 = $cmd->execute();
is($r1, 1, 'Testing for successful execution.  Expecting 1.  Got: '.$r1);

#Dump the output to a log file
my @output = $cmd->status_messages();
my $log_file = $temp_dir . "/SnvIndelReport.log.txt";
my $log = IO::File->new(">$log_file");
$log->print(join("\n", @output));
ok(-e $log_file, "Wrote message file from snv-indel-report to a log file: $log_file");

#The first time we run this we will need to save our initial result to diff against
#Genome::Sys->shellcmd(cmd => "cp -r -L $temp_dir/* $expected_out");

#Perform a diff between the stored results and those generated by this test
my @diff = `diff -r -x '*.log.txt' -x '*.xls' $expected_out $temp_dir`;
ok(@diff == 0, "Found only expected number of differences between expected results and test results")
or do {
  diag("expected: $expected_out\nactual: $temp_dir\n");
  diag("differences are:");
  diag(@diff);
  my $diff_line_count = scalar(@diff);
  print "\n\nFound $diff_line_count differing lines\n\n";
  Genome::Sys->shellcmd(cmd => "rm -fr /tmp/last-snv-indel-report/");
  Genome::Sys->shellcmd(cmd => "mv $temp_dir /tmp/last-snv-indel-report");
};


