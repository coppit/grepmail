use ExtUtils::MakeMaker;
$Verbose = 1;

WriteMakefile(
   NAME      => 'libemailreader',
   SKIP      => [qw(all static static_lib dynamic dynamic_lib)],
   clean     => {'FILES' => 'libemailreader$(LIB_EXT)'},
);

sub MY::top_targets {
'
all :: static

pure_all :: static

static :: libemailreader$(LIB_EXT)

libemailreader$(LIB_EXT): $(O_FILES)
	$(AR) cr libemailreader$(LIB_EXT) $(O_FILES)
	$(RANLIB) libemailreader$(LIB_EXT)
';
}

