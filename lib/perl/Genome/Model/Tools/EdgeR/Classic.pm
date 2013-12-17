package Genome::Model::Tools::EdgeR::Classic;

use Genome;
use Carp qw/confess/;

use strict;
use warnings;

my $R_SCRIPT = __FILE__ . ".R";

class Genome::Model::Tools::EdgeR::Classic {
    is => "Genome::Model::Tools::EdgeR::Base",
    doc => "Run edgeR's classic analysis on the given expression counts",
};

sub help_synopsis {
    return <<EOS

gmt edge-r classic --counts-file counts.txt --groups A,A,B,B,B --output-file out.txt

gmt edge-r classic --counts-file counts.txt --groups normal,tumor,tumor --output-file out.txt

EOS
}

sub help_detail {
    return <<EOS

Detect structures (genes/transcripts) with significantly different expression
levels across groups (e.g., tumor, normal) using edgeR. It is important to
note that at least one of the groups must contain more than one member
(replication).

The input "counts" file should be a headered tab delimited file containing a
header where the first column is the name of an structure and the subsequent
columns are per-sample expression counts generated by a program like
htseq-count. A brief example:

    Gene    Normal1 Tumor1  Tumor2
    GENE0   13      52      53
    GENE1   13      12      13
    GENE2   15      14      15
    GENE3   14      14      13
    ...

The groups parameter should be a comma separated list of condition ids to
associate with each of the input samples. In the example above, this might be
something like "normal,tumor,tumor" or "N,T,T".

The output file consists of 5 columns (one row per input object):

    1) the object name
    2) log-average concentration/abundance for each tag (logConc)
    3) the log fold change (logFC)
    4) the exact (uncorrected) p-value for differential expression
    5) classification result (-1 = down, 0 = no DE, 1 = up).

Example output:

            logCPM  logFC   PValue     test.result
    GENE0   -1.583  2.039   2.627e-08  1
    GENE1   -2.618  -0.031  0.865      0
    GENE2   -2.408  -0.023  0.874      0
    GENE3   -2.509  -0.027  1.000      0
    ...

EOS
}

sub construct_r_command {
    my $self = shift;

    my $cmd = sprintf("Rscript %s --input-file %s --groups '%s' --output-file %s --pvalue %f",
            $R_SCRIPT,
            $self->counts_file,
            $self->groups,
            $self->output_file,
            $self->p_value
            );

    return $cmd;
}

1;
