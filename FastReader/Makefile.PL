use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'Mail::Folder::FastReader',
    'VERSION_FROM' => 'FastReader.pm', # finds $VERSION
    'LIBS'	=> [''],   # e.g., '-lm' 
    'DEFINE'	=> '',     # e.g., '-DHAVE_SOMETHING' 
    'MYEXTLIB' => 'lib/libemailreader$(LIB_EXT)',
    # Make sure it doesn't recurse
    # So the tests will work when this is built from the root grepmail
    # directory
    'INC'	=> '-I../blib -I../blib/arch',
);

sub MY::postamble {
'
$(MYEXTLIB): lib/Makefile
	cd lib && $(MAKE) $(PASTHRU)
';
}
