use Inline::MakeMaker;
WriteInlineMakefile(
    'NAME'	=> 'Mail::Folder::FastReader',
    'VERSION_FROM' => 'FastReader.pm', # finds $VERSION
    'INC'	=> '-I../blib -I../blib/arch',
    'PREREQ_PM' => {'Inline' => 0.41},
    'dist'  => { COMPRESS => 'gzip -9', SUFFIX => 'gz' },
);
