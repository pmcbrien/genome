#!/usr/bin/env genome-perl

use strict;
use warnings FATAL => 'all';

use Test::More;
use above 'Genome';
use File::Basename qw(dirname basename);
use File::Slurp qw(read_file);
use File::Spec qw();
use File::Path qw(remove_tree);
use Test::Deep qw(cmp_deeply);
use Cwd qw(getcwd abs_path);
use JSON qw(from_json);

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
    require Genome::Config;
    Genome::Config::set_env('workflow_builder_backend', 'ptero');
};

my $test_pattern = shift @ARGV || '*';

for my $test_directory (glob test_data_directory($test_pattern)) {
    my $test_name = basename($test_directory);
    note "Reading in workflow from directory: " . test_data_directory($test_name) . "\n";
    my $workflow = Genome::WorkflowBuilder::DAG->from_xml_filename(workflow_xml_file($test_name));

    # It is important that the log_dir is accessible by the fork workers,
    # or can be created by them.
    my $log_dir = File::Spec->join(getcwd(), 'test_workflow_logs', $test_name);
    $workflow->recursively_set_log_dir($log_dir);

    note "Executing workflow: $test_name\n";
    my $outputs = $workflow->execute(inputs => get_test_inputs($test_name),
        polling_interval => 2);
    is_deeply($outputs, get_test_outputs($test_name), "Workflow $test_name produced expected output");

    unless (cmp_deeply($outputs, get_test_outputs($test_name))) {
        note "Displaying the contents of workflow log files.\n";
        for my $file (glob File::Spec->join($log_dir, '*')) {
            note "\n=== $file ===\n";
            note read_file($file) . "\n";
        }
    }
    remove_tree($log_dir);
}


done_testing();


sub workflow_xml_file {
    my $name = shift;

    my $file = File::Spec->join(test_data_directory($name), 'workflow.xml');
    die "Cannot locate workflow.xml for workflow_test: $name" unless -e $file;
    return $file;
}

sub get_test_inputs {
    my $name = shift;
    my $file = File::Spec->join(test_data_directory($name), 'inputs.json');
    die "Cannot locate test inputs for workflow_test: $name" unless -e $file;
    return from_json(read_file($file));
}

sub get_test_outputs {
    my $name = shift;
    my $file = File::Spec->join(test_data_directory($name), 'outputs.json');
    die "Cannot locate test outputs for workflow_test: $name" unless -e $file;
    return from_json(read_file($file));
}

sub test_data_directory {
    my $name = shift;

    return File::Spec->join(dirname(abs_path(__FILE__)), 'workflow_tests', $name);
}
