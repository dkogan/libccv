API_VERSION = 1

# I parse the version from the debian changelog. This version is generally
# something like 0.04-1 Here 0.04 is the main version and 1 is the debian
# package version. I only use the main version and strip leading 0s, so the
# above becomes 0.4
VERSION := $(shell sed -n 's/.*(\([0-9\.]*[0-9]\).*).*/\1/; s/\.0*/./g; p; q;' debian/changelog)

ifeq ($(strip $(VERSION)),)
$(error "Couldn't parse version from debian/changelog")
endif

SO_VERSION=$(API_VERSION).$(VERSION)
LIBTARGET_SO_BARE   = libccv.so
LIBTARGET_SO_FULL   = $(LIBTARGET_SO_BARE).$(SO_VERSION)
LIBTARGET_SO_SONAME = $(LIBTARGET_SO_BARE).$(API_VERSION)
LIB_LDFLAGS += -Wl,-soname -Wl,libccv.so.$(API_VERSION)

# Add my optimization flags if none already exist. These could exist if debian
# packages are built.
OPTFLAGS := $(if $(filter -O%, $(CFLAGS)),,-O3)
OPTFLAGS += -ffast-math -mtune=native

FLAGS += -ggdb3 -MMD $(OPTFLAGS)
CFLAGS += $(FLAGS) --std=gnu99

# no USE_DISPATCH since I see build errors with it
CFLAGS += -DHAVE_AVCODEC -DHAVE_AVFORMAT -DHAVE_CBLAS -DHAVE_FFTW3 -DHAVE_GSL -DHAVE_LIBJPEG -DHAVE_LIBLINEAR -DHAVE_LIBPNG -DHAVE_SWSCALE -DUSE_OPENMP -fopenmp -DUSE_SANITY_ASSERTION
LDLIBS += -lm -lavcodec -lavformat /usr/lib/libcblas.so.3 -lfftw3f -lfftw3 -lgomp -lgsl -ljpeg -llinear -lpng -lz -lswscale



LIB_TARGETS = libccv.a $(LIBTARGET_SO_BARE) $(LIBTARGET_SO_FULL) $(LIBTARGET_SO_SONAME)

ALL_TARGETS = $(LIB_TARGETS)

all: $(ALL_TARGETS)

LIB_SOURCES   := $(wildcard $(addsuffix /*.c,lib lib/3rdparty/sha1 lib/3rdparty/sfmt lib/3rdparty/kissfft lib/3rdparty/dsfmt))
SERVE_SOURCES := $(wildcard serve/*.c)

libccv.a: $(LIB_SOURCES:.c=.o)
	ar rcvu $@ $^

$(LIBTARGET_SO_FULL): $(LIB_SOURCES:.c=-pic.o)
	$(CC) $(LIB_LDFLAGS) -shared $^ $(LDLIBS) -o $@

$(LIBTARGET_SO_SONAME) $(LIBTARGET_SO_BARE): $(LIBTARGET_SO_FULL)
	ln -fs $^ $@

%-pic.o: %.c
	$(CC) $(CPPFLAGS) -fPIC $(CFLAGS) -c -o $@ $<



# extra .o because it is generated
SERVE_ALL_OBJECTS := $(SERVE_SOURCES:.c=.o)

# disabled building the state machine since the built files are already shipped
# in the tree
#
#%.c: %.rl
#	ragel -s -G2 $< -o $@

$(SERVE_ALL_OBJECTS): CFLAGS += -Ilib

ccv-serve: LDLIBS += -lccv -lev -ldispatch
ccv-serve: LDFLAGS += -L.

ccv-serve: $(SERVE_ALL_OBJECTS) | $(LIBTARGET_SO_BARE)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@


BIN_TARGETS = bbffmt msermatch siftmatch bbfcreate bbfdetect swtcreate swtdetect dpmcreate dpmdetect convert tld icfcreate icfdetect icfoptimize
$(BIN_TARGETS): LDLIBS += -lccv
$(BIN_TARGETS): LDFLAGS += -L.
$(BIN_TARGETS): %: bin/%.o
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@



clean:
	rm -f $(ALL_TARGETS) $(LIB_SOURCES:.c=*.o) $(LIB_SOURCES:.c=.d) $(SERVE_SOURCES:.c=*.o) $(SERVE_SOURCES:.c=.d)

.PHONY: all clean

-include *.d

