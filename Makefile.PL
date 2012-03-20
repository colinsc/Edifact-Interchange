use 5.10.0;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Edifact::Interchange',
    AUTHOR              => q{Colin Campbell <colinsc@cpan.org>},
    VERSION_FROM        => 'lib/Edifact/Interchange.pm',
    ABSTRACT_FROM       => 'lib/Edifact/Interchange.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Edifact-Interchange-*' },
);
