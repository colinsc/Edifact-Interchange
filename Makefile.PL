use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Edifact::Interchange',
    AUTHOR              => q{Colin Campbell <colin.campbell@ptfs-europe.com>},
    VERSION_FROM        => 'lib/Edifact/Interchange.pm',
    ABSTRACT_FROM       => 'lib/Edifact/Interchange.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Edifact-Interchange-*' },
);
