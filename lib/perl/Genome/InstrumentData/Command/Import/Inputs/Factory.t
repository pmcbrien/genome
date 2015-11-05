#!/usr/bin/env genome-perl

use strict;
use warnings;

use above 'Genome';

use Genome::Utility::Test;
use File::Spec;
use Test::Exception;
use Test::More tests => 4;

my $class = 'Genome::InstrumentData::Command::Import::Inputs::Factory';
use_ok($class) or die;

my $data_dir = Genome::Utility::Test->data_dir_ok('Genome::InstrumentData::Command::Import', 'generate-cmds');
my $input_file = File::Spec->join($data_dir, 'info.tsv');

my $csv_parser = $class->create(file => $input_file);
my $ref;

subtest 'next' => sub{
    plan tests => 2;

    for (1..4) { $ref = $csv_parser->next }
    is_deeply(
        $ref,
        {
            file => $input_file,
            line_number => 4,
            individual => { name => 'TeSt-0000', nomenclature => 'TeSt', upn => '0000', },
            sample => { name => 'TeSt-0000-01', nomenclature => 'TeSt', },
            library => { name => 'TeSt-0000-01-extlibs', },
            instdata => {
                lane => 7,
                downsample_ratio => '.1',
            },
            source_files => ['bam3.bam'],
        }, 
        'last ref is correct',
    );
    ok(!$csv_parser->next, 'reached end of file');
};

subtest 'fails' => sub{
    plan tests => 8;

    throws_ok(
        sub{ $class->create(file => File::Spec->join($data_dir, 'samples.blah')); },
        qr/Cannot determine type for file: .+. It needs to end with \.csv or \.tsv\./,
        'failed w/ invalid file type',
    );

    throws_ok(
        sub{ $class->create(file => File::Spec->join($data_dir, 'empty.csv')); },
        qr/File \(.+\) is empty\!/,
        'failed w/ empty file',
    );

    throws_ok(
        sub{ $class->create(file => File::Spec->join($data_dir, 'invalid-entity-type.csv')); },
        qr/Invalid entity type: unknown/,
        'failed w/ invalid entity type',
    );

    throws_ok(
        sub{ $class->create(file => File::Spec->join($data_dir, 'invalid-sample-name.csv'))->next; },
        qr/Invalid sample name: INVALID.NAME-. It must have at least 3 parts separated by dashes./,
        'failed w/ invalid sample name',
    );

    throws_ok(
        sub{ $class->create(file => File::Spec->join($data_dir, 'no-nomenclature.csv'))->next; },
        qr/No sample\.nomenclature column given\! It is required to resolve entity names when no sample name is given\./,
        'failed w/o sample name and no sample.nomenclature',
    );

    throws_ok(
        sub{ $class->create(file => File::Spec->join($data_dir, 'no-individual-name-part.csv'))->next; },
        qr/No individual\.name_part column_given! It is required to resolve entity names when no sample name is given\./,
        'failed w/o sample name and no individual.name_part',
    );

    throws_ok(
        sub{ $class->create(file => File::Spec->join($data_dir, 'no-sample-name-part.csv'))->next; },
        qr/No sample\.name_part column_given! It is required to resolve entity names when no sample name is given\./,
        'failed w/o sample name and no sample.name_part',
    );

    throws_ok(
        sub{ $class->create(file => File::Spec->join($data_dir, 'individual-name-mismatch.csv'))->next; },
        qr/Invalid individual name: TGI-AAAA\. It must include the first part of the sample name: TGI-AA12345-Z98765\./,
        'failed when sample name does not include individual name',
    );
};

done_testing();
