use strict;
use warnings;

use Test::More;
use above 'Genome';

BEGIN {
    use_ok 'Genome::Utility::Test', qw(sub_test compare_ok);
}

my $_compare_ok_parse_args = \&Genome::Utility::Test::_compare_ok_parse_args;

my @args_A = ('file_1', 'file_2', 'args_A');
sub_test('_compare_ok_parse_args parsed: ' . join(', ', @args_A) => sub {
    local $@ = '';
    my ($f1, $f2, %o) = eval { $_compare_ok_parse_args->(@args_A) };
    ok(!$@, 'did not die');
    is($o{name}, $args_A[2], 'name matched expected value');
});

my @args_B = ('file_1', 'file_2', 'args_B', filters => [qr(/foo/)]);
sub_test('_compare_ok_parse_args parsed: ' . join(', ', @args_B) => sub {
    local $@ = '';
    $DB::single = 1;
    my ($f1, $f2, %o) = eval { $_compare_ok_parse_args->(@args_B) };
    ok(!$@, 'did not die');
    is($o{name}, $args_B[2], 'name matched expected value');
    is_deeply($o{filters}, $args_B[4], 'filters matched expected value');
});

my @args_C = ('file_1', 'file_2', filters => [qr(/foo/)], name => 'args_C');
sub_test('_compare_ok_parse_args parsed: ' . join(', ', @args_C) => sub {
    local $@ = '';
    my ($f1, $f2, %o) = eval { $_compare_ok_parse_args->(@args_C) };
    ok(!$@, 'did not die');
    is($o{name}, $args_C[5], 'name matched expected value');
    is_deeply($o{filters}, $args_C[3], 'filters matched expected value');
});

my @args_D = ('file_1', 'file_2', 'args_D', name => 'args_D');
sub_test('_compare_ok_parse_args did fail to parse: ' . join(', ', @args_D) => sub {
    local $@ = '';
    my ($f1, $f2, %o) = eval { $_compare_ok_parse_args->(@args_D) };
    ok($@, 'did die');
});

my @args_E = ('file_1', 'file_2', 'args_E', filters => qr(/foo/));
sub_test('_compare_ok_parse_args parsed: ' . join(', ', @args_E) => sub {
    local $@ = '';
    $DB::single = 1;
    my ($f1, $f2, %o) = eval { $_compare_ok_parse_args->(@args_E) };
    ok(!$@, 'did not die');
    is($o{name}, $args_E[2], 'name matched expected value');
    is_deeply($o{filters}, [$args_E[4]], 'filters matched expected value');
});

sub_test('compare_ok matches diff command' => sub {
    my $a_fh = File::Temp->new(TMPDIR => 1);
    my $a_fn = $a_fh->filename;
    $a_fh->print("a\n");
    $a_fh->close();

    my $b_fh = File::Temp->new(TMPDIR => 1);
    my $b_fn = $b_fh->filename;
    $b_fh->print("b\n");
    $b_fh->close();

    my $aa_fh = File::Temp->new(TMPDIR => 1);
    my $aa_fn = $aa_fh->filename;
    $aa_fh->print("a\n"); # like a, not aa!
    $aa_fh->close();

    {
        my $compare_ok = compare_ok($a_fn, $b_fn, test => 0);
        my $diff    = (system(qq(diff -u "$a_fn" "$b_fn" > /dev/null)) == 0 ? 1 : 0);
        is($diff, 0, 'diff detected diff between different files');
        is($compare_ok, $diff, 'compare_ok detected diff between different files');
    }

    {
        my $compare_ok = compare_ok($a_fn, $aa_fn, test => 0);
        my $diff    = (system(qq(diff -u "$a_fn" "$aa_fn" > /dev/null)) == 0 ? 1 : 0);
        is($diff, 1, 'diff did not detect diff between similar files');
        is($compare_ok, $diff, 'compare_ok did not detect diff between similar files');
    }
});

done_testing();
